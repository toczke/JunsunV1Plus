# Junsun V1 Plus / Topway TS8667 — Android 13 Custom ROM Branch

> **Branch:** `android-13-custom-rom`  
> **Target OS:** Android 13 (Tiramisu / API 33)  
> **Baseline SoC:** MediaTek MT8667 / MT6768 (Helio P65/G85 platform)  
> **Orientation:** Forced 16:9 Landscape (1280 × 720)

---

## 🌟 Objective & Architecture

This branch serves as the dedicated development tree for building a modern **Android 13 Custom ROM** for the Junsun V1 Plus / TS8667 headunit.

### Key Goals:
1. **Modern Core:** Upgrading from Android 10 to clean, unbloated Android 13 (AOSP / LineageOS 20 base).
2. **100% Vehicle Feature Parity:**
   - **Steering Wheel Controls (SWC):** Both resistive analog keys (Key1 / Key2) and CAN bus digital buttons.
   - **CAN Bus Integration:** Real-time decoding via `libcan59.so` and `MainService` (Climatronic AC overlay, PDC parking radar, door status).
   - **Reversing Camera & 360° AVM:** Instant reverse gear screen acquisition via `BackcarService` with dynamic guidelines.
   - **DSP & Audio:** 32-band equalizer, speaker time alignment delays, and subwoofer cutoff filters via ROHM BD3702 processor.
   - **Active CPU Cooling:** Automated thermal monitoring via `CpuTempUtilsService` triggering the electric cooling fan at 60°C.
   - **Peripherals:** Preserving Dashcam/DVR (`com.ankai.cardvr`), TPMS monitoring, and external USB DVD player (`DvdBox`).
3. **Decoupled User Experience:**
   - Default Home Launcher: **DUDU-OS Launcher** in widescreen landscape.
   - Settings: Integrated **Car Settings Bridge** (`com.topway.carsettingsbridge`) directly inside stock Android Settings.
   - GMS: Slim **MicroG** baseline with optional **NikGapps Core** via TWRP.
   - Phone Projection: Clean slate for **DiPlay** / AutoKit (stock `sd_carplay` and `CarLetter` stripped).

---

## 📁 Tree Layout

```
├── device/topway/ts8667/
│   ├── AndroidProducts.mk        # Build lunch targets: ts8667-userdebug
│   ├── BoardConfig.mk            # Architecture, kernel offsets, Treble & dynamic partitions
│   ├── device.mk                 # Hardware packages, overlays, and system properties
│   ├── overlay/                  # Automotive landscape (1280x720) resource overlays
│   └── prebuilt/                 # Extracted kernel, DTB, and recovery_dtbo
├── vendor/topway/ts8667/
│   └── proprietary-files.txt     # List of proprietary vendor HALs and CAN/MCU libraries
├── car_settings_bridge/          # Source code of the Car Settings AOSP integration app
├── installer_apk/                # One-click TWRP installer APK
└── tools/
    ├── debloat_and_customize.sh  # Strips Chinese bloatware & telemetry
    └── patch_firmware.py         # Injects images into 8667.bin with MD5 regeneration
```

---

## 🛠️ Building & Bringup Instructions

1. **Initialize AOSP / LineageOS 20 (Android 13) workspace:**
   ```bash
   repo init -u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs
   repo sync -j$(nproc --all)
   ```

2. **Clone this device tree into `device/topway/ts8667`:**
   ```bash
   git clone -b android-13-custom-rom https://github.com/toczke/JunsunV1Plus.git device/topway/ts8667
   ```

3. **Set up environment and build:**
   ```bash
   source build/envsetup.sh
   lunch ts8667-userdebug
   mka bacon -j$(nproc --all)
   ```
