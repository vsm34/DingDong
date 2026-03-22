#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "nvs.h"
#include "mbedtls/constant_time.h"
}

#include <string.h>
#include <stdio.h>

static const char *TAG = "auth";

// Forward declaration (in http_server.cpp)
void send_json_error(httpd_req_t *req, int code, const char *msg);

// ── Rate-limiting state ───────────────────────────────────────────────────────
static int64_t  s_fail_timestamps[DD_AUTH_FAIL_MAX] = {};
static int      s_fail_count = 0;

static bool is_rate_limited(void)
{
    int64_t now_ms = esp_timer_get_time() / 1000LL;
    // Remove timestamps older than the window
    int valid = 0;
    for (int i = 0; i < s_fail_count; i++) {
        if ((now_ms - s_fail_timestamps[i]) < DD_AUTH_FAIL_WINDOW_MS) {
            s_fail_timestamps[valid++] = s_fail_timestamps[i];
        }
    }
    s_fail_count = valid;
    return s_fail_count >= DD_AUTH_FAIL_MAX;
}

static void record_fail(void)
{
    int64_t now_ms = esp_timer_get_time() / 1000LL;
    if (s_fail_count < DD_AUTH_FAIL_MAX) {
        s_fail_timestamps[s_fail_count++] = now_ms;
    } else {
        // Shift left and add new
        for (int i = 0; i < DD_AUTH_FAIL_MAX - 1; i++) {
            s_fail_timestamps[i] = s_fail_timestamps[i + 1];
        }
        s_fail_timestamps[DD_AUTH_FAIL_MAX - 1] = now_ms;
    }
}

// ── check_auth: returns true if authorised ────────────────────────────────────
bool check_auth(httpd_req_t *req)
{
    // Check rate limit first
    if (is_rate_limited()) {
        send_json_error(req, 429, "too many requests");
        return false;
    }

    // Read Authorization header
    size_t hdr_len = httpd_req_get_hdr_value_len(req, "Authorization");
    if (hdr_len == 0) {
        record_fail();
        send_json_error(req, 401, "unauthorized");
        return false;
    }

    char auth_hdr[DD_TOKEN_HEX_LEN + 16]; // "Bearer " + token + null
    if (hdr_len >= sizeof(auth_hdr)) {
        record_fail();
        send_json_error(req, 401, "unauthorized");
        return false;
    }

    esp_err_t err = httpd_req_get_hdr_value_str(req, "Authorization",
                                                 auth_hdr, sizeof(auth_hdr));
    if (err != ESP_OK) {
        record_fail();
        send_json_error(req, 401, "unauthorized");
        return false;
    }

    // Must start with "Bearer "
    const char *prefix = "Bearer ";
    size_t prefix_len  = strlen(prefix);
    if (strncmp(auth_hdr, prefix, prefix_len) != 0) {
        record_fail();
        send_json_error(req, 401, "unauthorized");
        return false;
    }

    const char *provided_token = auth_hdr + prefix_len;

    // Read stored token from NVS
    char stored_token[DD_TOKEN_HEX_LEN] = {};
    size_t len = sizeof(stored_token);
    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READONLY, &h) != ESP_OK) {
        send_json_error(req, 503, "service unavailable");
        return false;
    }
    err = nvs_get_str(h, "api_token", stored_token, &len);
    nvs_close(h);

    if (err != ESP_OK || strlen(stored_token) == 0) {
        send_json_error(req, 503, "service unavailable");
        return false;
    }

    // Constant-time compare to prevent timing attacks
    size_t stored_len   = strlen(stored_token);
    size_t provided_len = strlen(provided_token);

    // Lengths must match (padding-safe: compare stored_len bytes if lengths differ)
    bool length_ok = (provided_len == stored_len);
    int  cmp_result = mbedtls_ct_memcmp(provided_token, stored_token,
                                         stored_len < provided_len ? stored_len : provided_len);

    if (!length_ok || cmp_result != 0) {
        record_fail();
        ESP_LOGW(TAG, "Auth failure from %s", req->uri);
        send_json_error(req, 401, "unauthorized");
        return false;
    }

    return true;
}
