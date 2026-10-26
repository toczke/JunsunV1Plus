# SojunerOS 20.0 — Build and Deployment Guide

**Target Platform:** Junsun V1 Plus / JunCan UI03 (Topway TS-8667-02)  
**Base:** SojunerOS 20.0 (LineageOS 20 / Android 13)  
**Host Architecture:** Linux x86_64 (Ubuntu 22.04 LTS / Fedora 39+)  

---

## 1. Prerequisites & Environment Setup

### Required Build Tools
Install host compilation packages:
```bash
sudo apt-get update && sudo apt-get install -y \
    bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
    git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev \
    libelf-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev \
    libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool \
    squashfs-tools xsltproc zip zlib1g-dev python3 python3-pip \
    android-sdk-libsparse-utils android-sdk-platform-tools simg2img
```

Ensure Android platform tools and sparse utilities are available:
```bash
which simg2img lpmake lpunpack avbtool unpack_bootimg
```

---

## 2. Dual Build Configurations

SojunerOS supports two distinct deployment targets depending on testing goals:

| Configuration | Target User | Base Stack | Compatibility Status |
| :--- | :--- | :--- | :--- |
| **`sojuneros-production`** *(Recommended)* | Daily Driving | Modernized Stock Android 10 + DUDU-OS + `CarSettingsBridge` + Magisk | **100% Hardware Functional** (CAN, DSP, 360 AVM, SWC, Fan) |
| **`sojuneros-gsi-exp`** *(Experimental)* | Core Developers | LineageOS 20 GSI (Android 13) + VNDK 29 Bridge | Requires AIDL/HIDL shim debugging |

---

## 3. Automated ROM Assembly (Production Pipeline)

The repository provides an end-to-end builder script: [`tools/build_sojuneros.sh`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/tools/build_sojuneros.sh).

### Step 1: Prepare Partition Images
Place verified stock partitions into the extract staging directory:
```bash
mkdir -p /home/tomasztoczek/Downloads/fw_8667_extract/partitions
# Verify presence of system.img, vendor.img, product.img, boot.img
ls -lh /home/tomasztoczek/Downloads/fw_8667_extract/partitions/
```

### Step 2: Execute Build Pipeline
```bash
cd /home/tomasztoczek/Documents/GitHub/JunsunV1Plus
bash tools/build_sojuneros.sh
```

The script automatically executes:
1. Verification of stock partition integrity and SHA-256 hashes.
2. Invocation of [`tools/debloat_and_customize.sh`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/tools/debloat_and_customize.sh) to purge Chinese telemetry and backdoors.
3. Injection of `CarSettingsBridge.apk` into `/system/priv-app/CarSettingsBridge`.
4. Configuration of SurfaceFlinger overlays for forced 1280x720 landscape orientation.
5. Whitelisting of automotive hardware apps:
   - Front Dashcam DVR (`com.ankai.cardvr`)
   - Tire Pressure Monitor (`com.ts.main.tpms`)
   - External USB DVD Box (`com.vendor.DvdBox`)
   - ROHM DSP Equalizer (`com.ts.set.dsp`)
6. Assembly of dynamic `super.img` via `lpmake`.
7. Generation of release metadata manifest.

---

## 4. Packaging into `8667.bin` & `8667.upd`

Topway headunits read updates from a single bundled container `8667.bin` matched with `8667.upd`.

### Step 1: Splicing into Container
To inject a custom recovery (e.g., TWRP) or updated partition into the container:
```bash
python3 tools/patch_firmware.py \
    path/to/stock/8667.bin \
    path/to/twrp_ts8667.img \
    out/8667.bin
```

### Step 2: Generating Checksum File
The script automatically generates `out/8667.upd` containing the 32-character MD5 checksum:
```bash
cat out/8667.upd
# Output: [32-char hex string]
```

---

## 5. Deployment Procedures

### Method A: Flashing via USB Thumb Drive (Recommended)
1. Format a USB drive (16GB or 32GB) with **FAT32** file system and MBR partition table.
2. Copy `8667.bin` and `8667.upd` directly to the **root directory** of the USB drive:
   ```
   E:\ (USB Root)
   ├── 8667.bin
   └── 8667.upd
   ```
3. Insert the USB drive into **USB Port 1 (4-pin)** on the rear harness of the TS8667.
4. Turn on the car ignition or bench power supply (12V–14.4V).
5. The Topway bootloader (`lk.img`) detects the valid header and checksum and initiates the automatic upgrade screen.
6. **Do not interrupt power** during the 5–7 minute flashing sequence.
7. Remove the USB drive when prompted by the green "Update Successful" screen.

### Method B: Flashing via TWRP Recovery
1. Boot into TWRP using the `TS8667_TWRP_Flasher` APK or `adb reboot recovery`.
2. Connect USB drive with update zip or image.
3. In TWRP:
   - Select **Install** > **Install Image**.
   - Select target partition (`Super` or `System Image`).
   - Swipe to confirm Flash.
   - Wipe Dalvik/Cache and Reboot System.
