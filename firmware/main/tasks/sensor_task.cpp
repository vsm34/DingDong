#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/uart.h"
#include "esp_log.h"
#include "esp_timer.h"
}

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

static const char *TAG = "sensor";

// ── ISR event types ───────────────────────────────────────────────────────────
typedef enum {
    ISR_PIR      = 0,
    ISR_DOORBELL = 1,
} isr_event_t;

static QueueHandle_t s_isr_queue = nullptr;

// ── ISR Handlers (IRAM, no heap, no logging) ──────────────────────────────────
static void IRAM_ATTR pir_isr_handler(void *arg)
{
    isr_event_t ev = ISR_PIR;
    BaseType_t woken = pdFALSE;
    xQueueSendFromISR(s_isr_queue, &ev, &woken);
    portYIELD_FROM_ISR(woken);
}

static void IRAM_ATTR doorbell_isr_handler(void *arg)
{
    isr_event_t ev = ISR_DOORBELL;
    BaseType_t woken = pdFALSE;
    xQueueSendFromISR(s_isr_queue, &ev, &woken);
    portYIELD_FROM_ISR(woken);
}

// ── mmWave frame parser ───────────────────────────────────────────────────────
// Parses: "$JYBSS,<presence>,<distance_m>,<speed>,<angle>\r\n"
// Returns true if a valid frame was parsed.
static bool parse_jybss(const char *line, int *presence, float *distance_m)
{
    if (strncmp(line, "$JYBSS,", 7) != 0) {
        return false;
    }
    int p = 0;
    float d = 0.0f;
    // sscanf with %*f for speed and angle (ignored)
    int matched = sscanf(line + 7, "%d,%f", &p, &d);
    if (matched < 2) {
        return false;
    }
    *presence   = p;
    *distance_m = d;
    return true;
}

// ── Buzzer helpers ────────────────────────────────────────────────────────────
static void buzzer_beep(uint32_t duration_ms)
{
    gpio_set_level(DD_BUZZER_GPIO, 1);
    vTaskDelay(pdMS_TO_TICKS(duration_ms));
    gpio_set_level(DD_BUZZER_GPIO, 0);
}

// ── sensor_task ───────────────────────────────────────────────────────────────
void sensor_task(void *pvParam)
{
    ESP_LOGI(TAG, "Sensor task started");

    // Create ISR queue (depth 16 to handle burst ISR events)
    s_isr_queue = xQueueCreate(16, sizeof(isr_event_t));

    // ── Configure PIR: input, pull-down, rising edge ISR ─────────────────────
    gpio_config_t pir_cfg = {};
    pir_cfg.pin_bit_mask = (1ULL << DD_PIR_GPIO);
    pir_cfg.mode         = GPIO_MODE_INPUT;
    pir_cfg.pull_up_en   = GPIO_PULLUP_DISABLE;
    pir_cfg.pull_down_en = GPIO_PULLDOWN_ENABLE;
    pir_cfg.intr_type    = GPIO_INTR_POSEDGE;
    gpio_config(&pir_cfg);

    // ── Configure Doorbell: input, pull-up, falling edge ISR (active LOW) ────
    gpio_config_t db_cfg = {};
    db_cfg.pin_bit_mask = (1ULL << DD_DOORBELL_GPIO);
    db_cfg.mode         = GPIO_MODE_INPUT;
    db_cfg.pull_up_en   = GPIO_PULLUP_ENABLE;
    db_cfg.pull_down_en = GPIO_PULLDOWN_DISABLE;
    db_cfg.intr_type    = GPIO_INTR_NEGEDGE;
    gpio_config(&db_cfg);

    // ── Configure Buzzer: output ──────────────────────────────────────────────
    gpio_config_t buz_cfg = {};
    buz_cfg.pin_bit_mask = (1ULL << DD_BUZZER_GPIO);
    buz_cfg.mode         = GPIO_MODE_OUTPUT;
    buz_cfg.pull_up_en   = GPIO_PULLUP_DISABLE;
    buz_cfg.pull_down_en = GPIO_PULLDOWN_DISABLE;
    buz_cfg.intr_type    = GPIO_INTR_DISABLE;
    gpio_config(&buz_cfg);
    gpio_set_level(DD_BUZZER_GPIO, 0);

    // ── Install GPIO ISR service and attach handlers ──────────────────────────
    gpio_install_isr_service(0);
    gpio_isr_handler_add(DD_PIR_GPIO,      pir_isr_handler,      nullptr);
    gpio_isr_handler_add(DD_DOORBELL_GPIO, doorbell_isr_handler, nullptr);

    // ── Initialize UART1 for mmWave (SEN0395) ────────────────────────────────
    uart_config_t uart_cfg = {};
    uart_cfg.baud_rate  = DD_MMWAVE_BAUD;
    uart_cfg.data_bits  = UART_DATA_8_BITS;
    uart_cfg.parity     = UART_PARITY_DISABLE;
    uart_cfg.stop_bits  = UART_STOP_BITS_1;
    uart_cfg.flow_ctrl  = UART_HW_FLOWCTRL_DISABLE;
    uart_cfg.source_clk = UART_SCLK_DEFAULT;
    uart_param_config(DD_MMWAVE_UART_NUM, &uart_cfg);
    uart_set_pin(DD_MMWAVE_UART_NUM,
                 DD_MMWAVE_TX_GPIO, DD_MMWAVE_RX_GPIO,
                 UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    uart_driver_install(DD_MMWAVE_UART_NUM, 1024, 0, 0, nullptr, 0);

    // ── Fusion state ──────────────────────────────────────────────────────────
    bool    pir_triggered = false;
    int64_t pir_ts        = 0;
    int64_t last_pir_ts   = 0;  // for debounce

    // UART line buffer
    char line_buf[128];
    int  line_len = 0;

    ESP_LOGI(TAG, "Sensor task ready");

    while (true) {
        // ── Process ISR events (PIR / Doorbell) ──────────────────────────────
        isr_event_t isr_ev;
        while (xQueueReceive(s_isr_queue, &isr_ev, 0) == pdTRUE) {
            int64_t now_ms = (int64_t)(esp_timer_get_time() / 1000LL);

            if (isr_ev == ISR_PIR) {
                // Debounce
                if ((now_ms - last_pir_ts) >= DD_PIR_DEBOUNCE_MS) {
                    last_pir_ts   = now_ms;
                    pir_triggered = true;
                    pir_ts        = now_ms;
                    ESP_LOGD(TAG, "PIR triggered at %lld ms", pir_ts);
                }
            } else if (isr_ev == ISR_DOORBELL) {
                ESP_LOGI(TAG, "Doorbell pressed");
                dd_event_t ev = {};
                ev.type         = DD_EVENT_DOORBELL;
                ev.timestamp_ms = now_ms;
                ev.distance_m   = 0.0f;
                snprintf(ev.clip_id, sizeof(ev.clip_id), "%lld", (long long)now_ms);
                xQueueSend(event_queue, &ev, 0);
                add_to_event_log(&ev);
                last_event_ts = now_ms;
                // Beep buzzer 100ms
                buzzer_beep(100);
            }
        }

        // ── Read and parse mmWave UART data ───────────────────────────────────
        uint8_t byte;
        // Read up to 64 bytes per iteration to avoid starving other processing
        for (int i = 0; i < 64; i++) {
            int n = uart_read_bytes(DD_MMWAVE_UART_NUM, &byte, 1, pdMS_TO_TICKS(0));
            if (n <= 0) break;

            if (byte == '\n') {
                line_buf[line_len] = '\0';
                int   presence  = 0;
                float distance  = 0.0f;
                if (parse_jybss(line_buf, &presence, &distance)) {
                    if (presence == 1 && distance <= DD_MMWAVE_MAX_DISTANCE_M) {
                        int64_t now_ms = (int64_t)(esp_timer_get_time() / 1000LL);
                        if (pir_triggered &&
                            (now_ms - pir_ts) <= DD_MMWAVE_CONFIRM_WINDOW_MS) {
                            // Fusion confirmed — post MOTION event
                            ESP_LOGI(TAG, "MOTION confirmed: dist=%.2f m", distance);
                            dd_event_t ev = {};
                            ev.type         = DD_EVENT_MOTION;
                            ev.timestamp_ms = now_ms;
                            ev.distance_m   = distance;
                            snprintf(ev.clip_id, sizeof(ev.clip_id), "%lld", (long long)now_ms);
                            xQueueSend(event_queue, &ev, 0);
                            add_to_event_log(&ev);
                            last_event_ts = now_ms;
                            pir_triggered = false;
                        }
                    }
                }
                line_len = 0;
            } else if (byte != '\r') {
                if (line_len < (int)sizeof(line_buf) - 1) {
                    line_buf[line_len++] = (char)byte;
                } else {
                    // Line too long — reset buffer
                    line_len = 0;
                }
            }
        }

        // ── False-positive suppression: PIR with no mmWave confirm ───────────
        if (pir_triggered) {
            int64_t now_ms = (int64_t)(esp_timer_get_time() / 1000LL);
            if ((now_ms - pir_ts) > DD_MMWAVE_CONFIRM_WINDOW_MS) {
                ESP_LOGD(TAG, "PIR false positive suppressed (no mmWave confirm)");
                pir_triggered = false;
            }
        }

        // 10ms loop period — responsive to ISR events and UART data
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}
