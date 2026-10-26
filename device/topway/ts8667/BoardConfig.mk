# ==============================================================================
# BoardConfig.mk for Junsun V1 Plus / Topway TS8667
# Target Android Version: Android 13 (Tiramisu / API 33)
# SoC: MediaTek MT8667 / MT6768 (2x A75 + 6x A55, Mali-G52)
# ==============================================================================

DEVICE_PATH := device/topway/ts8667

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a75

# 32-bit secondary ABI (Required for vehicle hardware apps: MainUI, CarDVR, TPMS)
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a55

TARGET_USES_64_BIT_BINDER := true

# Platform
TARGET_BOARD_PLATFORM := mt6768
TARGET_BOOTLOADER_BOARD_NAME := ts8667

# Kernel Configuration (Using extracted prebuilt kernel & DTB)
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.selinux=permissive
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x07c08000
BOARD_SECOND_OFFSET := 0x00e88000
BOARD_TAGS_OFFSET := 0x0bc08000
BOARD_DTB_OFFSET := 0x0bc08000
BOARD_BOOTIMG_HEADER_VERSION := 2

TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/recovery_dtbo
BOARD_INCLUDE_RECOVERY_DTBO := true

# Partitions & Dynamic Partitions
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

# Dynamic Partitions in super.img
BOARD_SUPER_PARTITION_SIZE := 4294967296
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 4290772992
BOARD_MAIN_PARTITION_LIST := system vendor product

BOARD_USES_METADATA_PARTITION := true
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product

# Android 13 Treble & HAL Bridges
BOARD_VNDK_VERSION := current
PRODUCT_COMPATIBILITY_MATRIX_LEVEL := 7

# Graphics & SurfaceFlinger (Forced Landscape 1280x720)
TARGET_SCREEN_WIDTH := 1280
TARGET_SCREEN_HEIGHT := 720
TARGET_SCREEN_DENSITY := 213

# SELinux (Permissive during initial BSP bringup)
BOARD_PLAT_PRIVATE_SEPOLICY_DIR += $(DEVICE_PATH)/sepolicy/private
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor
