# Chapter 7: Custom Recovery (TWRP) Porting & Image Repacking Guide

Complete guide on porting Team Win Recovery Project (TWRP) for the Junsun V1 Plus / TS8667 in landscape orientation (1280×720) and injecting it into `8667.bin`.

---

## 1. TWRP Device Tree Structure

To compile TWRP from source using Android 10 (`twrp-10.0` or `omni-10.0`), set up your tree at `device/topway/ts8667`:

```
device/topway/ts8667/
├── Android.mk
├── AndroidProducts.mk
├── BoardConfig.mk
├── device.mk
├── omni_ts8667.mk
├── recovery.fstab
└── prebuilt/
    ├── kernel            (Stock extracted Linux 4.14 kernel)
    ├── dtb               (Stock extracted MT6768 device tree blob)
    └── recovery_dtbo     (Stock extracted recovery DTBO overlay)
```

---

## 2. Configuration Files

### 2.1 `BoardConfig.mk`
```makefile
DEVICE_PATH := device/topway/ts8667

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 := armeabi-v7a
TARGET_CPU_VARIANT := cortex-a53
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_VARIANT := cortex-a53

# Kernel & Boot Image Header v2
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x07c80000
BOARD_TAGS_OFFSET := 0x0bc80000
BOARD_DTB_OFFSET := 0x0bc80000
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 buildvariant=userdebug

TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/recovery_dtbo
BOARD_INCLUDE_RECOVERY_DTBO := true

# Storage & Partitions
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_SUPER_PARTITION_SIZE := 4294967296
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 4290772992
BOARD_MAIN_PARTITION_LIST := system vendor product

# TWRP UI Configuration: LANDSCAPE MODE
TW_THEME := landscape_hdpi
TARGET_SCREEN_WIDTH := 1280
TARGET_SCREEN_HEIGHT := 720
TW_SCREEN_BLANK_ON_BOOT := true

# Touch Digitizer Support
TW_INPUT_BLACKLIST := "hbtp_vm"
RECOVERY_TOUCHSCREEN_FLIP_X := false
RECOVERY_TOUCHSCREEN_FLIP_Y := false

# Extra Features
TW_NO_USB_STORAGE := false
TW_EXCLUDE_APEX := true
TW_INCLUDE_CRYPTO := false
TW_EXTRA_LANGUAGES := true
```

### 2.2 `recovery.fstab`
```text
/system         ext4    /dev/block/mapper/system        flags=display="System";backup=1;logical
/vendor         ext4    /dev/block/mapper/vendor        flags=display="Vendor";backup=1;logical
/product        ext4    /dev/block/mapper/product       flags=display="Product";backup=1;logical
/data           ext4    /dev/block/by-name/userdata     flags=display="Data";encryptable=userdata
/cache          ext4    /dev/block/by-name/cache        flags=display="Cache"
/boot           emmc    /dev/block/by-name/boot         flags=display="Boot";backup=1;flashimg=1
/recovery       emmc    /dev/block/by-name/recovery     flags=display="Recovery";backup=1;flashimg=1
/dtbo           emmc    /dev/block/by-name/dtbo         flags=display="DTBO";backup=1
/logo           emmc    /dev/block/by-name/logo         flags=display="Logo";backup=1
/nvram          emmc    /dev/block/by-name/nvram        flags=display="NVRAM";backup=1
/nvdata         ext4    /dev/block/by-name/nvdata       flags=display="NVData";backup=1
/protect_f      ext4    /dev/block/by-name/protect1     flags=display="Protect_F";backup=1
/protect_s      ext4    /dev/block/by-name/protect2     flags=display="Protect_S";backup=1
/avm            ext4    /dev/block/by-name/avm          flags=display="360_AVM_Calibration";backup=1
/usb_otg        vfat    /dev/block/sdb1  /dev/block/sdb flags=display="USB Flash Drive";storage;wipeingui;removable
```

---

## 3. Repacking TWRP into `8667.bin`

Once your TWRP ramdisk (`twrp_ramdisk.cpio.gz`) is compiled:

### Step 1: Pack the Boot Image
```bash
mkbootimg \
  --kernel prebuilt/kernel \
  --ramdisk twrp_ramdisk.cpio.gz \
  --dtb prebuilt/dtb \
  --recovery_dtbo prebuilt/recovery_dtbo \
  --base 0x40000000 \
  --kernel_offset 0x00080000 \
  --ramdisk_offset 0x07c80000 \
  --tags_offset 0x0bc80000 \
  --dtb_offset 0x0bc80000 \
  --pagesize 2048 \
  --os_version 10.0.0 \
  --os_patch_level 2021-06 \
  --header_version 2 \
  --cmdline "bootopt=64S3,32N2,64N2 buildvariant=userdebug" \
  -o twrp_recovery.img
```

### Step 2: Sign with AVB Footer
```bash
avbtool add_hash_footer \
  --image twrp_recovery.img \
  --partition_size 33554432 \
  --partition_name recovery \
  --algorithm SHA256_RSA2048 \
  --key /usr/share/avb/testkey_rsa2048.pem
```

### Step 3: Splice into `8667.bin`
Because `recovery.img` sits directly after `super.img` at byte offset **`3,823,939,840` (`0xe3ecb100`)**:
```bash
# Inject the 32MB recovery into 8667.bin in-place
dd if=twrp_recovery.img of=8667.bin bs=1 seek=3823939840 conv=notrunc
```

### Step 4: Recalculate `8667.upd`
```bash
md5sum 8667.bin | awk '{print $1}' > 8667.upd
```

### Step 5: Flash via USB
1. Copy `8667.bin` and `8667.upd` to the root of a FAT32-formatted USB flash drive.
2. Insert the USB stick into the car headunit.
3. Tap **System Update** from the Settings menu or reboot. The recovery will flash the new image.
