#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "esp_http_client.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "nvs.h"
#include "mbedtls/md.h"
#include "esp_random.h"
}

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>

static const char *TAG = "notify";

// ── Placeholder root CA certificate for *.cloudfunctions.net (GTS Root R1) ───
// Replace with real PEM before production deployment.
static const char *ROOT_CA_PEM =
    "-----BEGIN CERTIFICATE-----\n"
    "MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQsw\n"
    "CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU\n"
    "MBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw\n"
    "MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp\n"
    "Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUA\n"
    "A4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreVp0A8of2C+X0yBoJx9vamf/vo\n"
    "narCpKKhiZnfBCmNezpBbfN6wlCt03f1U+AbEFqm0pLd5KFewh6kfRHJJ1p0BXHX\n"
    "s5LtXF4yGpIR1kB1LBKZ0rCVBNTi3VZnSR7v3VFKQ3ZI8ckIR3pVqiPV0YAJHV\n"
    "LLCbG4R/kUMy3PFxZBp0VkuEelkFSKMIGUfz8I/+oOQ5IxWBZEiAH5bA3jLKO\n"
    "PLACEHOLDER - REPLACE WITH REAL GTS ROOT R1 CERTIFICATE BEFORE DEPLOY\n"
    "-----END CERTIFICATE-----\n";

// ── Event log definitions ─────────────────────────────────────────────────────
// (Defined here — extern declared in dd_types.h, defined in main.cpp)
// add_to_event_log and load_settings_from_nvs are implemented here.

// ── Hex encoding helpers ──────────────────────────────────────────────────────
static void bytes_to_hex(const uint8_t *in, size_t len, char *out)
{
    for (size_t i = 0; i < len; i++) {
        snprintf(out + i * 2, 3, "%02x", in[i]);
    }
}

// ── add_to_event_log ──────────────────────────────────────────────────────────
void add_to_event_log(const dd_event_t *ev)
{
    if (!ev || !event_log_mutex) return;
    if (xSemaphoreTake(event_log_mutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        event_log[event_log_head] = *ev;
        event_log_head = (event_log_head + 1) % DD_EVENT_LOG_SIZE;
        if (event_log_count < DD_EVENT_LOG_SIZE) {
            event_log_count = event_log_count + 1;
        }
        xSemaphoreGive(event_log_mutex);
    }
}

// ── load_settings_from_nvs ────────────────────────────────────────────────────
void load_settings_from_nvs(void)
{
    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READONLY, &h) != ESP_OK) {
        // Set defaults
        if (xSemaphoreTake(settings_mutex, pdMS_TO_TICKS(100)) == pdTRUE) {
            dd_settings.motion_enabled   = true;
            dd_settings.notify_enabled   = true;
            dd_settings.mmwave_threshold = 50;
            dd_settings.clip_length_sec  = DD_DEFAULT_CLIP_LENGTH_SEC;
            xSemaphoreGive(settings_mutex);
        }
        return;
    }

    dd_settings_t s = {};
    s.motion_enabled   = true;
    s.notify_enabled   = true;
    s.mmwave_threshold = 50;
    s.clip_length_sec  = DD_DEFAULT_CLIP_LENGTH_SEC;

    uint8_t v = 0;
    if (nvs_get_u8(h, "motion_enabled",   &v) == ESP_OK) s.motion_enabled   = (v != 0);
    if (nvs_get_u8(h, "notify_enabled",   &v) == ESP_OK) s.notify_enabled   = (v != 0);
    if (nvs_get_u8(h, "mmwave_threshold", &v) == ESP_OK) s.mmwave_threshold = v;
    if (nvs_get_u8(h, "clip_length_sec",  &v) == ESP_OK) s.clip_length_sec  = v;
    nvs_close(h);

    if (xSemaphoreTake(settings_mutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        dd_settings = s;
        xSemaphoreGive(settings_mutex);
    }

    ESP_LOGI(TAG, "Settings loaded: motion=%d notify=%d threshold=%d clip=%ds",
             (int)s.motion_enabled, (int)s.notify_enabled,
             (int)s.mmwave_threshold, (int)s.clip_length_sec);
}

// ── HMAC-SHA256 computation ───────────────────────────────────────────────────
static bool compute_hmac_sha256(
    const uint8_t *key, size_t key_len,
    const char *message, size_t msg_len,
    uint8_t *out_32bytes)
{
    const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (!md_info) return false;

    mbedtls_md_context_t ctx;
    mbedtls_md_init(&ctx);
    if (mbedtls_md_setup(&ctx, md_info, 1) != 0) {
        mbedtls_md_free(&ctx);
        return false;
    }
    if (mbedtls_md_hmac_starts(&ctx, key, key_len) != 0 ||
        mbedtls_md_hmac_update(&ctx, (const uint8_t *)message, msg_len) != 0 ||
        mbedtls_md_hmac_finish(&ctx, out_32bytes) != 0) {
        mbedtls_md_free(&ctx);
        return false;
    }
    mbedtls_md_free(&ctx);
    return true;
}

// ── HTTP client event handler (required by ESP-IDF) ───────────────────────────
static esp_err_t http_event_handler(esp_http_client_event_t *evt)
{
    return ESP_OK;
}

// ── send_notify ───────────────────────────────────────────────────────────────
void send_notify(const dd_event_t *ev)
{
    if (!ev) return;

    // Check notify_enabled setting
    if (xSemaphoreTake(settings_mutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        bool enabled = dd_settings.notify_enabled;
        xSemaphoreGive(settings_mutex);
        if (!enabled) {
            ESP_LOGD(TAG, "Notifications disabled, skipping");
            return;
        }
    }

    // Read device_id and device_secret from NVS
    char device_id[DD_DEVICE_ID_LEN + 1] = {};
    char device_secret[65]               = {};
    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READONLY, &h) != ESP_OK) {
        ESP_LOGE(TAG, "Cannot open NVS for notify");
        return;
    }
    size_t len = sizeof(device_id);
    nvs_get_str(h, "device_id",     device_id,     &len);
    len = sizeof(device_secret);
    nvs_get_str(h, "device_secret", device_secret, &len);
    nvs_close(h);

    if (strlen(device_id) == 0 || strlen(device_secret) == 0) {
        ESP_LOGW(TAG, "Device ID or secret not provisioned, skipping notify");
        return;
    }

    // ── Build JSON body ───────────────────────────────────────────────────────
    const char *type_str = (ev->type == DD_EVENT_DOORBELL) ? "doorbell" : "motion";
    bool pir_triggered   = true; // sensor_task always confirms PIR for MOTION
    float mmwave_dist    = ev->distance_m;

    char body[512];
    if (ev->type == DD_EVENT_MOTION) {
        snprintf(body, sizeof(body),
            "{\"deviceId\":\"%s\",\"type\":\"%s\",\"ts\":%lld,"
            "\"clipId\":\"%s\","
            "\"sensorStats\":{\"pirTriggered\":%s,\"mmwaveDistance\":%.2f}}",
            device_id, type_str, (long long)ev->timestamp_ms,
            ev->clip_id,
            pir_triggered ? "true" : "false",
            mmwave_dist);
    } else {
        snprintf(body, sizeof(body),
            "{\"deviceId\":\"%s\",\"type\":\"%s\",\"ts\":%lld,"
            "\"clipId\":\"%s\","
            "\"sensorStats\":{\"pirTriggered\":false,\"mmwaveDistance\":null}}",
            device_id, type_str, (long long)ev->timestamp_ms, ev->clip_id);
    }

    // ── Generate nonce (16 bytes → 32-char hex) ───────────────────────────────
    uint8_t nonce_bytes[DD_HMAC_NONCE_LEN];
    esp_fill_random(nonce_bytes, sizeof(nonce_bytes));
    char nonce_hex[33] = {};
    bytes_to_hex(nonce_bytes, sizeof(nonce_bytes), nonce_hex);
    nonce_hex[32] = '\0';

    // ── Get timestamp ─────────────────────────────────────────────────────────
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    int64_t ts_ms = (int64_t)tv.tv_sec * 1000LL + tv.tv_usec / 1000LL;
    char ts_str[24];
    snprintf(ts_str, sizeof(ts_str), "%lld", (long long)ts_ms);

    // ── Compute HMAC-SHA256: key=device_secret, msg=ts_str||nonce||body ───────
    // Decode hex secret to raw bytes
    uint8_t secret_bytes[32] = {};
    for (int i = 0; i < 32; i++) {
        unsigned int byte_val = 0;
        sscanf(device_secret + i * 2, "%02x", &byte_val);
        secret_bytes[i] = (uint8_t)byte_val;
    }

    // Build message = timestamp_str + nonce + body
    char message[1024];
    snprintf(message, sizeof(message), "%s%s%s", ts_str, nonce_hex, body);

    uint8_t hmac[32] = {};
    char    sig_hex[65] = {};
    if (!compute_hmac_sha256(secret_bytes, sizeof(secret_bytes),
                              message, strlen(message), hmac)) {
        ESP_LOGE(TAG, "HMAC computation failed");
        return;
    }
    bytes_to_hex(hmac, sizeof(hmac), sig_hex);
    sig_hex[64] = '\0';

    // ── POST to Cloud Function (retry up to 3 times) ──────────────────────────
    for (int attempt = 1; attempt <= 3; attempt++) {
        esp_http_client_config_t http_cfg = {};
        http_cfg.url            = DD_CLOUD_FUNCTION_URL;
        http_cfg.method         = HTTP_METHOD_POST;
        http_cfg.timeout_ms     = 10000;
        http_cfg.event_handler  = http_event_handler;
        http_cfg.cert_pem       = ROOT_CA_PEM;
        // cert_pem pins the server CA; set to NULL to skip TLS cert verify (not recommended)

        esp_http_client_handle_t client = esp_http_client_init(&http_cfg);
        if (!client) {
            ESP_LOGE(TAG, "HTTP client init failed");
            vTaskDelay(pdMS_TO_TICKS(5000));
            continue;
        }

        esp_http_client_set_header(client, "Content-Type",  "application/json");
        esp_http_client_set_header(client, "X-Timestamp",   ts_str);
        esp_http_client_set_header(client, "X-Nonce",       nonce_hex);
        esp_http_client_set_header(client, "X-Signature",   sig_hex);
        esp_http_client_set_post_field(client, body, (int)strlen(body));

        esp_err_t err = esp_http_client_perform(client);
        int status    = esp_http_client_get_status_code(client);
        esp_http_client_cleanup(client);

        if (err == ESP_OK && status == 200) {
            ESP_LOGI(TAG, "Notify OK (attempt %d)", attempt);
            return;
        }

        ESP_LOGW(TAG, "Notify attempt %d failed: err=%s status=%d",
                 attempt, esp_err_to_name(err), status);

        if (attempt < 3) {
            vTaskDelay(pdMS_TO_TICKS(5000));
        }
    }

    ESP_LOGE(TAG, "Notify failed after 3 attempts");
}
