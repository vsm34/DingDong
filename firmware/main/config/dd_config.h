#pragma once
#ifndef DD_CONFIG_H
#define DD_CONFIG_H

extern "C" {
#include "driver/gpio.h"
#include "driver/uart.h"
}

// ── Camera DVP (OV5640) ───────────────────────────────────────────────────────
#define DD_CAM_D0_GPIO       GPIO_NUM_8
#define DD_CAM_D1_GPIO       GPIO_NUM_16
#define DD_CAM_D2_GPIO       GPIO_NUM_15
#define DD_CAM_D3_GPIO       GPIO_NUM_7
#define DD_CAM_D4_GPIO       GPIO_NUM_6
#define DD_CAM_D5_GPIO       GPIO_NUM_5
#define DD_CAM_D6_GPIO       GPIO_NUM_4
#define DD_CAM_D7_GPIO       GPIO_NUM_10
#define DD_CAM_PCLK_GPIO     GPIO_NUM_9
#define DD_CAM_XCLK_GPIO     GPIO_NUM_11
#define DD_CAM_HREF_GPIO     GPIO_NUM_3
#define DD_CAM_VSYNC_GPIO    GPIO_NUM_46
#define DD_CAM_SDA_GPIO      GPIO_NUM_14   // I2C SDA
#define DD_CAM_SCL_GPIO      GPIO_NUM_13   // I2C SCL
#define DD_CAM_RESETB_GPIO   GPIO_NUM_21
#define DD_CAM_PWDN_GPIO     GPIO_NUM_47   // Verify against final Altium sheet

// ── microSD SPI ───────────────────────────────────────────────────────────────
#define DD_SD_CS_GPIO        GPIO_NUM_38
#define DD_SD_MOSI_GPIO      GPIO_NUM_39
#define DD_SD_SCLK_GPIO      GPIO_NUM_40
#define DD_SD_MISO_GPIO      GPIO_NUM_41
#define DD_SD_MOUNT_POINT    "/sdcard"

// ── PIR Sensor ────────────────────────────────────────────────────────────────
#define DD_PIR_GPIO          GPIO_NUM_42   // Rising edge interrupt

// ── mmWave Radar UART (DFRobot SEN0395) ──────────────────────────────────────
#define DD_MMWAVE_UART_NUM   UART_NUM_1
#define DD_MMWAVE_TX_GPIO    GPIO_NUM_43   // ESP TX → mmWave RX
#define DD_MMWAVE_RX_GPIO    GPIO_NUM_44   // ESP RX ← mmWave TX
#define DD_MMWAVE_BAUD       115200

// ── Doorbell Button ───────────────────────────────────────────────────────────
#define DD_DOORBELL_GPIO     GPIO_NUM_2    // Active LOW, falling edge, pulled up via R6

// ── Buzzer ────────────────────────────────────────────────────────────────────
#define DD_BUZZER_GPIO       GPIO_NUM_1    // Active HIGH, through R5

// ── System Constants ──────────────────────────────────────────────────────────
#define DD_DEVICE_ID_LEN          16
#define DD_TOKEN_LEN              32
#define DD_TOKEN_HEX_LEN          65
#define DD_SOFTAP_SSID            "DingDong-Setup"
#define DD_SOFTAP_MAX_CONN        1
#define DD_HTTP_PORT              80
#define DD_MDNS_HOSTNAME_PREFIX   "dingdong-"

// ── Motion Fusion ─────────────────────────────────────────────────────────────
#define DD_MMWAVE_CONFIRM_WINDOW_MS   2000
#define DD_MMWAVE_MAX_DISTANCE_M      5.0f
#define DD_PIR_DEBOUNCE_MS            500

// ── Rate Limiting ─────────────────────────────────────────────────────────────
#define DD_AUTH_FAIL_MAX         5
#define DD_AUTH_FAIL_WINDOW_MS   60000

// ── Clip Settings ─────────────────────────────────────────────────────────────
#define DD_DEFAULT_CLIP_LENGTH_SEC   10
#define DD_MAX_CLIP_LENGTH_SEC       30
#define DD_VIDEO_BITRATE_KBPS        1500

// ── Cloud Function ────────────────────────────────────────────────────────────
#define DD_CLOUD_FUNCTION_URL   "https://us-central1-dingdong-596c2.cloudfunctions.net/notify"
#define DD_HMAC_NONCE_LEN       16
#define DD_TIMESTAMP_TOLERANCE_MS   60000

#endif // DD_CONFIG_H
