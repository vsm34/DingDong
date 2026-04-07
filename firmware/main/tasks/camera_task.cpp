#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "esp_camera.h"
#include "esp_heap_caps.h"
}

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static const char *TAG = "camera";

// ── Max clip buffer in PSRAM (4 MB) ──────────────────────────────────────────
#define CLIP_BUF_MAX (4 * 1024 * 1024)
#define MAX_CLIP_FRAMES 300

// ── Minimal MJPEG AVI writer ──────────────────────────────────────────────────
// Writes an MJPEG AVI into a caller-provided PSRAM buffer.
// Returns the number of bytes written, or 0 on error.

#pragma pack(push, 1)
struct AviMainHdr {
    uint32_t dwMicroSecPerFrame;
    uint32_t dwMaxBytesPerSec;
    uint32_t dwPaddingGranularity;
    uint32_t dwFlags;
    uint32_t dwTotalFrames;
    uint32_t dwInitialFrames;
    uint32_t dwStreams;
    uint32_t dwSuggestedBufferSize;
    uint32_t dwWidth;
    uint32_t dwHeight;
    uint32_t dwReserved[4];
};
struct AviStreamHdr {
    char     fccType[4];
    char     fccHandler[4];
    uint32_t dwFlags;
    uint16_t wPriority;
    uint16_t wLanguage;
    uint32_t dwInitialFrames;
    uint32_t dwScale;
    uint32_t dwRate;
    uint32_t dwStart;
    uint32_t dwLength;
    uint32_t dwSuggestedBufferSize;
    uint32_t dwQuality;
    uint32_t dwSampleSize;
    int16_t  rcLeft, rcTop, rcRight, rcBottom;
};
struct BmpInfoHdr {
    uint32_t biSize;
    int32_t  biWidth;
    int32_t  biHeight;
    uint16_t biPlanes;
    uint16_t biBitCount;
    uint32_t biCompression;
    uint32_t biSizeImage;
    int32_t  biXPelsPerMeter;
    int32_t  biYPelsPerMeter;
    uint32_t biClrUsed;
    uint32_t biClrImportant;
};
struct AviIdxEntry {
    char     ckid[4];
    uint32_t dwFlags;
    uint32_t dwChunkOffset;
    uint32_t dwChunkSize;
};
#pragma pack(pop)

static inline void put_u32(uint8_t *p, uint32_t v)
{
    p[0] = (v >>  0) & 0xFF;
    p[1] = (v >>  8) & 0xFF;
    p[2] = (v >> 16) & 0xFF;
    p[3] = (v >> 24) & 0xFF;
}
static inline void put_fourcc(uint8_t *p, const char *cc)
{
    p[0] = cc[0]; p[1] = cc[1]; p[2] = cc[2]; p[3] = cc[3];
}

// Write a 4CC chunk header (8 bytes): fourcc + size
static inline size_t write_chunk_hdr(uint8_t *buf, const char *cc, uint32_t size)
{
    put_fourcc(buf, cc);
    put_u32(buf + 4, size);
    return 8;
}
// Write a LIST chunk header (12 bytes): "LIST" + size + listtype
static inline size_t write_list_hdr(uint8_t *buf, uint32_t size, const char *lt)
{
    put_fourcc(buf, "LIST");
    put_u32(buf + 4, size);
    put_fourcc(buf + 8, lt);
    return 12;
}

static size_t build_avi(
    uint8_t *buf, size_t buf_max,
    const uint8_t **frames, const size_t *fsizes, int frame_count,
    uint16_t width, uint16_t height, uint8_t fps)
{
    if (frame_count == 0 || !buf) return 0;

    // Calculate total movi data size
    size_t movi_data = 0;
    for (int i = 0; i < frame_count; i++) {
        movi_data += 8 + fsizes[i];
        if (fsizes[i] & 1) movi_data += 1; // pad to even
    }

    // Index size
    size_t idx_size = (size_t)frame_count * sizeof(AviIdxEntry);

    // Header sizes (fixed):
    //   avih chunk:  8 + 56 = 64
    //   strh chunk:  8 + 56 = 64
    //   strf chunk:  8 + 40 = 48
    //   LIST strl:  12 + 64 + 48 = 124
    //   LIST hdrl:  12 + 64 + 124 = 200
    //   LIST movi header: 12

    size_t total = 12                     // RIFF AVI header
                 + 200                    // LIST hdrl
                 + 12 + movi_data         // LIST movi
                 + 8 + idx_size;          // idx1 chunk

    if (total > buf_max) {
        ESP_LOGW(TAG, "AVI too large for buffer (%u > %u)", (unsigned)total, (unsigned)buf_max);
        return 0;
    }

    uint8_t *p = buf;

    // RIFF AVI
    put_fourcc(p, "RIFF");
    put_u32(p + 4, (uint32_t)(total - 8));
    put_fourcc(p + 8, "AVI ");
    p += 12;

    // LIST hdrl (200 bytes total incl. 12 hdr)
    // Contents = 4 + 64 + 124 = 192 bytes
    p += write_list_hdr(p, 192, "hdrl");

    // avih (8 + 56 = 64 bytes)
    p += write_chunk_hdr(p, "avih", (uint32_t)sizeof(AviMainHdr));
    AviMainHdr *avih = (AviMainHdr *)p;
    memset(avih, 0, sizeof(*avih));
    avih->dwMicroSecPerFrame    = (fps > 0) ? (1000000u / fps) : 66667u;
    avih->dwMaxBytesPerSec      = DD_VIDEO_BITRATE_KBPS * 1000 / 8;
    avih->dwFlags               = 0x10; // AVIF_HASINDEX
    avih->dwTotalFrames         = (uint32_t)frame_count;
    avih->dwStreams              = 1;
    avih->dwSuggestedBufferSize = (uint32_t)(movi_data / frame_count + 1024);
    avih->dwWidth               = width;
    avih->dwHeight              = height;
    p += sizeof(AviMainHdr);

    // LIST strl (12 + 64 + 48 = 124 bytes)
    // Contents = 4 + 64 + 48 = 116 bytes
    p += write_list_hdr(p, 116, "strl");

    // strh (8 + 56 = 64 bytes)
    p += write_chunk_hdr(p, "strh", (uint32_t)sizeof(AviStreamHdr));
    AviStreamHdr *strh = (AviStreamHdr *)p;
    memset(strh, 0, sizeof(*strh));
    strh->fccType[0] = 'v'; strh->fccType[1] = 'i';
    strh->fccType[2] = 'd'; strh->fccType[3] = 's';
    strh->fccHandler[0] = 'M'; strh->fccHandler[1] = 'J';
    strh->fccHandler[2] = 'P'; strh->fccHandler[3] = 'G';
    strh->dwScale              = 1;
    strh->dwRate               = fps;
    strh->dwLength             = (uint32_t)frame_count;
    strh->dwSuggestedBufferSize = (uint32_t)(movi_data / frame_count + 1024);
    strh->dwQuality            = 0xFFFFFFFFu;
    strh->rcRight              = (int16_t)width;
    strh->rcBottom             = (int16_t)height;
    p += sizeof(AviStreamHdr);

    // strf = BITMAPINFOHEADER (8 + 40 = 48 bytes)
    p += write_chunk_hdr(p, "strf", (uint32_t)sizeof(BmpInfoHdr));
    BmpInfoHdr *strf = (BmpInfoHdr *)p;
    memset(strf, 0, sizeof(*strf));
    strf->biSize        = sizeof(BmpInfoHdr);
    strf->biWidth       = (int32_t)width;
    strf->biHeight      = (int32_t)height;
    strf->biPlanes      = 1;
    strf->biBitCount    = 24;
    strf->biCompression = 0x47504A4Du; // 'MJPG'
    strf->biSizeImage   = (uint32_t)(width * height * 3);
    p += sizeof(BmpInfoHdr);

    // LIST movi
    uint8_t *movi_start = p;
    p += write_list_hdr(p, (uint32_t)(4 + movi_data), "movi");
    uint8_t *movi_data_start = p;

    // Write index entries alongside frame data
    // We'll collect index info while writing frames
    // Allocate temp index on stack is risky; use a static buffer
    static AviIdxEntry s_idx[MAX_CLIP_FRAMES];

    for (int i = 0; i < frame_count; i++) {
        size_t offset = (size_t)(p - movi_data_start);
        s_idx[i].ckid[0] = '0'; s_idx[i].ckid[1] = '0';
        s_idx[i].ckid[2] = 'd'; s_idx[i].ckid[3] = 'c';
        s_idx[i].dwFlags       = 0x10; // AVIIF_KEYFRAME
        s_idx[i].dwChunkOffset = (uint32_t)offset;
        s_idx[i].dwChunkSize   = (uint32_t)fsizes[i];

        p += write_chunk_hdr(p, "00dc", (uint32_t)fsizes[i]);
        memcpy(p, frames[i], fsizes[i]);
        p += fsizes[i];
        if (fsizes[i] & 1) { *p++ = 0; } // pad
    }
    (void)movi_start; // suppress unused warning

    // idx1 chunk
    p += write_chunk_hdr(p, "idx1", (uint32_t)idx_size);
    memcpy(p, s_idx, idx_size);
    p += idx_size;

    return (size_t)(p - buf);
}

// ── Camera init ───────────────────────────────────────────────────────────────
/** Matches esp32-camera `camera_probe()` reset/PWDN sequencing so a preflight scan sees an awake sensor. */
static void camera_apply_reset_lines(int pin_pwdn, int pin_reset)
{
    if (pin_pwdn >= 0) {
        gpio_config_t conf = {};
        conf.pin_bit_mask = 1ULL << (unsigned)pin_pwdn;
        conf.mode         = GPIO_MODE_OUTPUT;
        esp_err_t err = gpio_config(&conf);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "PWDN gpio_config failed: %s", esp_err_to_name(err));
            return;
        }
        err = gpio_set_level((gpio_num_t)pin_pwdn, 1);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "PWDN set HIGH failed: %s", esp_err_to_name(err));
            return;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
        err = gpio_set_level((gpio_num_t)pin_pwdn, 0);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "PWDN set LOW failed: %s", esp_err_to_name(err));
            return;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
    if (pin_reset >= 0) {
        gpio_config_t conf = {};
        conf.pin_bit_mask = 1ULL << (unsigned)pin_reset;
        conf.mode         = GPIO_MODE_OUTPUT;
        esp_err_t err = gpio_config(&conf);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "RESET gpio_config failed: %s", esp_err_to_name(err));
            return;
        }
        err = gpio_set_level((gpio_num_t)pin_reset, 0);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "RESET set LOW failed: %s", esp_err_to_name(err));
            return;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
        err = gpio_set_level((gpio_num_t)pin_reset, 1);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "RESET set HIGH failed: %s", esp_err_to_name(err));
            return;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
    vTaskDelay(pdMS_TO_TICKS(10));
}

/** Short I2C scan on the camera SCCB pins (same port as CONFIG_SCCB_HARDWARE_I2C_PORT1). Bus deleted before esp_camera_init. */
static esp_err_t camera_log_sccb_preflight_scan(void)
{
    i2c_master_bus_config_t bus_cfg = {};
    bus_cfg.i2c_port          = DD_CAM_SCCB_I2C_PORT;
    bus_cfg.scl_io_num        = DD_CAM_SCL_GPIO;
    bus_cfg.sda_io_num        = DD_CAM_SDA_GPIO;
    bus_cfg.clk_source        = I2C_CLK_SRC_DEFAULT;
    bus_cfg.glitch_ignore_cnt = 7;
    bus_cfg.flags.enable_internal_pullup = 1;

    i2c_master_bus_handle_t bus = nullptr;
    esp_err_t bus_ret           = i2c_new_master_bus(&bus_cfg, &bus);
    if (bus_ret != ESP_OK) {
        ESP_LOGW(TAG, "SCCB preflight: could not create I2C bus: %s", esp_err_to_name(bus_ret));
        return bus_ret;
    }

    char line[192];
    size_t pos  = 0;
    int    nack = 0;
    for (int addr = 0x08; addr < 0x78; addr++) {
        if (i2c_master_probe(bus, addr, pdMS_TO_TICKS(50)) == ESP_OK) {
            pos += (size_t)snprintf(line + pos, sizeof(line) - pos, "%s0x%02x", nack ? " " : "", addr);
            nack++;
            if (pos >= sizeof(line) - 12) {
                break;
            }
        }
    }

    esp_err_t del_ret = i2c_del_master_bus(bus);
    if (del_ret != ESP_OK) {
        ESP_LOGE(TAG, "SCCB preflight: i2c_del_master_bus failed: %s", esp_err_to_name(del_ret));
        return del_ret;
    }

    if (nack > 0) {
        ESP_LOGI(TAG, "SCCB preflight scan (7-bit ACK): %s (expect 0x3c for OV5640)", line);
    } else {
        ESP_LOGW(TAG,
                 "SCCB preflight: no devices ACK — I2C dead or sensor held off (OV5640=0x3c). "
                 "Check FPC, rails, PWDN/RST wiring vs GPIO %d / %d.",
                 (int)DD_CAM_PWDN_GPIO, (int)DD_CAM_RESETB_GPIO);
    }
    return ESP_OK;
}

static esp_err_t init_camera(void)
{
    ESP_LOGI(TAG,
             "Camera pins: SDA=%d SCL=%d RST=%d PWDN=%d VSYNC=%d HREF=%d PCLK=%d XCLK=%d",
             (int)DD_CAM_SDA_GPIO, (int)DD_CAM_SCL_GPIO, (int)DD_CAM_RESETB_GPIO,
             (int)DD_CAM_PWDN_GPIO, (int)DD_CAM_VSYNC_GPIO, (int)DD_CAM_HREF_GPIO,
             (int)DD_CAM_PCLK_GPIO, (int)DD_CAM_XCLK_GPIO);

    camera_config_t cfg = {};
    cfg.pin_pwdn     = DD_CAM_PWDN_GPIO;
    cfg.pin_reset    = DD_CAM_RESETB_GPIO;
    cfg.pin_xclk     = DD_CAM_XCLK_GPIO;
    cfg.pin_sccb_sda = DD_CAM_SDA_GPIO;
    cfg.pin_sccb_scl = DD_CAM_SCL_GPIO;
    cfg.pin_d7       = DD_CAM_D7_GPIO;
    cfg.pin_d6       = DD_CAM_D6_GPIO;
    cfg.pin_d5       = DD_CAM_D5_GPIO;
    cfg.pin_d4       = DD_CAM_D4_GPIO;
    cfg.pin_d3       = DD_CAM_D3_GPIO;
    cfg.pin_d2       = DD_CAM_D2_GPIO;
    cfg.pin_d1       = DD_CAM_D1_GPIO;
    cfg.pin_d0       = DD_CAM_D0_GPIO;
    cfg.pin_vsync    = DD_CAM_VSYNC_GPIO;
    cfg.pin_href     = DD_CAM_HREF_GPIO;
    cfg.pin_pclk     = DD_CAM_PCLK_GPIO;
    cfg.xclk_freq_hz = 20000000;
    cfg.ledc_timer   = LEDC_TIMER_0;
    cfg.ledc_channel = LEDC_CHANNEL_0;
    cfg.pixel_format = PIXFORMAT_JPEG;
    cfg.frame_size   = FRAMESIZE_HD;
    cfg.jpeg_quality = 12;
    cfg.fb_count     = 2;
    cfg.fb_location  = CAMERA_FB_IN_PSRAM;
    cfg.grab_mode    = CAMERA_GRAB_WHEN_EMPTY;

    camera_apply_reset_lines(cfg.pin_pwdn, cfg.pin_reset);
    vTaskDelay(pdMS_TO_TICKS(200));
    esp_err_t preflight_err = camera_log_sccb_preflight_scan();
    if (preflight_err != ESP_OK) {
        ESP_LOGE(TAG, "SCCB preflight failed before esp_camera_init: %s", esp_err_to_name(preflight_err));
        return preflight_err;
    }
    vTaskDelay(pdMS_TO_TICKS(50));

    esp_err_t err = esp_camera_init(&cfg);

    if (err == ESP_ERR_NOT_SUPPORTED) {
        ESP_LOGE(TAG,
                 "OV5640 probe failed: no SCCB ACK or wrong chip ID. "
                 "Check camera FPC, 2.8V/1.8V rails, and schematic for PWDN(GPIO%d)/RESET(GPIO%d) "
                 "(PRD 15.2: verify PWDN).",
                 (int)DD_CAM_PWDN_GPIO, (int)DD_CAM_RESETB_GPIO);
        ESP_LOGE(TAG,
                 "See SCCB preflight line above: if no ACK at 0x3c, fix hardware; "
                 "if ACK at 0x3c but still fail, enable more drivers in menuconfig or verify sensor is OV5640.");
    }
    return err;
}

// ── camera_task ───────────────────────────────────────────────────────────────
void camera_task(void *pvParam)
{
    ESP_LOGI(TAG, "Camera task started");

    esp_err_t err = init_camera();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Camera init failed: %s", esp_err_to_name(err));
        vTaskDelete(nullptr);
        return;
    }
    xEventGroupSetBits(system_eg, BIT_CAMERA_READY);
    ESP_LOGI(TAG, "Camera ready");

    // Per-frame pointer and size arrays (allocated in task to avoid stack issues)
    static const uint8_t *s_fptrs[MAX_CLIP_FRAMES];
    static size_t         s_fsizes[MAX_CLIP_FRAMES];

    while (true) {
        dd_event_t ev;

        // ── Streaming: push frames when active and no event pending ───────────
        EventBits_t bits = xEventGroupGetBits(system_eg);
        if ((bits & BIT_STREAMING_ACTIVE) &&
            uxQueueMessagesWaiting(event_queue) == 0) {
            // Switch to QVGA for stream
            sensor_t *s = esp_camera_sensor_get();
            if (s) s->set_framesize(s, FRAMESIZE_QVGA);

            camera_fb_t *fb = esp_camera_fb_get();
            if (fb) {
                camera_fb_t *fb_copy = fb; // pass ownership to stream_frame_queue
                if (xQueueSend(stream_frame_queue, &fb_copy, 0) != pdTRUE) {
                    // Drop frame if queue full
                    esp_camera_fb_return(fb);
                }
                // stream_task is responsible for returning the fb after sending
            }
            vTaskDelay(pdMS_TO_TICKS(50)); // ~20 fps cap for streaming
            continue;
        }

        // ── Wait for motion/doorbell event (100ms timeout) ────────────────────
        if (xQueueReceive(event_queue, &ev, pdMS_TO_TICKS(100)) != pdTRUE) {
            continue;
        }

        ESP_LOGI(TAG, "Recording clip for event type=%d ts=%lld", ev.type, ev.timestamp_ms);

        // Pause streaming during clip capture
        xEventGroupClearBits(system_eg, BIT_STREAMING_ACTIVE);

        // Switch to HD for clip
        sensor_t *s = esp_camera_sensor_get();
        if (s) s->set_framesize(s, FRAMESIZE_HD);

        // Allocate clip buffer in PSRAM
        uint8_t *clip_buf = (uint8_t *)heap_caps_malloc(CLIP_BUF_MAX, MALLOC_CAP_SPIRAM);
        if (!clip_buf) {
            ESP_LOGE(TAG, "Failed to allocate clip buffer");
            continue;
        }

        // Read clip_length_sec under mutex
        uint8_t clip_sec;
        if (xSemaphoreTake(settings_mutex, pdMS_TO_TICKS(100)) == pdTRUE) {
            clip_sec = dd_settings.clip_length_sec;
            xSemaphoreGive(settings_mutex);
        } else {
            clip_sec = DD_DEFAULT_CLIP_LENGTH_SEC;
        }

        // ── Capture frames ────────────────────────────────────────────────────
        int64_t capture_end_ms = (int64_t)(esp_timer_get_time() / 1000LL)
                                 + (int64_t)clip_sec * 1000LL;
        int     frame_count = 0;
        size_t  data_offset = 0; // offset into clip_buf for frame data

        // Frame data is stored sequentially in clip_buf + header area
        // We'll use the second half of clip_buf for raw frame data
        // and first MAX_CLIP_FRAMES*8 bytes for pointer/size bookkeeping offsets
        // Actually: store frame data starting at offset 0 into a sub-buffer
        // and collect pointers to regions within that buffer.
        // Since we pass const uint8_t* to build_avi, we need them to remain valid.

        uint8_t *frame_data_area = clip_buf; // raw frame bytes stored here

        while (frame_count < MAX_CLIP_FRAMES) {
            int64_t now_ms = (int64_t)(esp_timer_get_time() / 1000LL);
            if (now_ms >= capture_end_ms) break;

            camera_fb_t *fb = esp_camera_fb_get();
            if (!fb) {
                vTaskDelay(pdMS_TO_TICKS(5));
                continue;
            }

            // Check if frame fits in remaining buffer
            // Reserve the last 64KB for AVI overhead
            size_t frame_area_limit = CLIP_BUF_MAX - 65536;
            if (data_offset + fb->len > frame_area_limit) {
                esp_camera_fb_return(fb);
                break; // buffer full
            }

            memcpy(frame_data_area + data_offset, fb->buf, fb->len);
            s_fptrs[frame_count]  = frame_data_area + data_offset;
            s_fsizes[frame_count] = fb->len;
            data_offset += fb->len;
            frame_count++;

            esp_camera_fb_return(fb);
        }

        uint8_t fps = (clip_sec > 0 && frame_count > 0)
                        ? (uint8_t)(frame_count / clip_sec)
                        : 10;
        if (fps == 0) fps = 1;

        ESP_LOGI(TAG, "Captured %d frames in %u sec", frame_count, clip_sec);

        // ── Build AVI into second PSRAM allocation ────────────────────────────
        size_t avi_buf_size = CLIP_BUF_MAX / 2; // use half for AVI output
        uint8_t *avi_buf = (uint8_t *)heap_caps_malloc(avi_buf_size, MALLOC_CAP_SPIRAM);
        size_t avi_len = 0;
        if (avi_buf && frame_count > 0) {
            avi_len = build_avi(avi_buf, avi_buf_size,
                                s_fptrs, s_fsizes, frame_count,
                                1280, 720, fps);
        }
        heap_caps_free(clip_buf); // frame data no longer needed

        if (avi_len > 0) {
            // Post WRITE_CLIP to storage_queue
            storage_cmd_t cmd = {};
            cmd.cmd      = STORAGE_WRITE_CLIP;
            cmd.data     = avi_buf; // storage_task will free
            cmd.data_len = avi_len;
            snprintf(cmd.filename, sizeof(cmd.filename),
                     "%s/clips/%lld.avi",
                     DD_SD_MOUNT_POINT, (long long)ev.timestamp_ms);
            if (xQueueSend(storage_queue, &cmd, pdMS_TO_TICKS(5000)) != pdTRUE) {
                ESP_LOGE(TAG, "Storage queue full, discarding clip");
                heap_caps_free(avi_buf);
            } else {
                ESP_LOGI(TAG, "Clip queued: %s (%u bytes)", cmd.filename, (unsigned)avi_len);
                // Fill in clip_id in event
                snprintf((char *)ev.clip_id, sizeof(ev.clip_id), "%lld",
                         (long long)ev.timestamp_ms);
            }
        } else {
            if (avi_buf) heap_caps_free(avi_buf);
            ESP_LOGW(TAG, "No frames captured or AVI build failed");
        }

        // Trigger notification (runs in this task's context)
        send_notify(&ev);
    }
}
