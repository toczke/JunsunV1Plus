# Chapter 4: Pre-installed Applications & OEM Framework

Comprehensive catalog and behavioral analysis of applications installed across `/system/app`, `/system/priv-app`, `/vendor/app`, and `/system/tsoem`.

---

## 1. Car-Specific & OEM Apps Overview

### 1.1 Core Vehicle Framework (`MainUI.apk`)
- **Package:** `com.ts.MainUI`
- **Location:** `/system/app/MainUI/MainUI.apk` (71 MB)
- **Role:** The central heart of the automotive software stack. It handles:
  - Serial communication with the MCU (Microcontroller Unit) on `/dev/ttyMT1` / `/dev/ttyS1`.
  - Steering wheel resistive analog key learning (`CStudyMainActivity`).
  - Radio tuner interface (AM/FM frequency tuning, RDS text display).
  - Bluetooth calling and A2DP audio streaming (`SettingBtActivity`).
  - Equalizer and ROHM BD3702 DSP parameter adjustments (`SetDspMainActivity`).
  - Reverse gear trigger detection (`android.intent.action.BACKCAR_SERVICE`).
  - 342 vehicle-specific CAN bus models.

### 1.2 Smartphone Integration: CarPlay & Android Auto
- **CarLetter:**
  - **APK:** `/system/app/CarLetter/CarLetter.apk`
  - **Configuration (`/system/etc/carletter.prop`):**
    - `COMPANY_LOGO=TengShi`
    - `CUSTOMER_PLATFORM=TS-8667-02`
    - `LINK_DRIVER_POSITION=Left` (LHD)
    - `LINK_MENU_OPTION_CONFIG=OVERSEAS_VERSION` (Enables Apple CarPlay and Android Auto; disables Chinese domestic HiCar/CarLife).
    - `ScreenWidth=1280`, `ScreenHeight=720`, `ScreenSize=9.2`
    - `DefaultBitrate=5000000` (5 Mbps H.264 stream).
- **Native CarPlay Daemon (`sd_carplay`):**
  - **Binary:** `/system/bin/sd_carplay`
  - **Vendor:** SuDing (速度车载).
  - **Function:** Native Linux daemon managing low-level USB iAP2 protocol and Wi-Fi Direct connection for Apple CarPlay wireless handover.
- **EasyConnect:**
  - **APKs:** `/system/tsoem/easy/EasyConnect.TS05.6.7*.apk` and `/system/tsoem/easyFree/*.apk`
  - **Role:** Alternative screen-mirroring tool for Android and iPhone over USB/Wi-Fi.

### 1.3 360° Panoramic Around View Monitoring (AVM)
- **Apps:**
  - `360Camera.apk` (`/system/app/360Camera/360Camera.apk`)
  - `AVM2.apk` (`/system/app/AVM2/AVM2.apk`)
  - `TsAVM.apk` (`/system/app/TsAVM/TsAVM.apk`)
- **Hardware Integration:** Communicates with the **Techpoint TP2850** AHD receiver to capture 4 wide-angle camera feeds.
- **Calibration Partition:** Loads lens distortion coefficients and stitching matrices from `/mnt/avm` (mapped from `/dev/block/platform/bootdevice/by-name/avm`).
- **Features:** Dynamic trajectory lines reacting to CAN bus steering wheel angle, bird's eye view bird-cage perspective, emergency hazard trigger view.

### 1.4 Active Launchers (JunCan UI Suite)
Located in `/vendor/tsoem/launcher/apks/`:
- `UI00`: `8259TsLauncher2_juncan02_1_1280x720_sign.apk`
- `UI01`: `8259TsLauncher2_juncan02_2_1280x720_sign.apk`
- `UI02`: `8259TsLauncher2_juncan02_3_1280x720_sign.apk`
- **`UI03` (Active):** `8259TsLauncher2_juncan02_4_1280x720_sign.apk` (**车模 — 3D Car Model Theme**)
  - Integrates `/system/app/3dmodel/3dmodel.apk`.
  - Displays a real-time 3D rendered avatar of a car on the home screen.
  - Intercepts CAN bus door open/close events: opening the driver door opens the virtual door on the 3D car model; turning on headlights illuminates the virtual headlights.
- `UI04`: `8259TsLauncher2_juncan05_1280x720_sign.apk`

### 1.5 Peripheral & Utility Apps
- **Fan Control (`fan.apk`):** Manages internal cooling fan PWM duty cycle based on CPU temperature read from `/sys/class/thermal/thermal_zone*`.
- **Logoset (`logoset.apk`):** Car boot logo switcher (includes BMW, Mercedes, Audi, VW, Ford, Toyota, Honda, Nissan, Hyundai logos).
- **Touch Screen Calibration (`MyTouch_sign.apk`):** Floating assistive touch button and 5-finger touch calibration tool.
- **Screen Adjust (`ScreenAdjust.apk`):** Fine-tunes LCD gamma, saturation, contrast, and backlight curve.
- **Car DVR Dashcam (`com.ankai.cardvr`):** Front collision recorder supporting Ankai USB/MIPI dashcam hardware.
- **Gesture Control (`TsGesture_shenghang.apk`):** IR gesture sensing for waving to change tracks or answer calls.

---

## 2. Google Mobile Services (GMS) Suite

The firmware includes official pre-installed Google Mobile Services (GMS) in `/system/priv-app/`:

| App Name | Package / APK | Purpose |
|---|---|---|
| **Google Play Store** | `Phonesky.apk` | App marketplace |
| **Google Play Services** | `PrebuiltGmsCore.apk` | GMS APIs, location, auth |
| **Google Services Framework** | `GoogleServicesFramework.apk` | Account sync and push notifications |
| **Google Maps** | `Google-Maps.apk` (in `/vendor/app/`) | Navigation |
| **Google Search & Assistant** | `Velvet.apk` | Voice search & assistant |
| **Google Chrome** | `Chrome.apk` (in `/vendor/app/`) | Web browser |
| **Gboard** | `Gboard.apk` (in `/vendor/app/`) | Virtual keyboard |
| **Google Text-to-Speech** | `GoogleTTS.apk` | Speech synthesis |

---

## 3. Media & Third-Party Streaming Apps

Located in `/vendor/app/`:
- **YouTube:** `/vendor/app/youtube/youtube.apk`
- **Netflix:** `/vendor/app/Netflix/Netflix.apk`
- **External DVD Player:** `/vendor/app/DvdBox/DvdBox.apk` (support for external USB DVD drive boxes).
