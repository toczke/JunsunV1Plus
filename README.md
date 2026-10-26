# Junsun V1 Plus / Topway TS8667 (MT8667 / MT6768) Automotive Headunit Knowledge Base

Complete technical reverse-engineering documentation, hardware specifications, partition layouts, binary formats, pre-installed app audits, backdoors, root methods, custom recovery (TWRP) porting, and custom ROM development guide for the **Junsun V1 Plus / Topway TS8667 / JunCan UI03** MediaTek MT8667 Android Car Headunit.

---

## 📑 Documentation Index

1. [Hardware & Platform Architecture](docs/01_hardware_architecture.md)
   - SoC, Octa-Core big.LITTLE CPU details, GPU, memory, power management (MT6358).
   - Display & Touch controller chips (Goodix GT1151 / GT9886, MIPI DSI panels).
   - Audio DSP (ROHM BD3702FV), FM Tuner (MT6631), 360° Vision decoder (Techpoint TP2850).
   - Connectivity (Wi-Fi dual-band, Bluetooth 5.0, 4G LTE Cat-7 modem, GPS/GNSS).
   - UART serial console pinout & 921600 baud debugging.

2. [Firmware Packaging & Binary Formats](docs/02_firmware_packaging_and_partitions.md)
   - MediaTek `xj66` container format breakdown.
   - Exact byte-level partition map for `8667.bin`.
   - Android 10 Dynamic Partitions (`super.img` with `system`, `vendor`, `product`).
   - Trailing boot, recovery, dtbo, lk, and atf images.
   - Integrity validation mechanism (`8667.upd` MD5).

3. [Operating System, Android Version & Spoofing Quirks](docs/03_os_and_version_spoofing.md)
   - Real Android version: Android 10 (Q, API 29, Kernel 4.14).
   - Detailed analysis of the Chinese vendor spoofing trick (`ro.forfan.version.release=13`, AIDA64 spoofing).
   - Project Treble support & GSI compatibility.

4. [Pre-installed Applications & OEM Framework](docs/04_apps_and_ecosystem.md)
   - Complete inventory of `/system/app`, `/system/priv-app`, `/vendor/app`, `/product/app`.
   - Topway OEM suite (`tsoem`): JunCan UI03 (3D Car Model theme).
   - Smartphone integration: Native Apple CarPlay (`sd_carplay` daemon by SuDing) & Android Auto (`CarLetter`).
   - 360° Around View Monitoring (`AVM2`, `TsAVM`, `360Camera`).
   - Google Mobile Services (GMS) pre-installed suite.

5. [Vehicle CAN Bus Integration & Protocols](docs/05_vehicle_and_canbus.md)
   - 342 built-in vehicle profiles (`com.ts.can.*`).
   - Supported brands: VW, BMW, Mercedes, Toyota, Honda, Ford, PSA, Renault, Nissan, Mitsubishi, OBD-II.
   - Steering wheel controls (Key1/Key2 analog ADC study).

6. [Security Audits, Root Access & Backdoors](docs/06_security_root_and_backdoors.md)
   - Pre-installed root binaries: `/system/xbin/ffsu` and `/system/bin/rootremount`.
   - ADB root elevation methods without bootloader unlock.
   - Factory settings secret codes and passwords (`8888`, `3368`, `1617`, `123456`).

7. [Custom Recovery (TWRP) Porting & Image Repacking](docs/07_twrp_and_repacking_guide.md)
   - Boot Image Header v2 architecture and offsets.
   - Landscape mode configuration (1280x720).
   - Device tree for TWRP compilation (`BoardConfig.mk`, `recovery.fstab`).
   - Splicing repacked recovery into `8667.bin` and updating `8667.upd`.

8. [Modern Custom OS Strategy](docs/08_modern_custom_os_strategy.md)
   - Decoupling hardware services (MCU, CAN, DSP, 360° AVM) from the user layer.
   - Removing stock CarPlay/Android Auto (`sd_carplay`, `CarLetter`, `EasyConnect`) for DiPlay.
   - Custom headunit ROM ecosystem analysis (DUDU-OS, Malaysk, Hal9k).
   - 3-phase implementation roadmap.

9. [Custom ROM Feasibility & Android 12-17 Porting Analysis](docs/09_custom_rom_feasibility_analysis.md)
   - Deep architectural audit: GKI, Linux 4.19 kernel, VNDK bridges, 16KB page size constraint.
   - MediaTek MT8667/MT6768 BSP availability across Android 10, 11, 12, 13, 14+.
   - GSI (Generic System Image) vs. Vendor HAL porting breakdown.
   - Forced 1280x720 landscape automotive UI enforcement.

10. [MainUI Decompilation & Stock Android Settings Integration](docs/10_mainui_decompilation_and_settings_integration.md)
   - Complete decompilation map of `classes.dex` and `classes2.dex`.
   - Comprehensive table of all secret developer codes (`8878`, `8888`, `1617`, `0129`, `4848`).
   - Car Settings Bridge architecture (`car_settings_bridge/`) injecting "Car Settings" directly into AOSP Settings.
   - Hardware retention matrix: DVR (`com.ankai.cardvr`), TPMS, DVD player, and DUDU-OS launcher.

---

## 🛠️ Repository Components

- **`twrp_device_tree/`**: Official TWRP 10.0 device tree configured in forced landscape (1280x720) with prebuilt kernel, dtb, and recovery_dtbo.
- **`installer_apk/`**: One-click TWRP Installer Android App utilizing `/system/xbin/ffsu` for zero-PC recovery flashing and backup.
- **`car_settings_bridge/`**: Native Android app injecting "Car Settings" into stock Android Settings, providing passwordless direct access to reversing camera, SWC, CAN Bus, DSP, fan control, and factory menus.
- **`tools/patch_firmware.py`**: Automated Python tool for inspecting, extracting, and splicing partitions into `8667.bin` with `8667.upd` MD5 regeneration.
- **`tools/debloat_and_customize.sh`**: Shell script to prune Chinese telemetry, strip stock junk launchers, enforce DUDU-OS, and preserve vehicle hardware apps.
- **`.github/workflows/build_all.yml`**: GitHub Actions automated pipeline to compile TWRP recovery, Flasher APK, and Car Settings Bridge.

---

## 🕵️‍♂️ Privacy & Backdoor Reality Check: What Can the Chinese Vendor Actually See?

When buying a Chinese Android headunit (Junsun, Topway, FYT, Mekede), many users ask:
> *"Does the manufacturer have a backdoor into my car? Can they track where I drive, listen through the microphone, or read my data?"*

Based on reverse-engineering the stock firmware binaries, here is the plain-English truth:

### 1. What the Chinese Vendor CANNOT Do (No Active Remote Spyware)
- **No Active Cloud Spyware:** There is no hidden background daemon continuously streaming your microphone, front dashcam video, or GPS location to servers in China. The core car framework (`MainUI.apk`, `AVM2.apk`) contains zero hardcoded remote telemetry URLs or reporting servers.
- **No Remote Cellular Backdoor:** The 4G LTE modem and SIM subsystem run standard MediaTek RIL (`mtk-ril.so`). The vendor cannot remotely dial in or wake up the headunit when the car ignition is off (`sys.ipo.pwrdncap=2` deep standby).

### 2. What the Chinese Vendor / Third Parties DO Collect (Telemetry & Licensing)
- **App Activation & Fingerprinting:**
  - Apps like **`CarLetter`**, **`EasyConnect`**, and **`TsActivateCarDev`** check hardware licensing. When connected to Wi-Fi or mobile data, they phone home to licensing servers with:
    - Your headunit's motherboard serial number / UUID.
    - MediaTek modem IMEI and MAC addresses.
    - Approximate location via IP address.
- **EasyConnect Data Collection:**
  - `EasyConnect` is known in the automotive reverse-engineering community for aggressively logging phone device IDs, phone models, and connection timestamps when you plug in your phone via USB.
- **OTA Update Heartbeat (`TsUpgrade.apk`):**
  - When the unit has an internet connection, the OTA updater queries Topway update servers with your firmware build version (`QP1A.190711.020`, `p5spm8666p164P2`) to check if an update is available.

### 3. The REAL Threat: Local Security Vulnerabilities
The real security danger on this headunit is not state-sponsored surveillance, but **complete lack of local device security**:
1. **Pre-installed Unauthenticated Root (`ffsu`):** Any malicious Android app you install from the Play Store or via APK can silently execute `/system/xbin/ffsu` or `/system/bin/rootremount` and gain full `uid=0` root access without prompting you.
2. **Open Wireless ADB:** Because `persist.sys.usb.config=adb` is enabled by default, anyone on the same Wi-Fi network (or vehicle hotspot) who runs `adb connect <headunit_ip>:5555` can gain an unrestricted root shell, take screenshots, install apps, or read files from `/data`.
3. **Hardcoded Master Passwords:** Physical or passenger access to the Settings app allows entering `8888` or `3368` to alter critical MCU CAN bus parameters, display timings, or wipe calibration data.

---

## ⚡ Quick Reference Card

| Item | Details |
|---|---|
| **Marketing Name** | Junsun V1 Plus / JunCan UI03 |
| **ODM / Motherboard** | Topway / TengShi `TS-8667-02` (`spm8667p1_64`) |
| **Processor** | MediaTek MT8667 / MT6768 (2× Cortex-A75 @ 2.0GHz + 6× Cortex-A55 @ 2.0GHz) |
| **GPU** | ARM Mali-G52 MC2 |
| **True OS** | Android 10 (Q) - API Level 29 (Kernel 4.14.186+) |
| **Advertised OS** | "Android 13" (Spoofed via `ro.forfan.aida64.version.sdk=33`) |
| **Resolution** | 1280 × 720 (16:9 Landscape) |
| **Build Type** | `userdebug` (Rootable, test-keys, adb enabled) |
| **Factory Passwords** | `8888`, `3368`, `1617`, `123456`, `8878` |
| **UART Debugging** | `ttyS0` @ 921600 baud (8N1) |
| **Root Command** | `adb shell ffsu` or `adb shell rootremount` |
