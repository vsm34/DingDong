#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "esp_http_server.h"
#include "esp_log.h"
}

#include <string.h>

static const char *TAG = "http";

static httpd_handle_t s_server = nullptr;

// Forward declarations for route handlers (defined in routes_*.cpp and stream_task.cpp)
// Public routes
esp_err_t handle_provision_post(httpd_req_t *req);
esp_err_t handle_provision_status_get(httpd_req_t *req);
esp_err_t handle_provision_secret_post(httpd_req_t *req);
esp_err_t handle_provision_delete(httpd_req_t *req);
// Protected routes
esp_err_t handle_health_get(httpd_req_t *req);
esp_err_t handle_events_get(httpd_req_t *req);
esp_err_t handle_clips_list_get(httpd_req_t *req);
esp_err_t handle_clip_download_get(httpd_req_t *req);
esp_err_t handle_clip_delete(httpd_req_t *req);
esp_err_t handle_settings_get(httpd_req_t *req);
esp_err_t handle_settings_post(httpd_req_t *req);
// Stream (registered from stream_task.cpp)
esp_err_t handle_stream_get(httpd_req_t *req);

// ── CORS helper (called by every route handler) ───────────────────────────────
void set_cors_headers(httpd_req_t *req)
{
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin",  "*");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Headers", "Authorization, Content-Type");
}

// ── OPTIONS preflight handler ─────────────────────────────────────────────────
static esp_err_t handle_options(httpd_req_t *req)
{
    set_cors_headers(req);
    httpd_resp_set_status(req, "200 OK");
    httpd_resp_sendstr(req, "");
    return ESP_OK;
}

// ── JSON error helper (used by route handlers) ────────────────────────────────
void send_json_error(httpd_req_t *req, int code, const char *msg)
{
    set_cors_headers(req);
    char buf[128];
    snprintf(buf, sizeof(buf), "{\"error\":\"%s\",\"code\":%d}", msg, code);
    switch (code) {
    case 400: httpd_resp_set_status(req, "400 Bad Request");    break;
    case 401: httpd_resp_set_status(req, "401 Unauthorized");   break;
    case 403: httpd_resp_set_status(req, "403 Forbidden");      break;
    case 429: httpd_resp_set_status(req, "429 Too Many Requests"); break;
    case 503: httpd_resp_set_status(req, "503 Service Unavailable"); break;
    default:  httpd_resp_set_status(req, "500 Internal Server Error"); break;
    }
    httpd_resp_set_type(req, "application/json");
    httpd_resp_sendstr(req, buf);
}

// ── Register provisioning-only routes ────────────────────────────────────────
static void register_provisioning_routes(httpd_handle_t server)
{
    // OPTIONS
    static const httpd_uri_t opts_provision = {
        "/provision", HTTP_OPTIONS, handle_options, nullptr
    };
    static const httpd_uri_t opts_provision_status = {
        "/provision/status", HTTP_OPTIONS, handle_options, nullptr
    };
    static const httpd_uri_t opts_provision_secret = {
        "/provision/secret", HTTP_OPTIONS, handle_options, nullptr
    };

    // POST /provision
    static const httpd_uri_t post_provision = {
        "/provision", HTTP_POST, handle_provision_post, nullptr
    };
    // GET /provision/status
    static const httpd_uri_t get_provision_status = {
        "/provision/status", HTTP_GET, handle_provision_status_get, nullptr
    };
    // POST /provision/secret
    static const httpd_uri_t post_provision_secret = {
        "/provision/secret", HTTP_POST, handle_provision_secret_post, nullptr
    };
    // DELETE /provision
    static const httpd_uri_t del_provision = {
        "/provision", HTTP_DELETE, handle_provision_delete, nullptr
    };

    httpd_register_uri_handler(server, &opts_provision);
    httpd_register_uri_handler(server, &opts_provision_status);
    httpd_register_uri_handler(server, &opts_provision_secret);
    httpd_register_uri_handler(server, &post_provision);
    httpd_register_uri_handler(server, &get_provision_status);
    httpd_register_uri_handler(server, &post_provision_secret);
    httpd_register_uri_handler(server, &del_provision);
}

// ── Register all routes (provisioning + protected) ────────────────────────────
static void register_full_routes(httpd_handle_t server)
{
    register_provisioning_routes(server);

    // OPTIONS for protected routes
    static const httpd_uri_t opts_health = {
        "/api/v1/health", HTTP_OPTIONS, handle_options, nullptr
    };
    static const httpd_uri_t opts_events = {
        "/api/v1/events", HTTP_OPTIONS, handle_options, nullptr
    };
    static const httpd_uri_t opts_clips = {
        "/api/v1/clips", HTTP_OPTIONS, handle_options, nullptr
    };
    static const httpd_uri_t opts_clips_id = {
        "/api/v1/clips/*", HTTP_OPTIONS, handle_options, nullptr
    };
    static const httpd_uri_t opts_settings = {
        "/api/v1/settings", HTTP_OPTIONS, handle_options, nullptr
    };
    static const httpd_uri_t opts_stream = {
        "/api/v1/stream", HTTP_OPTIONS, handle_options, nullptr
    };

    // Protected GETs
    static const httpd_uri_t get_health = {
        "/api/v1/health", HTTP_GET, handle_health_get, nullptr
    };
    static const httpd_uri_t get_events = {
        "/api/v1/events", HTTP_GET, handle_events_get, nullptr
    };
    static const httpd_uri_t get_clips = {
        "/api/v1/clips", HTTP_GET, handle_clips_list_get, nullptr
    };
    static const httpd_uri_t get_clip_id = {
        "/api/v1/clips/*", HTTP_GET, handle_clip_download_get, nullptr
    };
    static const httpd_uri_t del_clip_id = {
        "/api/v1/clips/*", HTTP_DELETE, handle_clip_delete, nullptr
    };
    static const httpd_uri_t get_settings = {
        "/api/v1/settings", HTTP_GET, handle_settings_get, nullptr
    };
    static const httpd_uri_t post_settings = {
        "/api/v1/settings", HTTP_POST, handle_settings_post, nullptr
    };
    static const httpd_uri_t get_stream = {
        "/api/v1/stream", HTTP_GET, handle_stream_get, nullptr
    };

    httpd_register_uri_handler(server, &opts_health);
    httpd_register_uri_handler(server, &opts_events);
    httpd_register_uri_handler(server, &opts_clips);
    httpd_register_uri_handler(server, &opts_clips_id);
    httpd_register_uri_handler(server, &opts_settings);
    httpd_register_uri_handler(server, &opts_stream);

    httpd_register_uri_handler(server, &get_health);
    httpd_register_uri_handler(server, &get_events);
    httpd_register_uri_handler(server, &get_clips);
    httpd_register_uri_handler(server, &get_clip_id);
    httpd_register_uri_handler(server, &del_clip_id);
    httpd_register_uri_handler(server, &get_settings);
    httpd_register_uri_handler(server, &post_settings);
    httpd_register_uri_handler(server, &get_stream);
}

// ── Start provisioning-only HTTP server ───────────────────────────────────────
esp_err_t http_server_start_provisioning(void)
{
    if (s_server) return ESP_OK;

    httpd_config_t config      = HTTPD_DEFAULT_CONFIG();
    config.server_port         = DD_HTTP_PORT;
    config.max_uri_handlers    = 16;
    config.uri_match_fn        = httpd_uri_match_wildcard;
    config.stack_size          = 8192;
    config.lru_purge_enable    = true;

    esp_err_t err = httpd_start(&s_server, &config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Provisioning server start failed: %s", esp_err_to_name(err));
        return err;
    }
    register_provisioning_routes(s_server);
    ESP_LOGI(TAG, "Provisioning HTTP server started on port %d", DD_HTTP_PORT);
    return ESP_OK;
}

// ── Start full HTTP server (all routes) ───────────────────────────────────────
esp_err_t http_server_start_full(void)
{
    if (s_server) {
        httpd_stop(s_server);
        s_server = nullptr;
    }

    httpd_config_t config      = HTTPD_DEFAULT_CONFIG();
    config.server_port         = DD_HTTP_PORT;
    config.max_uri_handlers    = 32;
    config.uri_match_fn        = httpd_uri_match_wildcard;
    config.stack_size          = 8192;
    config.lru_purge_enable    = true;

    esp_err_t err = httpd_start(&s_server, &config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Full server start failed: %s", esp_err_to_name(err));
        return err;
    }
    register_full_routes(s_server);
    ESP_LOGI(TAG, "Full HTTP server started on port %d", DD_HTTP_PORT);
    return ESP_OK;
}

// ── Stop server ───────────────────────────────────────────────────────────────
void http_server_stop(void)
{
    if (s_server) {
        httpd_stop(s_server);
        s_server = nullptr;
        ESP_LOGI(TAG, "HTTP server stopped");
    }
}
