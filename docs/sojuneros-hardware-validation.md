# SojunerOS 20.0 — Automotive Hardware Validation Procedures

**Target Platform:** Junsun V1 Plus / JunCan UI03 (Topway TS-8667-02)  
**Verification Scope:** Automotive Subsystems, Peripherals, and Vehicle Integration  

---

## 1. Subsystem Test Matrix

| Subsystem | Underlying Chip / Interface | Validation Procedure | Pass Criteria |
| :--- | :--- | :--- | :--- |
| **Audio DSP** | ROHM BD3702FV via `/dev/ts07_dsp` (I2C) | Play test sweep 20Hz–20kHz; adjust 32 EQ sliders in DSP app | Audible frequency attenuation / boost; no clipping or digital distortion |
| **Steering Wheel (SWC)** | ADC Resistor Ladder (KEY1/KEY2) + CAN | Enter SWC Learn mode; press Vol+, Vol-, Mute, Mode on steering wheel | All key codes registered and mapped to Android KeyEvents |
| **CAN Bus Decoders** | Topway `libcan59.so` over MCU UART (`/dev/ttyMT1` @ 115200) | Select vehicle model in `CarSettingsBridge`; open doors, change A/C temp | Real-time door ajar overlay appears; HVAC temperature displays correctly |
| **Reverse & 360° AVM** | Techpoint TP2850 AHD Decoder via MIPI-CSI | Apply +12V trigger to `REVERSE` wire on main harness | Video feed switches to camera stream in < 1.0 second; guidelines render |
| **Active Cooling Fan** | MCU GPIO Relay via UART command `0xF5 0x01` | Run CPU stress benchmark (`stress-ng` or 4K playback) to exceed 65°C | Cooling fan spins up at 65°C; powers off below 55°C |
| **Front Dashcam (DVR)** | Ankai USB Video Class (UVC) | Connect Ankai USB DVR to USB Port 2 (6-pin); open `com.ankai.cardvr` | 1080p live preview visible; loop recording files saved to SD card |
| **Tire Pressure (TPMS)** | 433MHz RF USB Receiver | Connect USB TPMS dongle; monitor `com.ts.main.tpms` | Pressure (bar/psi) and temperature (°C) reported for all 4 wheels |
| **Optical Drive (DVD)** | USB External DVD Box | Insert Audio CD or DVD-Video into external Topway USB drive | Disc mounts as optical media; audio and video playback initiates |
| **AM/FM Tuner** | NXP TEF6686 / Silicon Labs Si4792 | Launch Radio app; tune local FM station; toggle AF/TA RDS flags | Audio output clean; RDS PS (Station Name) displays on screen |
| **Cellular 4G LTE** | MediaTek MT6768 Internal Modem + SIM Tray | Insert active 4G LTE SIM card with data plan | Signal bars appear; 4G VoLTE/data connection established |

---

## 2. In-Depth Test Procedures

### Test Case 1: Audio DSP (ROHM BD3702FV) & Sound Routing
1. Boot SojunerOS and connect speakers to Front-Left, Front-Right, Rear-Left, Rear-Right, and Subwoofer outputs.
2. Launch the Car Audio Settings from `CarSettingsBridge` or DUDU-OS.
3. Test Fader / Balance:
   - Pan sound fully Front-Left -> Rear and Right speakers must fall completely silent.
   - Pan sound fully Subwoofer -> Low-pass filter (LPF) cuts off frequencies above 120Hz.
4. Test 32-Band Equalizer:
   - Adjust 1kHz band by +10dB -> Verify vocal frequency prominence.
   - Set Soundfield delay -> Verify speaker time-alignment changes stage depth.

### Test Case 2: Steering Wheel Controls (SWC)
1. Open `CarSettingsBridge` > **Steering Wheel Keys**.
2. Tap "Start Learning".
3. Press and hold "Volume Up" on the steering wheel:
   - Verify ADC voltage reading changes on screen.
   - Assign to Android `KEYCODE_VOLUME_UP`.
4. Press and hold "Mode":
   - Assign to `KEYCODE_MEDIA_NEXT` or App Switcher.
5. Tap "Save & Exit".
6. In any third-party media player (Spotify, YouTube), verify physical wheel buttons control playback seamlessly.

### Test Case 3: Reversing Camera Trigger & TP2850
1. Connect an AHD 720p or 1080p camera to the yellow RCA `CAM IN` connector.
2. Connect the reverse trigger line (`BACK` / `REVERSE`) to +12V.
3. **Verification Points:**
   - Display must immediately preempt the current foreground app within 800ms.
   - Video signal must display without tearing, rolling, or black-screen delay.
   - Trajectory guidelines must superimpose dynamically if CAN steering angle sensor is active.
4. Remove +12V trigger -> Display must restore the previous application instantaneously.

### Test Case 4: CPU Thermal Regulation & Fan Controller
1. Connect an active 5V/12V fan to the 2-pin fan header on the rear heatsink.
2. Monitor SoC thermal zones via ADB:
   ```bash
   cat /sys/class/thermal/thermal_zone*/temp
   ```
3. Generate synthetic CPU load:
   ```bash
   while true; do true; done &
   ```
4. Observe thermal threshold:
   - At 65°C: The kernel or MCU service issues command `0xF5 0x01` over serial.
   - The fan turns on.
   - Kill background stress process.
   - When temperature drops below 55°C, the fan switches off (`0xF5 0x00`).
