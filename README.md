# Junsun V1 Plus / Topway TS8667 (MT8667 / MT6768) Automotive Headunit Knowledge Base

Complete technical reverse-engineering documentation, hardware specifications, partition layouts, binary formats, pre-installed app audits, backdoors, root methods, and custom recovery (TWRP) porting guide for the **Junsun V1 Plus / Topway TS8667 / JunCan UI03** MediaTek MT8667 Android Car Headunit.

---

## 📑 Documentation Index
8. [Modern Custom OS Strategy](docs/08_modern_custom_os_strategy.md)
   - Decoupling hardware services (MCU, CAN, DSP, 360° AVM) from the user layer.
   - Removing stock CarPlay/Android Auto (sd_carplay, CarLetter, EasyConnect) for DiPlay.
   - Custom headunit ROM ecosystem analysis (DUDU-OS, Malaysk, Hal9k).
   - 3-phase implementation roadmap.

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
