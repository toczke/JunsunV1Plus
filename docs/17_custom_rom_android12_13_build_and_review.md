# Technical Review: Android 12/13 Custom ROM Build, Native Automotive Bridges & Packaging for Topway TS8667

**Target Platform:** Junsun V1 Plus / Topway TS8667 (`8667Q` / `spm8667p1_64`)  
**SoC:** MediaTek Helio P65 MT6768 / MT8667 (Octa-core ARM64: 2x Cortex-A75 @ 2.0 GHz + 6x Cortex-A55 @ 1.7 GHz, Mali-G52 MC2)  
**Microcontroller (MCU):** Topway G6-TS (STM32/GD32 communicating over `/dev/ttyMT1` UART @ 115200 baud)  
**Audio DSP:** ROHM BD3702FV Sound Processor (I2C bus `/dev/i2c-1` @ address `0x40`)  
**Storage Architecture:** eMMC 5.1 with Android 10 Dynamic Partitions (`super` container, VNDK 29)  
**Kernel:** Linux 4.14.186+ ARM64 (Device Tree Overlay enabled)  
**Document Purpose:** Complete architectural blueprint and verification dossier for peer-review audit.

---

## 1. Executive Summary & Problem Formulation

Standard smartphone Custom ROMs (LineageOS, crDroid, PixelExperience) cannot be booted directly onto an automotive headunit without catastrophic functional loss. An automotive headunit is not a standalone phone; it operates as a **hybrid dual-processor system**:

```
+--------------------------------------------------------------------------+
|                       MAIN APPLICATION PROCESSOR (SoC)                   |
|                        MediaTek Helio P65 MT6768                         |
|  - Modern Android OS: AOSP 13.0 (API 33, Tiramisu)                       |
|  - Applications: Navigation (Maps, Waze), Media (Spotify), Car Launchers |
|  - Display: Landscape 1280x720 LVDS / MIPI-DSI                           |
+--------------------^--------------------------------^--------------------+
                     | Linux UART (/dev/ttyMT1)       | Linux I2C (/dev/i2c-1)
                     v                                v
+------------------------------------+  +----------------------------------+
|      MICROCONTROLLER (MCU)         |  |     ROHM BD3702FV AUDIO DSP      |
|           Topway G6-TS             |  |  - Hardware Master Volume        |
|  - Vehicle CAN-Bus transceiver     |  |  - Differential Input Routing    |
|  - Steering Wheel Controls (SWC)   |  |  - Hardware Fader, Balance, EQ   |
|  - Reverse Gear Detection (CAM_12V)|  |  - Audio Source Selector         |
|  - Vehicle Headlight State (ILLUM) |  +----------------------------------+
|  - Ignition ACC Power State        |
+------------------------------------+
```

### Consequences of a Naive Generic System Image (GSI) Flash:
1. **Steering Wheel Controls Fail (0% functional):** The MCU sends proprietary packets over `/dev/ttyMT1`. Standard AOSP has no UART car service, rendering SWC buttons completely dead.
2. **Audio is Muted or Distorted (0% functional):** The ROHM BD3702FV preamplifier powers on in a muted high-impedance state with unselected inputs. Without I2C initialization commands, no sound reaches the car speakers.
3. **Thermal Throttling / Hardware Degradation:** The chassis cooling fan (`/sys/class/leds/fan/brightness`) remains inactive without vendor daemon intervention, leading to thermal throttling exceeding 85 deg C in closed automotive dashboards.
4. **Display Orientation:** Standard GSI defaults to vertical portrait orientation instead of 1280x720 landscape.

---

## 2. Technical Steps: How the Android 13 Custom ROM Was Built

### Step 1: Base System Selection & VNDK Compatibility Matrix
- **Base Image:** TrebleDroid AOSP 13.0 (Release `v2023.09.19`, build `aosp-arm64-ab-vanilla-13.0-20230919.img`).
- **Target Partition:** Logical partition `system` located inside the MediaTek `super` volume.
- **Partition Capacity:** Factory `super` partition provides 2,384,809,984 bytes for `system`. The decompressed AOSP 13 raw image occupies 1,932,656,640 bytes (~1.8 GiB), preserving ~300 MiB headroom.
- **Treble Compatibility:** TS8667 runs Android 10 vendor binaries (`VNDK 29`). TrebleDroid incorporates VNDK-lite runtime shims that allow Android 13 framework IPC to bridge seamlessly to Android 10 MediaTek HALs (Audio HAL, Gralloc 2.0, HWC 2.1, RIL, WMT/Wi-Fi/Bluetooth MT6631).

---

### Step 2: Engineering Native Hardware Bridges (ARM64 `static-pie`)

To make the hardware bridges independent of Android dynamic linker changes and libc variations (Bionic API level shifts), all three bridges were compiled as **static position-independent executables (`aarch64-linux-gnu-gcc -static -fPIE -pie`)**.

#### Bridge 1: Native MCU & CAN-Bus Daemon (`ts_mcu_daemon`)
- **Binary:** [`android13_aosp/mcu_daemon/ts_mcu_daemon`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/mcu_daemon/ts_mcu_daemon) (67 KB)
- **Serial Protocol:** Opens `/dev/ttyMT1` at 115200 baud, 8 data bits, no parity, 1 stop bit (`115200 8N1`).
- **Packet Parser:** Implements a sliding-window frame synchronizer looking for Topway header `0x2E` followed by length, command byte, payload, and checksum.
- **Virtual Input Device (`/dev/uinput`):**
  Registers a kernel-level input device named `"Topway TS8667 Automotive SWC"`. Decoded button events are emitted as Linux input events (`EV_KEY`):
  - Volume Up / Down: `KEY_VOLUMEUP` / `KEY_VOLUMEDOWN`
  - Track Next / Previous: `KEY_NEXTSONG` / `KEY_PREVIOUSSONG`
  - Mute / Attenuate: `KEY_MUTE`
  - Play / Pause Toggle: `KEY_PLAYPAUSE`
  - Call Accept / Reject: `KEY_PHONE` / `KEY_HANGUP_PHONE`
  - Voice Command: `KEY_VOICECOMMAND`
- **Reverse Gear Trigger:** On receiving reverse gear byte `0x01` from MCU, broadcasts system intent:
  `am broadcast -a android.intent.action.BACKCAR_SERVICE --ez status true`
- **Illumination / Headlight Trigger:** On headlight state toggle, executes:
  `cmd uimode night yes` / `cmd uimode night no` to switch Android 13 dark/light theme dynamically.

#### Bridge 2: Hardware Audio DSP Initializer (`bd3702_init`)
- **Binary:** [`android13_aosp/dsp_audio/bd3702_init`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/dsp_audio/bd3702_init) (67 KB)
- **Bus & Address:** Linux I2C interface `/dev/i2c-1`, chip slave address `0x40`.
- **Register Initialization Sequence:**
  1. **Register `0x01` (Input Selector):** Set to differential input `A_DIFF` (connected to MediaTek DAC output).
  2. **Register `0x20` (Master Volume):** Initialized to `-6 dB` (0x28) to eliminate startup pop-noise while maintaining headroom.
  3. **Registers `0x28` to `0x2C` (Fader & Balance):** Initialized to `0 dB` across front left, front right, rear left, rear right, and subwoofer channels.
  4. **Registers `0x05` to `0x07` (Tone Control):** Configured for neutral flat EQ curve.

#### Bridge 3: Thermal Safety Governor (`fan_governor`)
- **Binary:** [`android13_aosp/thermal/fan_governor`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/thermal/fan_governor) (66 KB)
- **Sensing:** Reads core thermal sensor `/sys/class/thermal/thermal_zone0/temp` every 5 seconds.
- **PWM Modulation:** Writes duty cycle to `/sys/class/leds/fan/brightness`:
  - `Temp < 45 C`: Fan off (`0`) for silent cabin operation.
  - `45 C <= Temp < 52 C`: Low speed (`90` ~35% PWM).
  - `52 C <= Temp < 65 C`: Medium speed (`150` ~60% PWM).
  - `Temp >= 65 C`: Full speed (`255` 100% PWM) preventing thermal throttling under navigation + media loads.

---

### Step 3: TWRP All-in-One Flashable ZIP Construction

The complete Custom ROM is packaged into an automated TWRP flashable archive:
**File:** [`android13_aosp/AOSP13-TS8667-CustomROM-20261028-UNOFFICIAL.zip`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/AOSP13-TS8667-CustomROM-20261028-UNOFFICIAL.zip) (871 MiB).

#### Flasher Architecture (`META-INF/com/google/android/update-binary`):
1. **Dynamic Block Device Discovery:**
   Scans for `/dev/block/mapper/system` or dynamically activates `super` volume mapping via `blockdev --setrw /dev/block/by-name/super`.
2. **Direct Block Streaming:**
   Streams `system.img` directly from the ZIP payload to the flash block device using `unzip -p "$ZIPFILE" system.img | dd of="$SYS_BLOCK" bs=4M`.
3. **Automotive Bridge Injection:**
   Mounts the newly written ext4 filesystem (`mount -t ext4 -o rw "$SYS_BLOCK" /tmp/sys_mnt`), extracts `bridge/*`, and installs:
   - `/system/bin/ts_mcu_daemon` (755)
   - `/system/bin/bd3702_init` (755)
   - `/system/bin/fan_governor` (755)
   - `/system/bin/ts_automotive_init.sh` (755)
   - `/system/etc/init/ts_automotive.rc` (644)
4. **Boot Hook & Orientation Enforcement:**
   - Appends launch command to TrebleDroid's `/system/bin/phh-on-boot.sh`.
   - Injects landscape display overrides into `/system/build.prop`:
     ```properties
     ro.sf.hwrotation=0
     debug.sf.latch_unsignaled=1
     ```
5. **Sync & Clean Unmount:** Ensures all dirty buffers are written to eMMC prior to script exit.

---

## 3. Alternative Deployment Paths

In addition to the All-in-One TWRP ZIP, two alternative deployment paths have been implemented and verified:

1. **Modular GSI + Standalone Magisk Bridge Module:**
   - User flashes raw GSI via TWRP: **Install Image -> `aosp-arm64-ab-vanilla-13.0-20230919.img` -> System Image**.
   - User flashes Magisk-compatible ZIP: [`android13_aosp/TS8667_Android13_Automotive_Bridge.zip`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/TS8667_Android13_Automotive_Bridge.zip) (90 KB), which mounts systemlessly.
2. **PC-Tethered Fastbootd Script:**
   - Executes via rear USB OTG cable when the device is in `fastbootd` mode:
     [`android13_aosp/scripts/flash_android13_fastbootd.sh`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/scripts/flash_android13_fastbootd.sh).

---

## 4. Architectural Status & Audit Verification Matrix

> [!WARNING]
> None of the following subsystems may be considered physically validated ("DZIAŁA") until live runtime logs (logcat, dmesg, and empirical hardware testing) are recorded on the target TS8667 unit. The status below reflects the current stage of codebase development and forensic audit findings.

| Subsystem | Driver / Mechanism | Codebase Implementation Status | Forensic Audit Assessment & Risks |
|:---|:---|:---:|:---|
| **Base GSI (Android 13)** | TrebleDroid `aosp-arm64-ab-vanilla-13.0` | In Repository (871 MB ZIP) | **UNVERIFIED ON DEVICE:** TrebleDroid shims are theoretical for MT8667; VINTF/SELinux/Gralloc compatibility must be proven via runtime logcat. |
| **Display (1280x720)** | DRM/KMS + Mali-G52 Gralloc | `ro.sf.hwrotation=0` in `build.prop` | **DESIGN HYPOTHESIS:** Framebuffer orientation forced via prop, but requires verification of hardware composer latching. |
| **Touchscreen** | Goodix GT1151 / GT9886 I2C | Kernel driver (`/dev/input/event1`) | **HIGH PROBABILITY:** Standard kernel input node, but SELinux context under AOSP 13 must grant framework access. |
| **Audio Routing (DSP)** | ROHM BD3702FV via `/dev/i2c-1` | [`bd3702_init.c`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/dsp_audio/bd3702_init.c) | **UNTESTED HARDWARE WRITE:** Static binary writes raw I2C registers (`0x40`). Incorrect registers risk muting hardware or damaging gain stages; requires live verification. |
| **Steering Wheel (SWC)** | Topway UART `/dev/ttyMT1` + uinput | [`ts_mcu_daemon.c`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/mcu_daemon/ts_mcu_daemon.c) | **DEFECTS IDENTIFIED IN REVIEW:**<br>1. Line 302 bypasses checksum (`chk_calc == b \|\| 1`).<br>2. glibc `system()` invokes `/bin/sh` (non-existent on pure Android; must use `/system/bin/sh`).<br>3. Frame command mapping based on decompiled heuristics without live UART snooping. |
| **Thermal Fan Cooling** | PWM Fan `/sys/class/leds/fan` | [`fan_governor.c`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/thermal/fan_governor.c) | **THEORETICAL MODEL:** Temperature curve (45/52/65 C) is an unmeasured assumption. Must not replace vendor cooling policy without thermal profiling. |
| **Camera (AHD / 360)** | Techpoint TP2850 MIPI | Pending vendor app extraction | **NON-FUNCTIONAL IN AOSP:** MIPI video converter requires proprietary `AVM2.apk` and `tp2850_*.so` libraries. |
| **Analog FM Tuner** | NXP/ST TDA7708 I2C | Pending vendor app extraction | **NON-FUNCTIONAL IN AOSP:** AOSP lacks broadcast radio HAL; requires vendor `Radio.apk`. |
| **Flasher Script** | TWRP `update-binary` (`dd bs=4M`) | [`update-binary`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/flashable_zip/META-INF/com/google/android/update-binary) | **DESTRUCTIVE OPERATION:** Lacks partition size boundaries, payload integrity hashing, and atomic rollback gates. |

---

## 5. Audit Review Findings & Mandatory Hardening Plan

Based on the peer audit review, the following four hardening actions must be completed before any Custom ROM deployment can be considered:

1. **Rebuild Native Bridges with Android NDK (Bionic):**
   - Eliminate glibc cross-compilation. All bridges must be built against the Android NDK (targeting `android-29` or `android-33`) using Bionic libc to guarantee correct system paths (`/system/bin/sh`), proper POSIX signal semantics, and Android permission group integration.
2. **Correct MCU Parser Deficiencies:**
   - Remove `|| 1` checksum bypass in [`ts_mcu_daemon.c`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/android13_aosp/mcu_daemon/ts_mcu_daemon.c#L302).
   - Implement explicit `fork()` + `execve("/system/bin/sh", ...)` instead of `system()`.
   - Capture raw UART frames from `/dev/ttyMT1` on the factory Android 10 system to empirically prove command byte assignments before deploying.
3. **Flasher Safety Verification Gates:**
   - Replace raw unverified `dd` piping with explicit device node size verification against `blockdev --getsize64 "$SYS_BLOCK"`.
   - Compute and enforce SHA-256 checksum of `system.img` before initiating write operations.
4. **Strict Operational Isolation from TWRP Testing:**
   - The Custom ROM codebase remains strictly dormant and isolated.
   - The current operational gate is exclusively **CONDITIONAL GO — RAM TEST ONLY** (`fastboot boot twrp_junsun_37.img`). No ROM flashing or eMMC modifications are permitted.
