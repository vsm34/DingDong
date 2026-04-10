#include "shared/dd_types.h"

extern "C" {
#include "nvs_flash.h"
#include "esp_log.h"
}

static const char *TAG = "main";

// ── Shared Handle Definitions ─────────────────────────────────────────────────
QueueHandle_t      event_queue        = nullptr;
QueueHandle_t      storage_queue      = nullptr;
QueueHandle_t      stream_frame_queue = nullptr;
EventGroupHandle_t system_eg          = nullptr;
SemaphoreHandle_t  settings_mutex     = nullptr;
dd_settings_t      dd_settings        = {};

// ── Event Log Definitions ─────────────────────────────────────────────────────
dd_event_t        event_log[DD_EVENT_LOG_SIZE] = {};
volatile int      event_log_head  = 0;
volatile int      event_log_count = 0;
SemaphoreHandle_t event_log_mutex = nullptr;

// ── Last Event Timestamp ──────────────────────────────────────────────────────
volatile int64_t last_event_ts = 0;

extern "C" void app_main(void)
{
    // 1. NVS flash init — erase on version mismatch or no free pages
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }
    ESP_ERROR_CHECK(ret);

    // 2. Create shared queues and synchronisation primitives
    event_queue        = xQueueCreate(10, sizeof(dd_event_t));
    storage_queue      = xQueueCreate(5,  sizeof(storage_cmd_t));
    stream_frame_queue = xQueueCreate(2,  sizeof(camera_fb_t *));
    system_eg          = xEventGroupCreate();
    settings_mutex     = xSemaphoreCreateMutex();
    event_log_mutex    = xSemaphoreCreateMutex();

    // 3. Load settings from NVS into global dd_settings
    load_settings_from_nvs();

    // 4. Launch all 5 tasks with pinned cores, exact priorities and stack sizes
    xTaskCreatePinnedToCore(sensor_task,   "sensor",   4096, nullptr, 5, nullptr, 0);
    xTaskCreatePinnedToCore(camera_task,   "camera",   8192, nullptr, 4, nullptr, 1);
    xTaskCreatePinnedToCore(storage_task,  "storage",  4096, nullptr, 3, nullptr, 0);
    xTaskCreatePinnedToCore(wifi_task,     "wifi",     8192, nullptr, 6, nullptr, 0);
    xTaskCreatePinnedToCore(stream_task,   "stream",   4096, nullptr, 2, nullptr, 1);
    xTaskCreatePinnedToCore(ble_prov_task, "ble_prov", 8192, nullptr, 4, nullptr, 0);

    ESP_LOGI(TAG, "DingDong booting...");
}
