#include "shared/dd_types.h"

extern "C" {
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "cJSON.h"

// NimBLE stack
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/ble_gatt.h"
#include "host/ble_gap.h"
#include "host/ble_uuid.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"
}

#include <string.h>

static const char *TAG = "ble_prov";

extern "C" void wifi_trigger_provision_connect(void);

static const ble_uuid128_t s_svc_uuid = BLE_UUID128_INIT(
    0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12, 0x34, 0x12,
    0x34, 0x12, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12
);

static const ble_uuid128_t s_chr_uuid = BLE_UUID128_INIT(
    0xbd, 0x9a, 0x78, 0x56, 0x34, 0x12, 0x34, 0x12,
    0x34, 0x12, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12
);

static int wifi_creds_write_cb(uint16_t conn_handle, uint16_t attr_handle,
                                struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn_handle;
    (void)attr_handle;
    (void)arg;

    if (ctxt->op != BLE_GATT_ACCESS_OP_WRITE_CHR) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    uint16_t len = OS_MBUF_PKTLEN(ctxt->om);
    if (len == 0 || len > 255) {
        ESP_LOGW(TAG, "Invalid payload length: %u", len);
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    char buf[256] = {};
    uint16_t out_len = 0;
    int rc = ble_hs_mbuf_to_flat(ctxt->om, buf, (uint16_t)(sizeof(buf) - 1), &out_len);
    if (rc != 0) {
        ESP_LOGE(TAG, "mbuf_to_flat failed: %d", rc);
        return BLE_ATT_ERR_UNLIKELY;
    }
    buf[out_len] = '\0';

    ESP_LOGI(TAG, "BLE write received (%u bytes)", out_len);

    cJSON *root = cJSON_Parse(buf);
    if (!root) {
        ESP_LOGW(TAG, "JSON parse failed");
        return BLE_ATT_ERR_UNLIKELY;
    }

    cJSON *j_ssid = cJSON_GetObjectItem(root, "ssid");
    cJSON *j_pass = cJSON_GetObjectItem(root, "password");
    cJSON *j_name = cJSON_GetObjectItem(root, "deviceName");

    if (!cJSON_IsString(j_ssid) || !cJSON_IsString(j_pass)) {
        ESP_LOGW(TAG, "Missing ssid or password in BLE payload");
        cJSON_Delete(root);
        return BLE_ATT_ERR_UNLIKELY;
    }

    const char *ssid = j_ssid->valuestring;
    const char *pass = j_pass->valuestring;

    if (strlen(ssid) == 0 || strlen(ssid) > 32 || strlen(pass) > 63) {
        ESP_LOGW(TAG, "Field length invalid");
        cJSON_Delete(root);
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    nvs_handle_t h;
    if (nvs_open("dingdong", NVS_READWRITE, &h) == ESP_OK) {
        nvs_set_str(h, "wifi_ssid", ssid);
        nvs_set_str(h, "wifi_pass", pass);
        if (cJSON_IsString(j_name) && strlen(j_name->valuestring) > 0) {
            nvs_set_str(h, "device_name", j_name->valuestring);
        }
        nvs_commit(h);
        nvs_close(h);
        ESP_LOGI(TAG, "BLE: credentials stored, SSID: %s", ssid);
    }

    cJSON_Delete(root);
    wifi_trigger_provision_connect();
    return 0;
}

static uint16_t s_chr_val_handle;

static const struct ble_gatt_chr_def s_chr_defs[] = {
    {
        .uuid         = &s_chr_uuid.u,
        .access_cb    = wifi_creds_write_cb,
        .arg          = nullptr,
        .descriptors  = nullptr,
        .flags        = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_NO_RSP,
        .min_key_size = 0,
        .val_handle   = &s_chr_val_handle,
    },
    { 0 },
};

static const struct ble_gatt_svc_def s_gatt_svcs[] = {
    {
        .type            = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid            = &s_svc_uuid.u,
        .includes        = nullptr,
        .characteristics = s_chr_defs,
    },
    { 0 },
};

static void ble_app_advertise(void);

static int ble_gap_event_cb(struct ble_gap_event *event, void *arg)
{
    (void)arg;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        ESP_LOGI(TAG, "BLE client connected, conn_handle=%d status=%d",
                 event->connect.conn_handle, event->connect.status);
        if (event->connect.status == 0) {
            struct ble_gap_upd_params params = {};
            params.itvl_min            = 6;
            params.itvl_max            = 12;
            params.latency             = 0;
            params.supervision_timeout = 500;
            params.min_ce_len          = 0;
            params.max_ce_len          = 0;
            ble_gap_update_params(event->connect.conn_handle, &params);
        } else {
            ble_app_advertise();
        }
        break;
    case BLE_GAP_EVENT_DISCONNECT:
        ESP_LOGI(TAG, "BLE client disconnected, reason=%d",
                 event->disconnect.reason);
        if (!(xEventGroupGetBits(system_eg) & BIT_PROVISIONED)) {
            vTaskDelay(pdMS_TO_TICKS(500));
            ble_app_advertise();
        }
        break;
    default:
        break;
    }
    return 0;
}

static void ble_app_advertise(void)
{
    ble_gap_adv_stop();

    struct ble_hs_adv_fields fields = {};
    fields.flags            = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.name             = (const uint8_t *)"DingDong-Setup";
    fields.name_len         = (uint8_t)strlen("DingDong-Setup");
    fields.name_is_complete = 1;

    int rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_gap_adv_set_fields failed: %d", rc);
        return;
    }

    struct ble_gap_adv_params adv_params = {};
    adv_params.conn_mode  = BLE_GAP_CONN_MODE_UND;
    adv_params.disc_mode  = BLE_GAP_DISC_MODE_GEN;
    adv_params.itvl_min   = 160;
    adv_params.itvl_max   = 160;

    rc = ble_gap_adv_start(BLE_OWN_ADDR_PUBLIC, nullptr,
                           BLE_HS_FOREVER, &adv_params, ble_gap_event_cb, nullptr);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_gap_adv_start failed: %d", rc);
    } else {
        ESP_LOGI(TAG, "BLE advertising as 'DingDong-Setup'");
    }
}

static void ble_app_on_sync(void)
{
    ble_app_advertise();
}

static void ble_host_task(void *param)
{
    (void)param;
    ESP_LOGI(TAG, "BLE host task started");
    nimble_port_run();
    nimble_port_freertos_deinit();
}

extern "C" void ble_prov_task(void *pvParam)
{
    (void)pvParam;

    if (xEventGroupGetBits(system_eg) & BIT_PROVISIONED) {
        ESP_LOGI(TAG, "Already provisioned — BLE prov task exiting");
        vTaskDelete(nullptr);
        return;
    }

    ESP_LOGI(TAG, "Starting BLE provisioning task");

    nimble_port_init();
    ble_hs_cfg.sync_cb = ble_app_on_sync;
    ble_svc_gap_init();
    ble_svc_gatt_init();

    int rc = ble_gatts_count_cfg(s_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_gatts_count_cfg failed: %d", rc);
        vTaskDelete(nullptr);
        return;
    }

    rc = ble_gatts_add_svcs(s_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_gatts_add_svcs failed: %d", rc);
        vTaskDelete(nullptr);
        return;
    }

    nimble_port_freertos_init(ble_host_task);

    while (!(xEventGroupGetBits(system_eg) & BIT_PROVISIONED)) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }

    ESP_LOGI(TAG, "Device provisioned — stopping BLE advertising");
    ble_gap_adv_stop();
    nimble_port_stop();
    vTaskDelete(nullptr);
}