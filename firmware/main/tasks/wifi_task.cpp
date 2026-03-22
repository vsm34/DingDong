#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_wifi.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_netif.h"
#include "esp_event.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "esp_sntp.h"
#include "mdns.h"
#include "esp_random.h"
}

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static const char *TAG = "wifi";

// ── Task notification bits ────────────────────────────────────────────────────
#define NOTIFY_WIFI_GOT_IP        (1u << 0)
#define NOTIFY_WIFI_DISCONNECTED  (1u << 1)
#define NOTIFY_PROVISIONED        (1u << 2)

static TaskHandle_t s_wifi_task_handle = nullptr;
static bool         s_sta_connected    = false;

// Forward declarations for HTTP server control (defined in http_server.cpp)
esp_err_t http_server_start_provisioning(void);
esp_err_t http_server_start_full(void);
void      http_server_stop(void);

// ── WiFi event handler ────────────────────────────────────────────────────────
static void wifi_event_handler(void *arg, esp_event_base_t base,
                               int32_t id, void *data)
{
    if (base == WIFI_EVENT) {
        if (id == WIFI_EVENT_STA_DISCONNECTED) {
            s_sta_connected = false;
            xEventGroupClearBits(system_eg, BIT_WIFI_CONNECTED);
            if (s_wifi_task_handle) {
                xTaskNotify(s_wifi_task_handle, NOTIFY_WIFI_DISCONNECTED, eSetBits);
            }
        } else if (id == WIFI_EVENT_AP_STACONNECTED) {
            ESP_LOGI(TAG, "SoftAP: client connected");
        }
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        s_sta_connected = true;
        if (s_wifi_task_handle) {
            xTaskNotify(s_wifi_task_handle, NOTIFY_WIFI_GOT_IP, eSetBits);
        }
    }
}

// ── NVS helpers ───────────────────────────────────────────────────────────────
static bool nvs_read_str(const char *key, char *buf, size_t len)
{
    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READONLY, &h) != ESP_OK) return false;
    esp_err_t err = nvs_get_str(h, key, buf, &len);
    nvs_close(h);
    return err == ESP_OK;
}

// ── Hex encoding helper ───────────────────────────────────────────────────────
static void bytes_to_hex(const uint8_t *in, size_t len, char *out)
{
    for (size_t i = 0; i < len; i++) {
        snprintf(out + i * 2, 3, "%02x", in[i]);
    }
}

// ── Generate deviceId from MAC (16 hex chars) ────────────────────────────────
static void generate_device_id(char *buf)
{
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(buf, DD_DEVICE_ID_LEN + 1,
             "%02x%02x%02x%02x%02x%02x%02x%02x",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5],
             (uint8_t)(mac[0] ^ mac[5]), (uint8_t)(mac[1] ^ mac[4]));
}

// ── Generate 32-byte random token → 64 hex chars ─────────────────────────────
static void generate_token(char *buf)
{
    uint8_t raw[DD_TOKEN_LEN];
    esp_fill_random(raw, sizeof(raw));
    bytes_to_hex(raw, sizeof(raw), buf);
    buf[DD_TOKEN_HEX_LEN - 1] = '\0';
}

// ── Connect to home Wi-Fi ─────────────────────────────────────────────────────
static void connect_sta(const char *ssid, const char *pass)
{
    wifi_config_t sta_cfg = {};
    strncpy((char *)sta_cfg.sta.ssid,     ssid, sizeof(sta_cfg.sta.ssid) - 1);
    strncpy((char *)sta_cfg.sta.password, pass, sizeof(sta_cfg.sta.password) - 1);
    esp_wifi_set_mode(WIFI_MODE_STA);
    esp_wifi_set_config(WIFI_IF_STA, &sta_cfg);
    esp_wifi_connect();
}

// ── Start SoftAP ──────────────────────────────────────────────────────────────
static void start_softap(void)
{
    wifi_config_t ap_cfg = {};
    strncpy((char *)ap_cfg.ap.ssid, DD_SOFTAP_SSID, sizeof(ap_cfg.ap.ssid));
    ap_cfg.ap.ssid_len       = (uint8_t)strlen(DD_SOFTAP_SSID);
    ap_cfg.ap.max_connection = DD_SOFTAP_MAX_CONN;
    ap_cfg.ap.authmode       = WIFI_AUTH_OPEN;
    esp_wifi_set_mode(WIFI_MODE_AP);
    esp_wifi_set_config(WIFI_IF_AP, &ap_cfg);
    esp_wifi_start();
    ESP_LOGI(TAG, "SoftAP started: %s", DD_SOFTAP_SSID);
}

// ── SNTP init ─────────────────────────────────────────────────────────────────
static void init_sntp(void)
{
    esp_sntp_setoperatingmode(SNTP_OPMODE_POLL);
    esp_sntp_setservername(0, "pool.ntp.org");
    esp_sntp_init();
    ESP_LOGI(TAG, "SNTP initialised");
}

// ── mDNS start ────────────────────────────────────────────────────────────────
static void start_mdns(const char *device_id)
{
    char hostname[48];
    snprintf(hostname, sizeof(hostname), "%s%s", DD_MDNS_HOSTNAME_PREFIX, device_id);
    mdns_init();
    mdns_hostname_set(hostname);
    mdns_instance_name_set("DingDong Doorbell");
    mdns_service_add(nullptr, "_http", "_tcp", DD_HTTP_PORT, nullptr, 0);
    ESP_LOGI(TAG, "mDNS started: %s.local", hostname);
}

// ── On-station-connected actions ──────────────────────────────────────────────
static void on_sta_connected(void)
{
    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READWRITE, &h) != ESP_OK) return;

    // Generate deviceId if not stored
    char device_id[DD_DEVICE_ID_LEN + 1] = {};
    size_t len = sizeof(device_id);
    if (nvs_get_str(h, "device_id", device_id, &len) != ESP_OK) {
        generate_device_id(device_id);
        nvs_set_str(h, "device_id", device_id);
        nvs_commit(h);
        ESP_LOGI(TAG, "Generated device_id: %s", device_id);
    }

    // Generate api_token if not stored
    char api_token[DD_TOKEN_HEX_LEN] = {};
    len = sizeof(api_token);
    if (nvs_get_str(h, "api_token", api_token, &len) != ESP_OK) {
        generate_token(api_token);
        nvs_set_str(h, "api_token", api_token);
        nvs_commit(h);
        ESP_LOGI(TAG, "Generated api_token");
    }
    nvs_close(h);

    xEventGroupSetBits(system_eg, BIT_WIFI_CONNECTED | BIT_PROVISIONED);
    ESP_LOGI(TAG, "Wi-Fi connected");

    start_mdns(device_id);
    init_sntp();
    http_server_start_full();
}

// ── wifi_task ─────────────────────────────────────────────────────────────────
void wifi_task(void *pvParam)
{
    ESP_LOGI(TAG, "Wi-Fi task started");
    s_wifi_task_handle = xTaskGetCurrentTaskHandle();

    // Init netif and event loop
    esp_netif_init();
    esp_event_loop_create_default();
    esp_netif_create_default_wifi_sta();
    esp_netif_create_default_wifi_ap();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);

    esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                               wifi_event_handler, nullptr);
    esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                               wifi_event_handler, nullptr);

    // Check NVS for stored credentials
    char ssid[33] = {};
    char pass[64] = {};
    bool provisioned = nvs_read_str("wifi_ssid", ssid, sizeof(ssid));

    if (!provisioned || strlen(ssid) == 0) {
        ESP_LOGI(TAG, "No credentials — starting SoftAP provisioning");
        start_softap();
        http_server_start_provisioning();

        // Wait until provisioned (HTTP handler sets NOTIFY_PROVISIONED via task notify)
        while (true) {
            uint32_t notif = 0;
            xTaskNotifyWait(0, UINT32_MAX, &notif, pdMS_TO_TICKS(5000));
            if (notif & NOTIFY_PROVISIONED) break;
            // Re-read NVS in case provisioning happened
            if (nvs_read_str("wifi_ssid", ssid, sizeof(ssid)) && strlen(ssid) > 0) {
                nvs_read_str("wifi_pass", pass, sizeof(pass));
                break;
            }
        }
        esp_wifi_stop();
        nvs_read_str("wifi_ssid", ssid, sizeof(ssid));
        nvs_read_str("wifi_pass", pass, sizeof(pass));
    } else {
        nvs_read_str("wifi_pass", pass, sizeof(pass));
        ESP_LOGI(TAG, "Credentials found, connecting to '%s'", ssid);
        esp_wifi_start();
    }

    // Connect in STA mode with exponential backoff reconnect
    int backoff_ms = 1000;

    connect_sta(ssid, pass);

    while (true) {
        uint32_t notif = 0;
        BaseType_t got = xTaskNotifyWait(0, UINT32_MAX, &notif, pdMS_TO_TICKS(30000));

        if (got == pdTRUE && (notif & NOTIFY_WIFI_GOT_IP)) {
            ESP_LOGI(TAG, "Got IP — running on-connected setup");
            backoff_ms = 1000; // reset backoff
            on_sta_connected();
        } else if (got == pdTRUE && (notif & NOTIFY_WIFI_DISCONNECTED)) {
            ESP_LOGW(TAG, "Wi-Fi disconnected, reconnecting in %d ms", backoff_ms);
            vTaskDelay(pdMS_TO_TICKS(backoff_ms));
            backoff_ms = (backoff_ms * 2 < 30000) ? backoff_ms * 2 : 30000;
            esp_wifi_connect();
        } else {
            // Timeout — try reconnect if not connected
            if (!s_sta_connected) {
                ESP_LOGW(TAG, "Reconnect attempt (backoff %d ms)", backoff_ms);
                esp_wifi_connect();
                vTaskDelay(pdMS_TO_TICKS(backoff_ms));
                backoff_ms = (backoff_ms * 2 < 30000) ? backoff_ms * 2 : 30000;
            }
        }
    }
}

// ── Called by provisioning route after credentials stored ─────────────────────
extern "C" void wifi_trigger_provision_connect(void)
{
    if (s_wifi_task_handle) {
        xTaskNotify(s_wifi_task_handle, NOTIFY_PROVISIONED, eSetBits);
    }
}
