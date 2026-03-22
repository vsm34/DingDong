#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "nvs.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "cJSON.h"
}

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <time.h>

static const char *TAG = "routes_prot";

// Forward declarations
void set_cors_headers(httpd_req_t *req);
void send_json_error(httpd_req_t *req, int code, const char *msg);
bool check_auth(httpd_req_t *req);

// ── Helpers ───────────────────────────────────────────────────────────────────
static void send_json_ok_str(httpd_req_t *req, const char *json)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");
    httpd_resp_set_status(req, "200 OK");
    httpd_resp_sendstr(req, json);
}

static bool read_body(httpd_req_t *req, char *buf, size_t max_len)
{
    if (req->content_len == 0 || req->content_len >= max_len) return false;
    int received = httpd_req_recv(req, buf, req->content_len);
    if (received <= 0) return false;
    buf[received] = '\0';
    return true;
}

// ── Extract clipId from URI /api/v1/clips/<clipId> ────────────────────────────
static bool extract_clip_id(httpd_req_t *req, char *clip_id, size_t max)
{
    // URI format: /api/v1/clips/<clipId>
    const char *prefix = "/api/v1/clips/";
    const char *uri    = req->uri;
    if (strncmp(uri, prefix, strlen(prefix)) != 0) return false;
    const char *id_start = uri + strlen(prefix);
    // Remove query string if any
    const char *q = strchr(id_start, '?');
    size_t id_len = q ? (size_t)(q - id_start) : strlen(id_start);
    if (id_len == 0 || id_len >= max) return false;
    strncpy(clip_id, id_start, id_len);
    clip_id[id_len] = '\0';
    return true;
}

// ── GET /api/v1/health ────────────────────────────────────────────────────────
esp_err_t handle_health_get(httpd_req_t *req)
{
    if (!check_auth(req)) return ESP_OK;

    char device_id[DD_DEVICE_ID_LEN + 1] = {};
    size_t len = sizeof(device_id);
    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READONLY, &h) == ESP_OK) {
        nvs_get_str(h, "device_id", device_id, &len);
        nvs_close(h);
    }

    int64_t now_ms = last_event_ts;
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    int64_t time_now = (int64_t)tv.tv_sec * 1000LL + tv.tv_usec / 1000LL;

    char resp[256];
    snprintf(resp, sizeof(resp),
        "{\"ok\":true,\"deviceId\":\"%s\",\"fwVersion\":\"1.0.0\","
        "\"time\":%lld,\"lastEventTs\":%lld}",
        device_id, (long long)time_now, (long long)now_ms);

    send_json_ok_str(req, resp);
    return ESP_OK;
}

// ── GET /api/v1/events?since=<ts> ────────────────────────────────────────────
esp_err_t handle_events_get(httpd_req_t *req)
{
    if (!check_auth(req)) return ESP_OK;

    // Parse ?since= query param
    int64_t since_ms = 0;
    char since_str[32] = {};
    if (httpd_req_get_url_query_str(req, since_str, sizeof(since_str)) == ESP_OK) {
        char val[24] = {};
        if (httpd_query_key_value(since_str, "since", val, sizeof(val)) == ESP_OK) {
            since_ms = (int64_t)atoll(val);
        }
    }

    // Build JSON from circular event log
    static char resp_buf[4096];
    size_t pos = 0;
    pos += (size_t)snprintf(resp_buf + pos, sizeof(resp_buf) - pos, "{\"events\":[");

    if (xSemaphoreTake(event_log_mutex, pdMS_TO_TICKS(500)) == pdTRUE) {
        bool first = true;
        int  count = event_log_count;
        int  head  = event_log_head;

        // Walk the circular buffer from oldest to newest (up to 50 entries)
        int start = (count >= DD_EVENT_LOG_SIZE) ? head : 0;
        int total = (count < DD_EVENT_LOG_SIZE)  ? count : DD_EVENT_LOG_SIZE;

        for (int i = 0; i < total && pos < sizeof(resp_buf) - 128; i++) {
            int idx = (start + i) % DD_EVENT_LOG_SIZE;
            const dd_event_t *ev = &event_log[idx];
            if (ev->timestamp_ms <= since_ms) continue;

            if (!first) pos += (size_t)snprintf(resp_buf + pos, sizeof(resp_buf) - pos, ",");
            first = false;

            const char *type_str = (ev->type == DD_EVENT_DOORBELL) ? "doorbell" : "motion";
            pos += (size_t)snprintf(resp_buf + pos, sizeof(resp_buf) - pos,
                "{\"type\":\"%s\",\"ts\":%lld,\"clipId\":\"%s\","
                "\"sensorStats\":{\"pirTriggered\":true,\"mmwaveDistance\":%.2f}}",
                type_str, (long long)ev->timestamp_ms, ev->clip_id, ev->distance_m);
        }
        xSemaphoreGive(event_log_mutex);
    }

    pos += (size_t)snprintf(resp_buf + pos, sizeof(resp_buf) - pos, "]}");
    send_json_ok_str(req, resp_buf);
    return ESP_OK;
}

// ── GET /api/v1/clips ─────────────────────────────────────────────────────────
esp_err_t handle_clips_list_get(httpd_req_t *req)
{
    if (!check_auth(req)) return ESP_OK;

    // Request LIST_CLIPS from storage_task with 5s timeout
    static char resp_buf[8192];
    SemaphoreHandle_t sem = xSemaphoreCreateBinary();
    if (!sem) {
        send_json_error(req, 503, "service unavailable");
        return ESP_OK;
    }

    storage_cmd_t cmd = {};
    cmd.cmd           = STORAGE_LIST_CLIPS;
    cmd.resp_buf      = resp_buf;
    cmd.resp_buf_size = sizeof(resp_buf);
    cmd.resp_len      = 0;
    cmd.resp_sem      = sem;

    if (xQueueSend(storage_queue, &cmd, pdMS_TO_TICKS(1000)) != pdTRUE) {
        vSemaphoreDelete(sem);
        send_json_error(req, 503, "storage busy");
        return ESP_OK;
    }

    // Wait up to 5s for response
    if (xSemaphoreTake(sem, pdMS_TO_TICKS(5000)) != pdTRUE) {
        vSemaphoreDelete(sem);
        send_json_error(req, 503, "storage timeout");
        return ESP_OK;
    }
    vSemaphoreDelete(sem);

    send_json_ok_str(req, resp_buf);
    return ESP_OK;
}

// ── GET /api/v1/clips/<clipId> ─────────────────────────────────────────────────
esp_err_t handle_clip_download_get(httpd_req_t *req)
{
    if (!check_auth(req)) return ESP_OK;

    char clip_id[32] = {};
    if (!extract_clip_id(req, clip_id, sizeof(clip_id))) {
        send_json_error(req, 400, "invalid clip id");
        return ESP_OK;
    }

    char path[128];
    snprintf(path, sizeof(path), "%s/clips/%s.avi", DD_SD_MOUNT_POINT, clip_id);

    struct stat st;
    if (stat(path, &st) != 0) {
        send_json_error(req, 404, "not found");
        return ESP_OK;
    }

    FILE *f = fopen(path, "rb");
    if (!f) {
        send_json_error(req, 503, "file open failed");
        return ESP_OK;
    }

    set_cors_headers(req);
    httpd_resp_set_type(req, "video/x-msvideo");

    char cl_str[24];
    snprintf(cl_str, sizeof(cl_str), "%ld", (long)st.st_size);
    httpd_resp_set_hdr(req, "Content-Length", cl_str);
    httpd_resp_set_status(req, "200 OK");

    static uint8_t chunk[4096];
    size_t n;
    while ((n = fread(chunk, 1, sizeof(chunk), f)) > 0) {
        if (httpd_resp_send_chunk(req, (const char *)chunk, (ssize_t)n) != ESP_OK) {
            ESP_LOGW(TAG, "Client disconnected during clip download");
            break;
        }
    }
    fclose(f);
    httpd_resp_send_chunk(req, nullptr, 0); // signal end
    return ESP_OK;
}

// ── DELETE /api/v1/clips/<clipId> ─────────────────────────────────────────────
esp_err_t handle_clip_delete(httpd_req_t *req)
{
    if (!check_auth(req)) return ESP_OK;

    char clip_id[32] = {};
    if (!extract_clip_id(req, clip_id, sizeof(clip_id))) {
        send_json_error(req, 400, "invalid clip id");
        return ESP_OK;
    }

    storage_cmd_t cmd = {};
    cmd.cmd = STORAGE_DELETE_CLIP;
    strncpy(cmd.filename, clip_id, sizeof(cmd.filename) - 1);

    xQueueSend(storage_queue, &cmd, pdMS_TO_TICKS(1000));

    send_json_ok_str(req, "{\"ok\":true}");
    return ESP_OK;
}

// ── GET /api/v1/settings ──────────────────────────────────────────────────────
esp_err_t handle_settings_get(httpd_req_t *req)
{
    if (!check_auth(req)) return ESP_OK;

    dd_settings_t s;
    if (xSemaphoreTake(settings_mutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        s = dd_settings;
        xSemaphoreGive(settings_mutex);
    } else {
        send_json_error(req, 503, "settings locked");
        return ESP_OK;
    }

    char resp[256];
    snprintf(resp, sizeof(resp),
        "{\"motionEnabled\":%s,\"notifyEnabled\":%s,"
        "\"mmwaveThreshold\":%d,\"clipLengthSec\":%d}",
        s.motion_enabled  ? "true" : "false",
        s.notify_enabled  ? "true" : "false",
        (int)s.mmwave_threshold,
        (int)s.clip_length_sec);

    send_json_ok_str(req, resp);
    return ESP_OK;
}

// ── POST /api/v1/settings ─────────────────────────────────────────────────────
esp_err_t handle_settings_post(httpd_req_t *req)
{
    if (!check_auth(req)) return ESP_OK;

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

    // Start with current settings
    dd_settings_t s;
    if (xSemaphoreTake(settings_mutex, pdMS_TO_TICKS(200)) == pdTRUE) {
        s = dd_settings;
        xSemaphoreGive(settings_mutex);
    } else {
        cJSON_Delete(root);
        send_json_error(req, 503, "settings locked");
        return ESP_OK;
    }

    cJSON *j;
    // motionEnabled
    if ((j = cJSON_GetObjectItem(root, "motionEnabled")) && cJSON_IsBool(j)) {
        s.motion_enabled = cJSON_IsTrue(j);
    }
    // notifyEnabled
    if ((j = cJSON_GetObjectItem(root, "notifyEnabled")) && cJSON_IsBool(j)) {
        s.notify_enabled = cJSON_IsTrue(j);
    }
    // mmwaveThreshold
    if ((j = cJSON_GetObjectItem(root, "mmwaveThreshold")) && cJSON_IsNumber(j)) {
        int v = (int)j->valuedouble;
        if (v < 0 || v > 100) {
            cJSON_Delete(root);
            send_json_error(req, 400, "mmwaveThreshold out of range");
            return ESP_OK;
        }
        s.mmwave_threshold = (uint8_t)v;
    }
    // clipLengthSec: must be 5, 10, 20, or 30
    if ((j = cJSON_GetObjectItem(root, "clipLengthSec")) && cJSON_IsNumber(j)) {
        int v = (int)j->valuedouble;
        if (v != 5 && v != 10 && v != 20 && v != 30) {
            cJSON_Delete(root);
            send_json_error(req, 400, "clipLengthSec must be 5, 10, 20, or 30");
            return ESP_OK;
        }
        s.clip_length_sec = (uint8_t)v;
    }
    cJSON_Delete(root);

    // Apply to live settings (mutex locked)
    if (xSemaphoreTake(settings_mutex, pdMS_TO_TICKS(200)) == pdTRUE) {
        dd_settings = s;
        xSemaphoreGive(settings_mutex);
    }

    // Persist to NVS
    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READWRITE, &h) == ESP_OK) {
        nvs_set_u8(h, "motion_enabled",   s.motion_enabled  ? 1 : 0);
        nvs_set_u8(h, "notify_enabled",   s.notify_enabled  ? 1 : 0);
        nvs_set_u8(h, "mmwave_threshold",  s.mmwave_threshold);
        nvs_set_u8(h, "clip_length_sec",   s.clip_length_sec);
        nvs_commit(h);
        nvs_close(h);
    }

    send_json_ok_str(req, "{\"ok\":true}");
    return ESP_OK;
}
