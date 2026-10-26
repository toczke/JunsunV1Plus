# Pre-installed Firmware Applications Selection & Retention Matrix

This document categorizes every stock application extracted from the firmware, explains its low-level hardware role, and distinguishes between **mandatory vehicle daemons** and **optional user-facing apps**.

---

## 🟢 Category 1: CORE VEHICLE SERVICES (Mandatory)
These components are responsible for hardware communication with the motherboard MCU (`/dev/ttyMT1`), vehicle CAN bus, camera decoders, and audio amplifiers. Without them, the headunit behaves as an ordinary generic tablet with zero vehicle connectivity.

| Application / Package | Hardware Functionality | Retention Recommendation |
| :--- | :--- | :--- |
| **`MainUI.apk`** (`com.ts.MainUI`) | **Hardware Brain**: Interfaces with MCU serial port `/dev/ttyMT1` and CAN bus decoder. Processes reverse gear signals, resistive steering wheel keys (SWC), AM/FM tuner, and hardware audio attenuation. | **RETAIN (in Headless Mode)**. Strip legacy stock media player UIs, but preserve the underlying daemon and vehicle configuration activities. |
| **`AVM2.apk` / `360Camera.apk`** | Handles 360° panoramic cameras and the **Techpoint TP2850** AHD decoder. Merges 4 video feeds into an overhead bird's-eye view with dynamic trajectory guidelines. | **RETAIN**. Wired to reverse gear and camera activation triggers. |
| **`CStudyMainActivity`** (MainUI) | Calibration interface for analog resistive steering wheel buttons (Key1 / Key2) in vehicles without digital CAN bus. | **RETAIN**. Critical for mapping steering wheel controls. |
| **`fan.apk` / `ElectricFanActivity`** | Controls active CPU cooling fan based on SoC junction temperature sensors. | **RETAIN**. Protects MediaTek MT8667 from thermal throttling during summer heat. |
| **`logoset.apk`** | Modifies the vehicle manufacturer boot logo stored in bootloader / flash memory. | **RETAIN**. |

---

## 🔴 Category 2: OBSOLETE / BLOATWARE (Recommended for Removal)
These applications are either redundant, outdated, heavily telemetry-laden, or conflict with modern alternatives.

| Application / Package | Role in Stock ROM | Replacement / Alternative |
| :--- | :--- | :--- |
| **`sd_carplay`** (`com.suding.speedplay`) | Vendor's proprietary Apple CarPlay daemon. | Replaced by **DiPlay** / AutoKit. |
| **`CarLetter.apk`** | Stock Android Auto / CarPlay integration. | Replaced by **DiPlay**. |
| **`EasyConnect.apk` / `net.easyconn`** | Legacy Chinese screen mirroring utility with aggressive telemetry. | **REMOVE COMPLETELY**. |
| **`TsActivateCarDev` / `cpe_agent`** | Hardware activation and vendor tracking daemons phoning home. | **REMOVE COMPLETELY**. |
| **Stock Launchers UI00 - UI04** | Outdated 3D car model themes. | Replaced by **DUDU-OS Launcher** or **Agama Car Launcher**. |

---

## 🟡 Category 3: HARDWARE ACCESSORY APPS (User Choice)
Specialized apps that interface with specific hardware peripherals:

| Component | Hardware Role | Decision |
| :--- | :--- | :--- |
| **Car DVR Dashcam (`com.ankai.cardvr`)** | Controls front USB/MIPI dashcam recorder for loop recording. | **RETAIN** (if front dashcam is installed). |
| **Tire Pressure Monitoring (TPMS)** | Reads live tire pressure and temperature from USB sensors and CAN bus. | **RETAIN** (essential safety feature). |
| **External DVD Player (`DvdBox.apk`)** | Provides playback interface for USB optical drives. | **RETAIN** (cleanly isolated in `/vendor/app`). |

---

## 🚀 Recommended Custom OS Profile:
- **Default Home Launcher:** **DUDU-OS Launcher** (Automotive landscape 1280×720 UI with real-time map widgets and media player controls).
- **Phone Projection:** **DiPlay** (Modern wireless CarPlay & Android Auto).
- **Google Ecosystem:** **MicroG** (Ultra-lightweight ~30MB footprint) with optional **NikGapps Core** via TWRP.
