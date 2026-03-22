#include "shared/dd_types.h"
#include "config/dd_config.h"

extern "C" {
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "freertos/event_groups.h"
#include "driver/spi_master.h"
#include "esp_vfs_fat.h"
#include "sdmmc_cmd.h"
#include "driver/sdspi_host.h"
#include "esp_log.h"
#include "esp_timer.h"
}

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <errno.h>

static const char *TAG = "storage";

#define SD_SPI_HOST  SPI2_HOST
#define CLIPS_DIR    DD_SD_MOUNT_POINT "/clips"

static sdmmc_card_t *s_card = nullptr;

// ── Mount SD card ─────────────────────────────────────────────────────────────
static esp_err_t mount_sd(void)
{
    spi_bus_config_t bus_cfg = {};
    bus_cfg.mosi_io_num     = DD_SD_MOSI_GPIO;
    bus_cfg.miso_io_num     = DD_SD_MISO_GPIO;
    bus_cfg.sclk_io_num     = DD_SD_SCLK_GPIO;
    bus_cfg.quadwp_io_num   = -1;
    bus_cfg.quadhd_io_num   = -1;
    bus_cfg.max_transfer_sz = 4096;

    esp_err_t ret = spi_bus_initialize(SD_SPI_HOST, &bus_cfg, SDSPI_DEFAULT_DMA);
    if (ret != ESP_OK && ret != ESP_ERR_INVALID_STATE) {
        ESP_LOGE(TAG, "SPI bus init failed: %s", esp_err_to_name(ret));
        return ret;
    }

    sdspi_device_config_t slot = SDSPI_DEVICE_CONFIG_DEFAULT();
    slot.gpio_cs  = DD_SD_CS_GPIO;
    slot.host_id  = (spi_host_device_t)SD_SPI_HOST;

    sdmmc_host_t host = SDSPI_HOST_DEFAULT();

    esp_vfs_fat_sdmmc_mount_config_t mount_cfg = {};
    mount_cfg.format_if_mount_failed = false;
    mount_cfg.max_files              = 8;
    mount_cfg.allocation_unit_size  = 16 * 1024;

    ret = esp_vfs_fat_sdspi_mount(DD_SD_MOUNT_POINT, &host, &slot, &mount_cfg, &s_card);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "SD mount failed: %s", esp_err_to_name(ret));
        return ret;
    }

    // Ensure clips directory exists
    struct stat st;
    if (stat(CLIPS_DIR, &st) != 0) {
        mkdir(CLIPS_DIR, 0755);
    }

    sdmmc_card_print_info(stdout, s_card);
    ESP_LOGI(TAG, "SD card mounted at %s", DD_SD_MOUNT_POINT);
    return ESP_OK;
}

// ── LIST_CLIPS: scan dir, build JSON ─────────────────────────────────────────
static void list_clips(char *buf, size_t buf_size, size_t *out_len)
{
    DIR *dir = opendir(CLIPS_DIR);
    if (!dir) {
        const char *empty = "{\"clips\":[]}";
        strncpy(buf, empty, buf_size - 1);
        buf[buf_size - 1] = '\0';
        *out_len = strlen(buf);
        return;
    }

    size_t pos = 0;
    pos += (size_t)snprintf(buf + pos, buf_size - pos, "{\"clips\":[");

    bool first = true;
    struct dirent *entry;
    while ((entry = readdir(dir)) != nullptr) {
        if (entry->d_type != DT_REG) continue;
        // Filter .avi files only
        const char *dot = strrchr(entry->d_name, '.');
        if (!dot || strcmp(dot, ".avi") != 0) continue;

        char path[320];
        snprintf(path, sizeof(path), "%s/%s", CLIPS_DIR, entry->d_name);

        struct stat st;
        if (stat(path, &st) != 0) continue;

        // clip_id = filename without extension
        char clip_id[32];
        size_t stem_len = (size_t)(dot - entry->d_name);
        if (stem_len >= sizeof(clip_id)) stem_len = sizeof(clip_id) - 1;
        strncpy(clip_id, entry->d_name, stem_len);
        clip_id[stem_len] = '\0';

        // Derive ts from clip_id (it IS the unix ms timestamp)
        long long ts_ms = atoll(clip_id);

        // Estimate duration from file size and bitrate
        uint32_t bitrate_bytes_sec = (DD_VIDEO_BITRATE_KBPS * 1000) / 8;
        uint32_t dur_sec = (bitrate_bytes_sec > 0)
                            ? (uint32_t)(st.st_size / bitrate_bytes_sec)
                            : 0;

        if (!first) {
            pos += (size_t)snprintf(buf + pos, buf_size - pos, ",");
        }
        first = false;
        pos += (size_t)snprintf(buf + pos, buf_size - pos,
            "{\"clipId\":\"%s\",\"ts\":%lld,\"durationSec\":%lu,\"sizeBytes\":%ld}",
            clip_id, ts_ms, (unsigned long)dur_sec, (long)st.st_size);

        if (pos >= buf_size - 64) break; // guard against overflow
    }
    closedir(dir);

    pos += (size_t)snprintf(buf + pos, buf_size - pos, "]}");
    *out_len = pos;
}

// ── storage_task ──────────────────────────────────────────────────────────────
void storage_task(void *pvParam)
{
    ESP_LOGI(TAG, "Storage task started");

    // Try to mount SD card; retry every 5s on failure
    while (mount_sd() != ESP_OK) {
        ESP_LOGW(TAG, "SD mount failed, retrying in 5s");
        vTaskDelay(pdMS_TO_TICKS(5000));
    }
    xEventGroupSetBits(system_eg, BIT_SD_MOUNTED);

    while (true) {
        storage_cmd_t cmd;
        if (xQueueReceive(storage_queue, &cmd, pdMS_TO_TICKS(1000)) != pdTRUE) {
            continue;
        }

        switch (cmd.cmd) {

        case STORAGE_WRITE_CLIP: {
            if (!cmd.data || cmd.data_len == 0) break;
            FILE *f = fopen(cmd.filename, "wb");
            if (!f) {
                ESP_LOGE(TAG, "Cannot open %s for write: %s", cmd.filename, strerror(errno));
                free(cmd.data);
                break;
            }
            const uint8_t *p   = cmd.data;
            size_t remaining   = cmd.data_len;
            while (remaining > 0) {
                size_t chunk = (remaining < 4096) ? remaining : 4096;
                size_t written = fwrite(p, 1, chunk, f);
                p         += written;
                remaining -= written;
                if (written < chunk) {
                    ESP_LOGE(TAG, "Short write on %s", cmd.filename);
                    break;
                }
            }
            fclose(f);
            free(cmd.data);
            ESP_LOGI(TAG, "Clip written: %s (%u bytes)", cmd.filename, (unsigned)cmd.data_len);
            break;
        }

        case STORAGE_DELETE_CLIP: {
            char path[128];
            snprintf(path, sizeof(path), "%s/%s.avi", CLIPS_DIR, cmd.filename);
            if (remove(path) == 0) {
                ESP_LOGI(TAG, "Deleted clip: %s", path);
            } else {
                ESP_LOGW(TAG, "Delete failed for %s: %s", path, strerror(errno));
            }
            break;
        }

        case STORAGE_LIST_CLIPS: {
            if (!cmd.resp_buf || !cmd.resp_sem) break;
            list_clips(cmd.resp_buf, cmd.resp_buf_size, (size_t *)&cmd.resp_len);
            // Signal caller
            xSemaphoreGive(cmd.resp_sem);
            break;
        }

        default:
            ESP_LOGW(TAG, "Unknown storage cmd %d", (int)cmd.cmd);
            break;
        }
    }
}
