#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "freertos/event_groups.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_camera.h"
}

#include <string.h>
#include <stdio.h>

static const char *TAG = "stream";

static volatile bool s_streaming = false;

// ── MJPEG stream handler ──────────────────────────────────────────────────────
// Registered as GET /api/v1/stream handler from http_server.cpp
esp_err_t handle_stream_get(httpd_req_t *req)
{
    // Reject second client
    if (s_streaming) {
        httpd_resp_set_status(req, "503 Service Unavailable");
        httpd_resp_set_type(req, "application/json");
        httpd_resp_sendstr(req, "{\"error\":\"stream busy\",\"code\":503}");
        return ESP_OK;
    }

    s_streaming = true;
    xEventGroupSetBits(system_eg, BIT_STREAMING_ACTIVE);
    ESP_LOGI(TAG, "MJPEG stream client connected");

    // Set multipart content type
    httpd_resp_set_type(req, "multipart/x-mixed-replace; boundary=frame");
    httpd_resp_set_status(req, "200 OK");

    // CORS headers
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin",  "*");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Headers", "Authorization, Content-Type");
    httpd_resp_set_hdr(req, "Cache-Control", "no-cache");

    esp_err_t res = ESP_OK;

    while (res == ESP_OK) {
        // Get frame from stream_frame_queue (placed there by camera_task)
        camera_fb_t *fb = nullptr;
        if (xQueueReceive(stream_frame_queue, &fb, pdMS_TO_TICKS(100)) != pdTRUE) {
            // Queue empty — camera busy with clip or no frames yet; skip
            continue;
        }

        if (!fb) continue;

        // Build MIME part header
        char part_hdr[128];
        int hdr_len = snprintf(part_hdr, sizeof(part_hdr),
            "--frame\r\n"
            "Content-Type: image/jpeg\r\n"
            "Content-Length: %zu\r\n"
            "\r\n",
            fb->len);

        // Send part header
        res = httpd_resp_send_chunk(req, part_hdr, hdr_len);
        if (res == ESP_OK) {
            // Send JPEG data
            res = httpd_resp_send_chunk(req, (const char *)fb->buf, (ssize_t)fb->len);
        }
        if (res == ESP_OK) {
            // Send part terminator
            res = httpd_resp_send_chunk(req, "\r\n", 2);
        }

        // Return frame buffer to camera driver
        esp_camera_fb_return(fb);

        if (res != ESP_OK) {
            ESP_LOGI(TAG, "Client disconnected from stream");
        }
    }

    xEventGroupClearBits(system_eg, BIT_STREAMING_ACTIVE);
    s_streaming = false;
    ESP_LOGI(TAG, "MJPEG stream ended");

    return ESP_OK;
}

// ── stream_task: idle task — stream handler runs in httpd task context ────────
// The stream logic runs entirely within handle_stream_get() above (called by httpd).
// This task just monitors state and can handle cleanup if needed.
void stream_task(void *pvParam)
{
    ESP_LOGI(TAG, "Stream task started (monitor)");

    while (true) {
        // Nothing to do — stream handler runs in httpd task context.
        // This task exists to satisfy the task architecture requirement
        // and can be used for future stream management (e.g., watchdog).
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
