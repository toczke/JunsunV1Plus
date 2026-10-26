# Chapter 10: MainUI Decompilation & Stock Android Settings Integration

> **Status:** Analysis complete following full JADX decompilation of `classes.dex`, `classes2.dex`, and APKTool resource extraction from `MainUI.apk` (firmware build `V11.1.2_20231023`).

---

## 1. Internal Architecture of `MainUI.apk`

Contrary to its name, `MainUI.apk` is not merely a launcher or front-end interface—it serves as the **central hardware abstraction daemon and HAL bridge** for the Junsun V1 Plus / Topway TS8667 platform.

### Core Architecture Layers:
1. **Native JNI Shared Libraries (`lib/armeabi-v7a/`):**
   - **`libts67xhw.so` (381 KB):** Handles low-level UART communication with the Microcontroller Unit (MCU) over `/dev/ttyMT1`. Manages analog tuner chips, power management states (sleep, ignition ACC), hardware audio volume registers, resistive touch button illumination, and camera switching.
   - **`libcan59.so` (2.75 MB):** Massive protocol parser containing decoding engines for over 340 vehicle models and CAN box manufacturers (Raise, Hiworld, SimpleSoft, Bagoo, OUDI, Xinpu, etc.).
   - **`libpymatch.so` & `libts70xicfg.so`:** Signal cross-routing and dynamic UI mapping.
2. **Headless Background Services:**
   - **`com.ts.main.common.MainService`:** Core background daemon listening on MCU serial and CAN bus pipelines.
   - **`com.ts.backcar.BackcarService`:** Automatic video pipeline switcher that grabs the screen when reverse gear is engaged (`REVERSE` wire trigger or CAN frame).
   - **`com.ts.main.cpufan.CpuTempUtilsService`:** Continuous thermal monitoring service controlling the active CPU cooling fan via MCU GPIO.
3. **Hardware Configuration Activities:**
   - Factory Engineering Menus (`com.ts.factoryset.*`)
   - User Car Settings & DSP Audio Processor (`com.ts.set.*`)
   - Steering Wheel Key Learning (`com.ts.main.CStudy.*`)

---

## 2. Master Secret Engineering Codes & Triggers

Extracted directly from `com.ts.main.common.MainSet.DealFactorySec()` and `res/values/strings.xml`:

| Dial Code | Internal Code Constant | Triggered Target / Activity Class | Functional Purpose |
| :--- | :--- | :--- | :--- |
| **`8878`** | `custom_fatctory_num` | `com.ts.factoryset.FsMainActivity` (`factory=true`) | **Full Unrestricted Factory Settings Menu** |
| **`8888`** | `custom_shop_num` | `WinShow.GotoWin(15, 0)` | Quick Installer / Shop Menu |
| **`7224`** | Hardcoded | `com.ts.factoryset.FsMainActivity` (`factory=true`) | Alternative direct factory menu entry |
| **`3368`** | Hardcoded | `com.ts.factoryset.FsMainActivity` | TengShi / Topway engineering access password |
| **`1617`** | `custom_usbwait_id_num` | `com.ts.main.auth.FactoryMainActivity` | **Switches USB port to ADB Device Mode** |
| **`4848`** | `custom_open_system_setting_num`| `com.android.settings` | Direct shortcut to Stock Android Settings |
| **`4949`** | `custom_open_filemange` | `com.ts.filemanager` | Direct shortcut to Stock File Manager |
| **`0129`** | `custom_can_data_num` | `startCanDataService()` | **Real-time CAN Bus Raw Frame Sniffer / Monitor** |
| **`0127`** | `custom_can_keystudy_num`| `com.ts.can.CanCarInfoSub3Activity` | Digital CAN bus steering wheel button mapper |
| **`0128`** | `custom_can_update_num` | `com.ts.can.CanAllUpdateActivity` | CAN Bus decoder box firmware flashing tool |
| **`1414`** | `custom_reboot_id_num` | `PowerManager.reboot()` | Immediate soft reboot of headunit |
| **`1313`** | `custom_radio_reset_num`| `FtSet.ResetRadio()` | Hardware reset of AM/FM silicon tuner chip |
| **`123`** | `custom_check_dsp_secret`| `Iop.GetDspVer()` | Displays hardware DSP chip firmware version |
| **`1101`** | `custom_screenshot_num` | Screen mode toggle | Toggles system screenshot capture mode |
| **`1102`** | `custom_touchtest_num` | `com.ts.touchcheck` | Multi-touch coordinate accuracy & calibration test |
| **`1103`** | `custom_screen_adjust_num`| `com.ts.screentest.MainActivity` | LCD / LVDS panel display timing calibration |
| **`6666`** | `custom_fatctory_exprort_num`| `com.ts.factoryset.FsMPModeActivity` | Export / Import factory configuration to USB storage |
| **`2648`** | `custom_systemclear_pwd`| `MainSet.SystemClear()` | Master password to initiate full factory data wipe |
| **`9090`** / **`9191`** | `custom_destroy_id_*` | Activation certificate revoke | Revokes vendor hardware activation certificates |
| **`1314214`** | Multi-tap touch sequence | `SettingEquipmentActivity` -> `FsMainActivity` | Hidden multi-tap Easter egg on "About" screen |

---

## 3. Key Hardware Control Screens & APIs

All vehicle settings write directly to MCU non-volatile registers or NVRAM partitions via static JNI bindings in `com.yyw.ts70xhw.FtSet`:

### A. Reversing Camera & Parking Guidelines (`com.ts.factoryset.FsBackCarSetActivity`)
- **Video Input Format (`FtSet.SetCamSUBfmt`):**
  - `1`: CVBS NTSC (Standard Definition)
  - `2`: CVBS PAL
  - `3`: AHD 720P @ 25fps
  - `4`: AHD 720P @ 30fps
  - `5`: AHD 1080P @ 25fps (High Definition)
  - `6`: AHD 1080P @ 30fps
  - `7`: TVI 720P / 1080P
- **Parking Guidelines (`FtSet.SetLineType`, `FtSet.SetLinePos`):** Static guides, dynamic trajectory curves (steered via CAN steering angle sensor), or disabled.
- **Reverse Audio Mute (`FtSet.SetParkMuteDef`):** `0` = No attenuation, `1` = -10dB attenuation, `2` = Full audio mute when reverse gear is active.
- **Camera Mirroring (`FtSet.SetCamMir`, `FtSet.SetFcamMir`):** Horizontal flip for front and rear video feeds.

### B. Steering Wheel Controls – SWC (`com.ts.main.CStudy.CStudyMainActivity`)
- Calibrates analog resistive voltage ladders connected to KEY1 / KEY2 ISO wires.
- Maps up to 32 discrete key codes: `VOLUME_UP`, `VOLUME_DOWN`, `MUTE`, `NEXT`, `PREV`, `CALL_ANSWER`, `CALL_END`, `NAVI`, `MODE`, `HOME`, `VOICE_ASSIST`.

### C. CAN Bus Vehicle Protocol (`com.ts.factoryset.FsCanActivity`)
- CAN box manufacturer selection (Raise, Hiworld, SimpleSoft, Bagoo, OUDI, Xinpu, etc.).
- Vehicle brand, model, and year selection.
- Features toggles: Climatronic AC overlay, PDC parking radar overlay, door/trunk open visualizer.

### D. Digital Signal Processor – DSP (`com.ts.set.dsp.SetDspMainActivity`)
- 32-band parametric/graphic equalizer with independent Q-factor adjustments.
- Time Alignment / Emperor Delay (millisecond speaker delay compensation for driver-centric soundstage).
- Subwoofer LPF (Low-Pass Filter) and HPF (High-Pass Filter) cutoff slopes.
- Smart Bass Dynamic Boost.

### E. Active Cooling Fan Control (`com.ts.main.cpufan.ElectricFanActivity`)
- Threshold temperature adjustment: 60°C to 80°C (recommended: 60°C).
- Operational mode: Automatic thermal-trip control (`FtSet.SetFanEn`) or manual continuous operation.

---

## 4. Native AOSP Settings Integration Architecture

Rather than requiring users to search for hidden vendor APKs or dial secret codes like `8878`/`8888`, we integrate a dedicated **"Car Settings"** category directly into the Stock Android Settings app (`com.android.settings`).

### Implementation: `CarSettingsBridge`
Leverages the standard AOSP **Dynamic Dashboard Category** mechanism (`com.android.settings.category.ia.homepage`).

```
                    ┌──────────────────────────────────────────────┐
                    │          Stock AOSP Settings.apk             │
                    │         (Android System Settings)            │
                    └──────────────────────┬───────────────────────┘
                                           │ Dynamic Tile Injection
                                           ▼
             ┌───────────────────────────────────────────────────────────┐
             │            "Car Settings" Dashboard Tile                  │
             │           com.topway.carsettingsbridge                    │
             └─────────────────────────────┬─────────────────────────────┘
                                           │
         ┌───────────────────┬─────────────┴───────┬─────────────────────┐
         ▼                   ▼                     ▼                     ▼
┌─────────────────┐ ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Reversing Camera│ │ Steering Wheel  │  │ DSP Equalizer    │  │ CAN Bus Protocol │
│  & Guidelines   │ │  (SWC Learning) │  │  (32-Band Audio) │  │  & Car Model     │
│FsBackCarSetAct. │ │CStudyMainAct.   │  │SetDspMainActivity│  │  FsCanActivity   │
└─────────────────┘ └─────────────────┘  └──────────────────┘  └──────────────────┘
         │                   │                     │                     │
         └───────────────────┴─────────────┬───────┴─────────────────────┘
                                           ▼
                             ┌───────────────────────────┐
                             │        libts67xhw.so      │
                             │  Microcontroller (UART)   │
                             └───────────────────────────┘
```

### Tile Declaration (`AndroidManifest.xml`):
```xml
<activity
    android:name=".CarSettingsMainActivity"
    android:icon="@drawable/ic_car_settings"
    android:label="@string/car_settings_title"
    android:exported="true">
    <intent-filter>
        <action android:name="com.android.settings.action.SETTINGS_EXTENDED" />
        <category android:name="com.android.settings.category.ia.homepage" />
    </intent-filter>
    <meta-data
        android:name="com.android.settings.category"
        android:value="com.android.settings.category.ia.homepage" />
    <meta-data
        android:name="com.android.settings.title"
        android:value="@string/car_settings_title" />
    <meta-data
        android:name="com.android.settings.summary"
        android:value="@string/car_settings_summary" />
    <meta-data
        android:name="com.android.settings.icon"
        android:resource="@drawable/ic_car_settings" />
    <meta-data
        android:name="com.android.settings.order"
        android:value="-50" />
</activity>
```

When opened, the user sees structured preferences that launch directly into:
1. **Camera & Parking** -> Directly invokes `com.ts.factoryset.FsBackCarSetActivity`.
2. **Steering Wheel Controls** -> Directly invokes `com.ts.main.CStudy.CStudyMainActivity`.
3. **CAN Bus & Vehicle** -> Directly invokes `com.ts.factoryset.FsCanActivity`.
4. **DSP & Equalizer** -> Directly invokes `com.ts.set.dsp.SetDspMainActivity`.
5. **RGB Touch Key Lighting** -> Directly invokes `com.ts.set.SetColorKeyMainActivity`.
6. **Active CPU Cooling Fan** -> Directly invokes `com.ts.main.cpufan.ElectricFanActivity`.
7. **Factory Engineering Menu** -> Directly invokes `com.ts.factoryset.FsMainActivity` with `factory=true` (bypasses PIN dialog completely!).

---

## 5. App Retention & De-bloat Strategy

| Component / Package | File Path | Decision | Technical Justification |
| :--- | :--- | :--- | :--- |
| **DUDU-OS Launcher** | `com.autonavi.dudu` | **ADD (Default)** | High-performance, modern automotive UI in landscape 1280×720 with widget and split-screen map support. |
| **Dashcam / Car DVR** | `com.ankai.cardvr` (`CarDVR.apk`) | **RETAIN** | Front collision USB/MIPI video recording stack. |
| **Tire Pressure (TPMS)** | `com.ts.main.tpms` / `MainUI.apk` | **RETAIN** | Reads real-time tire pressure and temperature from USB sensors and CAN bus. |
| **USB DVD-ROM Player** | `DvdBox.apk` (`/vendor/app/DvdBox/`) | **RETAIN** | Support for external USB optical drives. |
| **Google Mobile Services** | GMS Core, Chrome, Maps, YouTube | **DEBLOAT / OPTION** | Replaced with **MicroG** (~30MB RAM overhead vs ~600MB stock GMS) or optional **NikGapps Core** via TWRP. |
| **Stock CarPlay / Android Auto** | `sd_carplay`, `CarLetter`, `EasyConnect` | **REMOVE** | Outdated Chinese phone link services causing resource contention. Prepared for clean **DiPlay** / AutoKit deployment. |
| **Stock OEM Launchers** | `8259TsLauncher2_*` (`/vendor/tsoem/`) | **REMOVE** | Cluttered 3D themes replaced completely by DUDU-OS. |
| **Chinese Telemetry & Daemons** | `txz`, `cpe_agent`, `cservice`, `ximalaya` | **REMOVE** | Privacy violations, unnecessary background battery and CPU consumption. |
| **MainUI (Headless Daemon)** | `MainUI.apk` | **RETAIN / STRIP** | Media player UIs stripped; MCU UART, CAN bus stack, and settings activities preserved. |
