#pragma once
#ifndef DD_TYPES_H
#define DD_TYPES_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

extern "C" {
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/event_groups.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "esp_camera.h"
}

// ── Event Group Bits ──────────────────────────────────────────────────────────
#define BIT_WIFI_CONNECTED   (1 << 0)
#define BIT_CAMERA_READY     (1 << 1)
#define BIT_SD_MOUNTED       (1 << 2)
#define BIT_PROVISIONED      (1 << 3)
#define BIT_STREAMING_ACTIVE (1 << 4)

// ── Event Types ───────────────────────────────────────────────────────────────
typedef enum {
    DD_EVENT_MOTION   = 0,
    DD_EVENT_DOORBELL = 1,
} dd_event_type_t;

// ── Event Struct ──────────────────────────────────────────────────────────────
typedef struct {
    dd_event_type_t type;
    float           distance_m;
    int64_t         timestamp_ms;
    char            clip_id[24];
} dd_event_t;

// ── Storage Command Types ─────────────────────────────────────────────────────
typedef enum {
    STORAGE_WRITE_CLIP  = 0,
    STORAGE_DELETE_CLIP = 1,
    STORAGE_LIST_CLIPS  = 2,
} storage_cmd_type_t;

// ── Storage Command ───────────────────────────────────────────────────────────
typedef struct {
    storage_cmd_type_t  cmd;
    char                filename[64];
    uint8_t            *data;
    size_t              data_len;
    // Response mechanism for LIST_CLIPS
    char               *resp_buf;
    size_t              resp_buf_size;
    size_t              resp_len;
    SemaphoreHandle_t   resp_sem;
} storage_cmd_t;

// ── Settings ──────────────────────────────────────────────────────────────────
typedef struct {
    bool    motion_enabled;
    bool    notify_enabled;
    uint8_t mmwave_threshold;
    uint8_t clip_length_sec;
} dd_settings_t;

// ── Shared Handles (defined in main.cpp) ─────────────────────────────────────
extern QueueHandle_t      event_queue;        // depth 10, dd_event_t
extern QueueHandle_t      storage_queue;      // depth 5,  storage_cmd_t
extern QueueHandle_t      stream_frame_queue; // depth 2,  camera_fb_t*
extern EventGroupHandle_t system_eg;
extern SemaphoreHandle_t  settings_mutex;
extern dd_settings_t      dd_settings;

// ── Event Log (circular buffer for GET /events) ───────────────────────────────
#define DD_EVENT_LOG_SIZE 50
extern dd_event_t         event_log[DD_EVENT_LOG_SIZE];
extern volatile int       event_log_head;
extern volatile int       event_log_count;
extern SemaphoreHandle_t  event_log_mutex;

// ── Last Event Timestamp (for GET /health) ────────────────────────────────────
extern volatile int64_t   last_event_ts;

// ── Helper: Add event to circular log ─────────────────────────────────────────
void add_to_event_log(const dd_event_t *ev);

// ── Task Function Declarations ────────────────────────────────────────────────
extern "C" {
void sensor_task(void *pvParam);
void camera_task(void *pvParam);
void storage_task(void *pvParam);
void wifi_task(void *pvParam);
void stream_task(void *pvParam);
}

// ── Settings Loader (defined in notify_client.cpp) ───────────────────────────
void load_settings_from_nvs(void);

// ── Notify Client ─────────────────────────────────────────────────────────────
void send_notify(const dd_event_t *ev);

#endif // DD_TYPES_H
