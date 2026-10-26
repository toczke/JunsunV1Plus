# SojunerOS — Automotive Android 13 Custom ROM

> **Operating System:** SojunerOS 20.0 (Based on LineageOS 20 / Android 13 Tiramisu)  
> **Target Device:** Junsun V1 Plus / Topway TS8667 (MediaTek MT8667 / MT6768)  
> **Display:** 1280 × 720 (16:9 Landscape Forced)  
> **License:** Apache-2.0 / GPL-2.0  

---

## 🏎️ Overview & Vision

**SojunerOS** is a specialized, debloated, privacy-first custom automotive Android distribution engineered specifically for Chinese MediaTek MT8667 / MT6768 (Topway TS10 / TS8667) automotive headunits.

Built upon the robust **LineageOS 20 (Android 13)** open-source foundation, SojunerOS completely strips out Chinese vendor tracking, telemetry daemons, and insecure backdoors while providing full hardware parity for all essential automotive vehicle features:
- **Steering Wheel Controls (SWC):** Analog resistive (KEY1/KEY2) and digital CAN bus button mapping.
- **CAN Bus Integration:** Multi-brand vehicle protocol decoding engine (`libcan59.so`) with Climatronic AC overlay, door/trunk open visualizers, and parking radar.
- **Reversing Camera & 360° AVM:** Instant reverse-gear screen takeover (`BackcarService`) with dynamic guidelines powered by Techpoint TP2850 AHD decoder.
- **High-Fidelity Audio & DSP:** 32-band equalizer, individual speaker delay alignment, subwoofer cutoff filters, and smart bass boost via ROHM BD3702 processor.
- **Thermal Protection:** Background thermal governor service (`CpuTempUtilsService`) controlling the active cooling fan.
- **Vehicle Peripherals:** Retained support for Front Dashcam/DVR (`com.ankai.cardvr`), tire pressure monitoring (TPMS), and external USB DVD player (`DvdBox`).

---

## 🧩 Software Stack Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                   SOJUNEROS USER INTERFACE LAYER                       │
│  - Default Home Screen: DUDU-OS Launcher (Landscape 1280x720)         │
│  - Settings Integration: Car Settings Bridge (AOSP Settings Tile)      │
│  - Phone Projection: DiPlay / AutoKit (Clean wireless CarPlay & AA)    │
│  - Play Services: MicroG Core (~30MB RAM) / Optional NikGapps Core     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ LineageOS 20 / Android 13 Framework
┌───────────────────────────────────▼────────────────────────────────────┐
│              SOJUNEROS AUTOMOTIVE HARDWARE DAEMONS                     │
│  - MainUI Headless Daemon: UART serial bridge (/dev/ttyMT1) to MCU     │
│  - CAN Bus Service: libcan59.so (340+ vehicle profiles)                │
│  - Reversing Camera: BackcarService + Techpoint TP2850 AHD decoder     │
│  - DSP Sound Engine: ROHM BD3702FV 32-band equalizer driver            │
│  - Thermal Governor: CpuTempUtilsService (Cooling fan trip @ 60°C)     │
│  - Peripherals: com.ankai.cardvr (DVR), TPMS stack, DvdBox.apk         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Android 10 Vendor HAL Compatibility
┌───────────────────────────────────▼────────────────────────────────────┐
│                  KERNEL & LOW-LEVEL HARDWARE LAYER                     │
│  - Kernel: Linux 4.14.186+ (arm64, MediaTek MT8667 Octa-Core)          │
│  - GPU: ARM Mali-G52 MC2 (Vulkan & OpenGL ES 3.2)                      │
│  - Partitions: Dynamic Partitions (super.img: system, vendor, product) │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Repository & Device Tree Layout

- **`device/topway/ts8667/`**:
  - `lineage_ts8667.mk`: LineageOS 20 target definition.
  - `BoardConfig.mk`: Hardware architecture, dynamic partitions, and MT8667 kernel offsets.
  - `device.mk`: Package inclusions (`CarSettingsBridge`, automotive audio, HAL bridges).
  - `overlay/`: Forced landscape (1280x720) resource configurations.
  - `prebuilt/`: Extracted kernel binary, DTB, and recovery_dtbo.
- **`vendor/topway/ts8667/`**:
  - `proprietary-files.txt`: Proprietary vendor HALs and MCU/CAN libraries.
- **`car_settings_bridge/`**:
  - Companion application injecting the "Car Settings" menu directly into Stock Settings.
- **`installer_apk/`**:
  - Zero-PC TWRP flasher APK utilizing local root exploit.
- **`tools/`**:
  - `build_sojuneros.sh`: Automated pipeline script to assemble and package SojunerOS.
  - `debloat_and_customize.sh`: De-bloating and sanitization script.
  - `patch_firmware.py`: Packaging tool for generating flashable `8667.bin` containers.

---

## 🚀 Building SojunerOS from Source

### Prerequisites
- Ubuntu 20.04 / 22.04 LTS x86_64
- Minimum 16GB RAM + 150GB disk space
- OpenJDK 17, `repo`, Python 3, `git-lfs`

### Steps
1. **Initialize LineageOS 20 source tree:**
   ```bash
   mkdir -p ~/sojuneros
   cd ~/sojuneros
   repo init -u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs
   repo sync -c -j$(nproc --all) --no-tags --no-clone-bundle
   ```

2. **Clone the SojunerOS TS8667 Device Tree:**
   ```bash
   git clone -b android-13-custom-rom https://github.com/toczke/JunsunV1Plus.git device/topway/ts8667
   ```

3. **Compile the ROM:**
   ```bash
   source build/envsetup.sh
   lunch lineage_ts8667-userdebug
   mka bacon -j$(nproc --all)
   ```
