# Chapter 8: Modern Custom OS Strategy for Junsun V1 Plus / TS8667

Architectural blueprint for building a debloated, modern Android OS for this unit that preserves all essential automotive features (CAN bus, MCU, DSP audio, 360° AVM, steering wheel controls) while dropping native CarPlay/Android Auto in favor of third-party solutions (DiPlay, Carlinkit, Headunit Reloaded, open-headunit).

---

## 1. The Headunit Software Stack Decoupling

To understand what can be modernized and what must be preserved, examine the three software layers of this device:

```
┌────────────────────────────────────────────────────────────────────────┐
│ USER EXPERIENCE LAYER (Can be fully replaced & modernized)             │
│ - Launcher (DUDUOS Launcher, Agama, CarWebGuru, Nova, Vivid)           │
│ - Media Players (Poweramp, Spotify, Apple Music, VLC)                  │
│ - Phone Projection: DiPlay, Headunit Reloaded, open-headunit           │
│ - Navigation: Google Maps, Waze, Yandex, OsmAnd                       │
├────────────────────────────────────────────────────────────────────────┤
│ AUTOMOTIVE HARDWARE SERVICE LAYER (MUST BE PRESERVED / ADAPTED)        │
│ - /system/app/MainUI (MCU serial communication, CAN bus vehicle state) │
│ - /system/app/360Camera + AVM2 (TP2850 AHD 4-camera video receiver)    │
│ - /system/set/dsp (ROHM BD3702 sound processor equalizer & fader)      │
│ - /system/app/CStudy (Key1/Key2 analog steering wheel button learning) │
│ - /system/app/fan (Thermal CPU temperature polling & cooling fan PWM)  │
├────────────────────────────────────────────────────────────────────────┤
│ LINUX KERNEL & VENDOR HAL LAYER (HARDWARE BOUNDARY)                    │
│ - Linux 4.14 ARM64 kernel + MT6768 Device Tree Blobs                   │
│ - MediaTek MT6358 PMIC / Audio DAC HAL                                 │
│ - Goodix GT1151 / GT9886 touchscreen I2C driver                        │
│ - Techpoint TP2850 AHD video driver (/vendor/lib64/tp2850_*)           │
│ - MediaTek MT6631 FM radio combo driver                                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Removing Stock Phone Projection (CarPlay / Android Auto)

Since **DiPlay** and independent apps will be used instead of the stock closed-source projection engine, the following components can be cleanly removed from `/system` and `/vendor`:

| Stock Component | Location | Purpose & Reason for Removal |
|---|---|---|
| **`sd_carplay`** | `/system/bin/sd_carplay` | SuDing proprietary CarPlay native daemon. Consumes background CPU and holds USB port hooks. |
| **`CarLetter`** | `/system/app/CarLetter/CarLetter.apk` | Stock CarPlay / Android Auto projection app. |
| **`EasyConnect`** | `/system/tsoem/easy/EasyConnect*.apk` | Chinese screen mirroring tool (often bundled with aggressive background analytics). |
| **`EasyConnect Free`**| `/system/tsoem/easyFree/*.apk` | FreeUSB variation of EasyConnect. |
| **`TsActivateCarDev`**| `/system/app/TsActivateCarDev/` | OEM licensing and activation check daemon for CarPlay/Android Auto. |

Removing these saves ~120 MB in `/system` and frees up USB endpoints, allowing **DiPlay** or third-party USB dongles (e.g. Carlinkit CPC200-CCPA) to claim exclusive control of USB ports without port conflicts.

---

## 3. Preserving Essential Car Hardware Features

To keep all car functions working without the stock OEM bloat:

### 3.1 MCU & CAN Bus Integration (`com.ts.MainUI`)
- **How it works:** Topway's `MainUI.apk` contains the background service `com.ts.MainUI.MainService`. This service opens `/dev/ttyMT1` (or `/dev/ttyS1`) and exchanges binary protocol frames with the on-board STM32/GD32 MCU.
- **Why it is needed:** The MCU communicates with the external CAN bus box. If `MainService` is not running:
  - Steering wheel buttons will not register.
  - Reverse camera trigger (swapping screen to camera on reverse gear) will not fire.
  - Vehicle Climatronic / door open broadcasts will not be translated to Android intents.
- **Strategy:** Run `MainUI` in **headless / background service mode**. Strip out the stock launcher widgets, remove the stock music and video player UIs, and retain only `MainService`, `CanGolf*`/`CanToyota*` handlers, and `BackcarService`.

### 3.2 Sound Processor / Equalizer (`ROHM BD3702FV`)
- **How it works:** The ROHM sound processor is controlled via I2C commands originating from `/system/app/MainUI/` (`com.ts.set.dsp`).
- **Strategy:** Retain the DSP setting activity (`SetDspMainActivity`) or expose its parameters via broadcast intents so custom launchers (like DuduOS or Agama) can trigger preset curves (Rock, Pop, Flat) and adjust subwoofer gains directly.

### 3.3 360° Around View Monitoring (Techpoint TP2850)
- **How it works:** The 4 AHD camera streams are digitized by the TP2850 chip and converted to planar YUV. The stitching and calibration algorithms are handled by `AVM2.apk` using `/mnt/avm` calibration matrices.
- **Strategy:** Keep `/system/app/AVM2/` and `360Camera.apk`. `AVM2` registers a system overlay intent that automatically pops to the foreground whenever the reverse signal or hazard button is pressed.

### 3.4 Active Cooling Fan (`fan.apk`)
- **How it works:** Polls `/sys/class/thermal/thermal_zone0/temp` and writes PWM values to `/sys/class/leds/fan/brightness` or GPIO control nodes.
- **Strategy:** Can be replaced with a lightweight 50-line native shell daemon or root background script:
  ```bash
  #!/system/bin/sh
  while true; do
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    if [ "$TEMP" -gt 65000 ]; then
      echo 255 > /sys/class/leds/fan/brightness # Full speed
    elif [ "$TEMP" -gt 50000 ]; then
      echo 128 > /sys/class/leds/fan/brightness # Half speed
    else
      echo 0 > /sys/class/leds/fan/brightness   # Fan off
    fi
    sleep 10
  done
  ```

---

## 4. Custom ROM Ecosystem Analysis for Android Headunits

Analysis of how other headunit platforms (TS10, FYT 7862, MT8259) build custom experiences:

### 4.1 DUDU-OS (The Industry Standard for Aftermarket Headunits)
- **Origin:** Developed by DUDUAuto community for Unisoc UIS7862 and MediaTek MT8666/MT8667 platforms.
- **Architecture:** Instead of attempting to replace the proprietary vendor kernel and HALs from scratch, DUDU-OS uses a **Cleaned Base System + Modern UI Layer**:
  1. Base system is stripped of all Chinese spyware, fake version strings, and ad-laden APKs.
  2. Proprietary MCU serial services are isolated and wrapped behind clean Android `AIDL` interfaces.
  3. A desktop-grade car launcher (DUDU Launcher) acts as the home screen, providing:
     - Real-time PiP (Picture-in-Picture) for navigation (Google Maps / Yandex / Waze).
     - Global media notification player widget with blur cover art.
     - Direct Bluetooth OBD-II tire pressure and sensor widgets.
     - Clean dark/light theme switching based on vehicle headlight CAN signals (`ILLUM` line).

### 4.2 Malaysk / Hal9k ROM Approaches (Rockchip & MediaTek)
- Prominent XDA developers (Malaysk, Hal9k) created custom ROMs for PX5, PX6, and Topway units using the **Modded Stock Framework approach**:
  1. **Deodex & Patch Framework:** Modify `services.jar` and `framework.jar` to fix audio focus handling (allowing navigation voice prompts to duck background music smoothly rather than abruptly muting it).
  2. **MicroG Integration:** Replace heavy Google Play Services with MicroG to save ~400 MB of RAM, speeding up boot times significantly.
  3. **Magisk Systemless Root:** Inject Magisk into `boot.img` ramdisk for modern root modules and Viper4Android audio enhancement.

---

## 5. Implementation Roadmap for Junsun V1 Plus

```
Phase 1: Recovery & Safety Net (In Progress)
├── Compile TWRP for ts8667 in landscape orientation (1280x720)
└── Create full eMMC partition backup (super, boot, recovery, nvram, avm) via TWRP

Phase 2: Debloating Stock System
├── Unpack system.img and vendor.img with simg2img + lpunpack
├── Remove sd_carplay, CarLetter, EasyConnect, and ad trackers
├── Clean up spoofed properties in build.prop (restore true Android 10 values)
├── Install Viper4Android FX driver for enhanced BD3702 DSP tuning
└── Repack into super.img with lpmake

Phase 3: Integration of DiPlay & Modern Automotive UI
├── Pre-install modern automotive launcher (DUDU Launcher or Agama)
├── Install DiPlay for native wireless phone projection
├── Configure automatic day/night theme switching via CAN bus ILLUM line
└── Set up Viper4Android audio profile for car speakers & subwoofer crossover
```
