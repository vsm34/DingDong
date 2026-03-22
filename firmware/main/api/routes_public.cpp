#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "cJSON.h"
}

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static const char *TAG = "routes_pub";

// Forward declarations from other files
void set_cors_headers(httpd_req_t *req);
void send_json_error(httpd_req_t *req, int code, const char *msg);
extern "C" void wifi_trigger_provision_connect(void);

// ── Helper: send JSON 200 ─────────────────────────────────────────────────────
static void send_json_ok(httpd_req_t *req, const char *json)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");
    httpd_resp_set_status(req, "200 OK");
    httpd_resp_sendstr(req, json);
}

// ── Helper: read request body ─────────────────────────────────────────────────
static bool read_body(httpd_req_t *req, char *buf, size_t max_len)
{
    if (req->content_len == 0 || req->content_len >= max_len) return false;
    int received = httpd_req_recv(req, buf, req->content_len);
    if (received <= 0) return false;
    buf[received] = '\0';
    return true;
}

// ── POST /provision ───────────────────────────────────────────────────────────
esp_err_t handle_provision_post(httpd_req_t *req)
{
    set_cors_headers(req);

    char body[512] = {};
    if (!read_body(req, body, sizeof(body))) {
        send_json_error(req, 400, "invalid body");
        return ESP_OK;
    }

    cJSON *root = cJSON_Parse(body);
    if (!root) {
        send_json_error(req, 400, "invalid json");
        return ESP_OK;
    }

    cJSON *j_ssid   = cJSON_GetObjectItem(root, "ssid");
    cJSON *j_pass   = cJSON_GetObjectItem(root, "password");
    cJSON *j_name   = cJSON_GetObjectItem(root, "deviceName");

    if (!cJSON_IsString(j_ssid) || !cJSON_IsString(j_pass) || !cJSON_IsString(j_name)) {
        cJSON_Delete(root);
        send_json_error(req, 400, "missing fields");
        return ESP_OK;
    }

    const char *ssid = j_ssid->valuestring;
    const char *pass = j_pass->valuestring;
    const char *name = j_name->valuestring;

    // Validate lengths
    if (strlen(ssid) == 0 || strlen(ssid) > 32 ||
        strlen(pass) > 63  ||
        strlen(name) == 0 || strlen(name) > 32) {
        cJSON_Delete(root);
        send_json_error(req, 400, "field length invalid");
        return ESP_OK;
    }

    // Store in NVS
    nvs_handle_t h;
    esp_err_t err = nvs_open("dingdong", NVS_READWRITE, &h);
    if (err == ESP_OK) {
        nvs_set_str(h, "wifi_ssid",   ssid);
        nvs_set_str(h, "wifi_pass",   pass);
        nvs_set_str(h, "device_name", name);
        nvs_commit(h);
        nvs_close(h);
        ESP_LOGI(TAG, "Credentials stored, SSID: %s", ssid);
    }
    cJSON_Delete(root);

    // Trigger connect in wifi_task
    wifi_trigger_provision_connect();

    send_json_ok(req, "{\"ok\":true}");
    return ESP_OK;
}

// ── GET /provision/status ─────────────────────────────────────────────────────
esp_err_t handle_provision_status_get(httpd_req_t *req)
{
    set_cors_headers(req);

    EventBits_t bits = xEventGroupGetBits(system_eg);
    bool connected   = (bits & BIT_WIFI_CONNECTED) != 0;

    nvs_handle_t h;
    char device_id[DD_DEVICE_ID_LEN + 1] = {};
    char api_token[DD_TOKEN_HEX_LEN]     = {};
    uint8_t token_served = 0;

    if (nvs_open("dingdong", NVS_READWRITE, &h) == ESP_OK) {
        size_t len = sizeof(device_id);
        nvs_get_str(h, "device_id", device_id, &len);
        len = sizeof(api_token);
        nvs_get_str(h, "api_token", api_token, &len);
        nvs_get_u8(h, "token_served", &token_served);

        if (connected && strlen(api_token) > 0 && token_served == 0) {
            // Return token once, then set the served flag
            nvs_set_u8(h, "token_served", 1);
            nvs_commit(h);
        } else if (token_served) {
            // Clear token from response — already served
            api_token[0] = '\0';
        }
        nvs_close(h);
    }

    char resp[256];
    if (connected && strlen(api_token) > 0) {
        snprintf(resp, sizeof(resp),
            "{\"state\":\"connected\",\"deviceId\":\"%s\",\"token\":\"%s\"}",
            device_id, api_token);
    } else if (connected) {
        snprintf(resp, sizeof(resp),
            "{\"state\":\"connected\",\"deviceId\":\"%s\"}",
            device_id);
    } else {
        // Check if we have credentials stored (connecting) or not (failed/waiting)
        char ssid[33] = {};
        size_t len = sizeof(ssid);
        nvs_handle_t h2;
        bool has_creds = false;
        if (nvs_open("dingdong", NVS_READONLY, &h2) == ESP_OK) {
            has_creds = (nvs_get_str(h2, "wifi_ssid", ssid, &len) == ESP_OK
                         && strlen(ssid) > 0);
            nvs_close(h2);
        }
        snprintf(resp, sizeof(resp),
            "{\"state\":\"%s\"}", has_creds ? "connecting" : "waiting");
    }

    send_json_ok(req, resp);
    return ESP_OK;
}

// ── POST /provision/secret ────────────────────────────────────────────────────
esp_err_t handle_provision_secret_post(httpd_req_t *req)
{
    set_cors_headers(req);

    // Check if already provisioned
    nvs_handle_t h;
    uint8_t secret_provisioned = 0;
    if (nvs_open("dingdong", NVS_READONLY, &h) == ESP_OK) {
        nvs_get_u8(h, "secret_provisioned", &secret_provisioned);
        nvs_close(h);
    }
    if (secret_provisioned) {
        send_json_error(req, 403, "already provisioned");
        return ESP_OK;
    }

    char body[256] = {};
    if (!read_body(req, body, sizeof(body))) {
        send_json_error(req, 400, "invalid body");
        return ESP_OK;
    }

    cJSON *root = cJSON_Parse(body);
    if (!root) {
        send_json_error(req, 400, "invalid json");
        return ESP_OK;
    }

    cJSON *j_secret = cJSON_GetObjectItem(root, "secret");
    if (!cJSON_IsString(j_secret)) {
        cJSON_Delete(root);
        send_json_error(req, 400, "missing secret");
        return ESP_OK;
    }

    const char *secret = j_secret->valuestring;

    // Must be exactly 64 hex chars
    if (strlen(secret) != 64) {
        cJSON_Delete(root);
        send_json_error(req, 400, "secret must be 64 hex chars");
        return ESP_OK;
    }
    for (int i = 0; i < 64; i++) {
        char c = secret[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) {
            cJSON_Delete(root);
            send_json_error(req, 400, "secret must be hex");
            return ESP_OK;
        }
    }

    // Store in NVS
    if (nvs_open("dingdong", NVS_READWRITE, &h) == ESP_OK) {
        nvs_set_str(h, "device_secret", secret);
        nvs_set_u8(h,  "secret_provisioned", 1);
        nvs_commit(h);
        nvs_close(h);
        ESP_LOGI(TAG, "Device secret stored");
    }
    cJSON_Delete(root);

    send_json_ok(req, "{\"ok\":true}");
    return ESP_OK;
}

// ── DELETE /provision ─────────────────────────────────────────────────────────
static void delayed_reboot(void *arg)
{
    esp_restart();
}

esp_err_t handle_provision_delete(httpd_req_t *req)
{
    set_cors_headers(req);
    ESP_LOGI(TAG, "Factory reset requested — clearing NVS");

    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READWRITE, &h) == ESP_OK) {
        nvs_erase_key(h, "wifi_ssid");
        nvs_erase_key(h, "wifi_pass");
        nvs_erase_key(h, "device_id");
        nvs_erase_key(h, "api_token");
        nvs_erase_key(h, "token_served");
        nvs_erase_key(h, "device_secret");
        nvs_erase_key(h, "secret_provisioned");
        nvs_erase_key(h, "device_name");
        nvs_commit(h);
        nvs_close(h);
    }

    send_json_ok(req, "{\"ok\":true}");

    // Reboot after 500ms (give HTTP response time to be sent)
    esp_timer_handle_t timer;
    const esp_timer_create_args_t timer_args = {
        delayed_reboot, nullptr, ESP_TIMER_TASK, "reboot_timer", false
    };
    esp_timer_create(&timer_args, &timer);
    esp_timer_start_once(timer, 500 * 1000); // 500ms in microseconds

    return ESP_OK;
}
