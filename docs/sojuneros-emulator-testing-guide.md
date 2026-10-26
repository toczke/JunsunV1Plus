# SojunerOS 20.0 — Virtual Hardware Emulator & Testing Guide

This document describes how to execute, test, and debug **SojunerOS 20.0 (LineageOS 20 / Android 13)** in a virtual machine environment using QEMU ARM64 with full hardware and MCU protocol emulation.

---

## 1. Emulator Architecture

The SojunerOS emulator mimics the hardware environment of the **Junsun V1 Plus / Topway TS-8667-02**:

| Subsystem | Target Hardware | Emulator Implementation |
| :--- | :--- | :--- |
| **SoC / CPU** | MediaTek MT8667 (2× A75 + 6× A55) | QEMU ARM64 `virt` with `-smp 8` (`cortex-a72`) |
| **RAM** | 4GB LPDDR4X | QEMU `-m 4G` memory allocation |
| **Display** | 1280×720 Fixed Landscape Panel | `virtio-gpu-pci` (xres=1280, yres=720) |
| **Touch Screen** | Goodix GT9886 / GT1151 capacitive | `virtio-tablet-pci` (absolute coordinate touch) |
| **Audio Subsystem** | MT6358 + BD3702FV DSP | Intel HDA duplex + Topway DSP command bridge |
| **MCU Communication** | Topway MCU UART on `/dev/ttyMT1` | Virtual PTY pair (`/tmp/mcu_uart`) via `mock_topway_mcu.py` |
| **Network & Debug** | Wi-Fi / LTE Modem | VirtIO Net with ADB port forwarding (`localhost:5555`) |

---

## 2. Quick Start

### Step 1: Build the Linux 4.14 Kernel & Boot.img
Run the automated build script:
```bash
./tools/build_kernel.sh
```
This builds:
- `out/kernel/Image` (Uncompressed ARM64 kernel)
- `out/kernel/Image.lz4` (Compressed for Android boot image)
- `out/kernel/boot.img` (Android Header v2 image with AVB signing)

### Step 2: Start the Topway MCU Hardware Simulator
In a separate terminal or background tab:
```bash
python3 tools/emulator/mock_topway_mcu.py
```
This launches an interactive CLI shell and creates a PTY symlinked at `/tmp/mcu_uart`.

### Step 3: Launch QEMU
In another terminal, launch the emulator:
```bash
./tools/emulator/run_qemu.sh
```
For headless server environments (e.g., CI/CD or SSH):
```bash
./tools/emulator/run_qemu.sh --headless
# Connect VNC client to localhost:5900
```

---

## 3. Interactive Vehicle Hardware Testing

The `mock_topway_mcu.py` CLI allows real-time triggering of automotive hardware events to test SojunerOS services (`MainService`, `BackcarService`, `libts67xhw.so`):

### 3.1 Reverse Camera Trigger (`TP2850`)
Simulates engaging and disengaging reverse gear:
```text
topway-mcu> reverse on
[MCU] REVERSE GEAR ENGAGED (Camera Active)

topway-mcu> reverse off
[MCU] REVERSE GEAR DISENGAGED
```
**Expected Android Behavior:** Android switches immediately to `BackcarService` full-screen camera overlay, then returns to the launcher when turned off.

### 3.2 Ignition / ACC Power Management
Simulates car key ignition states (Sleep / Deep Sleep vs Wake):
```text
topway-mcu> acc off
[MCU] ACC POWER OFF (Vehicle Sleep)

topway-mcu> acc on
[MCU] ACC POWER ON (Ignition Wake)
```

### 3.3 Steering Wheel Controls (SWC)
Dispatches calibrated key events to Android framework:
```text
topway-mcu> vol+
[MCU] SWC Event: VOL_UP (DOWN)
[MCU] SWC Event: VOL_UP (UP)

topway-mcu> vol-
topway-mcu> mute
topway-mcu> next
topway-mcu> prev
topway-mcu> play
```

### 3.4 CAN Bus Vehicle Telemetry
Simulates doors opening and closing:
```text
topway-mcu> door fl open
[MCU] CAN Bus Door Update: FL is OPEN

topway-mcu> door trunk open
[MCU] CAN Bus Door Update: TRUNK is OPEN
```

### 3.5 Audio DSP Validation
When Android audio HAL or settings change the equalizer or volume, `mock_topway_mcu.py` intercepts the BD3702FV command packet:
```text
[MCU <- Android] DSP Volume set to: 24
[MCU <- Android] DSP EQ updated: [3, 2, 0, 0, -1, -2, 0, 1, 3, 4]
```

---

## 4. ADB Debugging & Inspection

Once the VM boots, connect to the guest via ADB:
```bash
adb connect localhost:5555
adb devices
adb shell
```

Inspect the MCU serial communication:
```bash
adb shell "logcat -s TopwayMCU MainService BackcarService"
```
