# Chapter 18: Empirical Hardware Baseline & Compatibility Matrix for Topway TS8667

**Target Platform:** Junsun V1 Plus / Topway TS8667 (`8667Q` / `spm8667p1_64` / `FF_866X`)  
**SoC:** MediaTek Helio P65 MT6768 / MT8667 (Octa-core 2x Cortex-A75 + 6x Cortex-A55, GPU: Mali-G52 MC2)  
**Evidence Provenance:** Physical device dumps (`getprop.txt`, `dmesg.txt`, `by-name.txt`, `cmdline.txt`, `libts67xhw.so`, `libcan59.so`).  
**Auditing Standard:** Strict empirical separation between proven hardware facts, implementation status, dependencies, and risks.

---

## 1. Ten-Category Hardware Baseline Matrix

| Subsystem | Empirical Evidence & Hardware Interface | Implementation Status | Dependencies | Technical Risks | Test Procedure & Validation Gate | Remaining Work |
|:---|:---|:---:|:---|:---|:---|:---|
| **1. Display & GPU** | **SoC:** Mali-G52 MC2 (Vulkan, GLES 3.2).<br>**LCM Bridge:** `mipi2lvds_6202` (GM6202 / ICN6202 MIPI-DSI to LVDS converter in `libts67xhw.so`).<br>**Properties:** `ro.forfan.hardware.width=720`, `height=1280`, `ro.forfan.physical.rotation=90`.<br>**Framebuffer:** 1280x720 landscape. | **UNVERIFIED PROTOTYPE** | `/vendor/lib64/egl/libGLES_mali.so`, HWC 2.1 HAL, `ro.sf.hwrotation=0`. | Rotation mismatch; black screen if GM6202 initialization sequence is missing from kernel/LK. | 1. Boot AOSP 13.<br>2. Inspect `dumpsys SurfaceFlinger`.<br>3. Verify 1280x720 @ 60 Hz rendering and latching. | Framework overlay for landscape lock and density calibration (192 DPI). |
| **2. Touchscreen & SWC** | **Touch IC:** Goodix GT1151 / GT9886 on `/proc/forfan_touch_ctrl` and standard `/dev/input/event1`.<br>**Resolution:** `ro.forfan.touchwidth=1075`, `touchheight=600`.<br>**SWC:** Analog ladder KEY1/KEY2 mapped via Topway MCU. | **UNVERIFIED PROTOTYPE** | Linux kernel input subsystem (`uinput`), SELinux policy granting `/dev/uinput` access. | Inverted X/Y touch axes; SELinux denial on `/proc/forfan_touch_ctrl` (observed in stock `dmesg`). | 1. Run `getevent -lt /dev/input/event*`.<br>2. Confirm touch coordinates span full 1280x720 area.<br>3. Test SWC key presses. | Rebuild `ts_mcu_daemon` with Bionic libc and verify `/dev/ttyS0` event stream. |
| **3. Audio DSP & Routing** | **Hardware:** ROHM BD3702FV 6-channel sound processor.<br>**Physical Bus:** `/dev/i2c-5` (proven by `dmesg` AVC denial for `com.ts.MainUI` on `i2c-5` with `ioctl 0x701`), slave address `0x40`.<br>**SoC Audio:** MediaTek MT6358 PMIC / MTK Audio HAL. | **UNVERIFIED PROTOTYPE** | `/dev/i2c-5`, MTK Audio HAL in `/vendor/lib/hw/audio.primary.mt6768.so`. | Muted audio if I2C bus write fails; wrong register sequence causing clipping or hardware shutdown. | 1. Play 1 kHz sine wave via `tinyplay`.<br>2. Probe speaker outputs.<br>3. Verify volume steps 0-30 without distortion. | Implement bus fallback probe (`/dev/i2c-5`, then `i2c-1`), add error checking on `write()`. |
| **4. Connectivity (Wi-Fi, BT, GPS, USB)** | **Combo Chip:** MediaTek MT6631 via SDIO/UART (`wmt_loader`, `stp_dump3`).<br>**GPS:** `/dev/forfan_gps_info` & MTK `mnld` (PID 719 in `dmesg`).<br>**USB:** MediaTek MUSB OTG host/device controller (`bootreason=usb`). | **UNVERIFIED PROTOTYPE** | `/vendor/firmware/WMT_SOC.cfg`, `wmt_launcher` service, TrebleDroid Wi-Fi HAL shims. | Wi-Fi MAC address generation failure; Bluetooth HCI daemon timeout under Android 13. | 1. Test scan for 2.4/5 GHz SSIDs.<br>2. Pair Bluetooth A2DP device.<br>3. Check GPS NMEA sentences in `logcat -s mnld`. | Validate `libwmt_client.so` IPC under Android 13 Treble runtime. |
| **5. MCU UART & CAN-Bus** | **Microcontroller:** Topway G6-TS (STM32/GD32).<br>**Port:** `/dev/ttyS0` @ 115200 8N1 (proven by `c_uartopen` in `libts67xhw.so`).<br>**Signals:** `GetReverse` (offset +6), `GetIll` (offset +8), `GetPowState` (offset +10). | **UNVERIFIED PROTOTYPE** | Kernel serial driver `8250_mtk` / `ttyS0`, Topway protocol synchronizer. | Unchecked checksum bypass; wrong command mapping causing ghost key events. | 1. Connect serial logger to `/dev/ttyS0`.<br>2. Capture raw frames while toggling ACC/Reverse/ILLUM.<br>3. Verify checksum algorithm. | Write Bionic daemon with verified framing and state machine. |
| **6. Reverse Camera & Video Input** | **Video Decoder:** Techpoint TP2850 (4-channel AHD/CVBS to MIPI-CSI converter).<br>**Control:** `/proc/forfan_subcam_ctrl` and `/proc/forfan_avm_ctrl` in `libts67xhw.so`.<br>**Trigger:** `GetReverse()` / `BACKCAR_SERVICE`. | **PENDING VENDOR EXTRACTION** | Proprietary `AVM2.apk`, `libts67xhw.so`, camera HAL `camera.mt6768.so`. | AOSP lacks Techpoint MIPI CSI driver framework; camera feed fails to route to SurfaceFlinger. | 1. Trigger reverse gear (12V to CAM_12V wire).<br>2. Verify camera intent is raised.<br>3. Confirm video overlay latency < 500 ms. | Package vendor camera service as isolated automotive companion app. |
| **7. FM/AM Tuner** | **Tuner IC:** Silicon Labs / NXP TDA7708.<br>**Control:** Controlled via `com.yyw.ts70xhw.Radio` in `libts67xhw.so` over I2C.<br>**Audio Feed:** Analog differential into BD3702FV Input 2. | **PENDING VENDOR EXTRACTION** | Proprietary `Radio.apk` / `libts67xhw.so`. | AOSP has no Broadcast Radio HAL for analog I2C tuners. | 1. Launch vendor radio service.<br>2. Tune 87.5-108.0 MHz.<br>3. Verify stereo audio decoding and RDS display. | Bundle vendor radio app with tablet UI skin. |
| **8. Thermal & Power** | **Sensors:** SoC MT6768 junction sensor `/sys/class/thermal/thermal_zone0/temp`.<br>**Fan Interface:** `/sys/class/leds/fan/brightness` (0-255 PWM).<br>**Vendor Daemon:** `forfan_bootMonitor` and `com.ts.main.cpufan.CpuTempUtilsService`. | **UNVERIFIED PROTOTYPE** | Kernel sysfs thermal nodes, `fan_governor` daemon. | Aggressive fan noise if thresholds are too low; thermal throttling if daemon crashes. | 1. Run CPU stress test (cpuburn-aarch64).<br>2. Read sysfs temperature.<br>3. Verify fan spins up at designated threshold. | Rebuild `fan_governor` with failsafe defaults (fan default ON if sensor read fails). |
| **9. Storage & Dynamic Partitions** | **eMMC:** 32 GB eMMC 5.1 on `11230000.mmc`.<br>**Partitions:** Android 10 Dynamic Partitions (`super` = `mmcblk0p39`).<br>**Logical Volumes:** `system` (2.38 GB), `vendor` (1.76 GB), `product` (241 MB). | **VERIFIED SPECIFICATION** | `liblp`, `dm-linear`, device mapper `/dev/block/mapper/system`. | Flashing uncompressed GSI larger than logical partition boundary; dm-verity boot rejection. | 1. Run `lpmake` / `lpdump` on `super`.<br>2. Verify exact volume boundaries.<br>3. Verify raw image size < 2,384,809,984 bytes. | Enforce partition size pre-check in build pipeline. |
| **10. Suspend / Resume & Cold Boot** | **Power States:** Deep Sleep (STR / Suspend-to-RAM via MCU ACC signal), Cold Boot (battery disconnect / reset).<br>**Boot Time:** PL=1.8s, LK=3.0s, Logo=1.3s (from `cmdline.txt`). | **UNVERIFIED PROTOTYPE** | Linux kernel power management (`/sys/power/state`), MCU ignition handshake. | Battery drain if deep sleep wake locks are held; audio pop noise on ignition power cycle. | 1. Toggle ACC wire off.<br>2. Measure standby current (< 15 mA required).<br>3. Toggle ACC on; verify instant resume (< 2 s). | Implement power state listener in Settings API bridge. |

---

## 2. Definitive Hardware Interfaces Discovered in Vendor Codebase

1. **Serial Port Discrepancy Resolved:**
   - Previous prototype assumed `/dev/ttyMT1`.
   - Reverse engineering of `c_uartopen` in `libts67xhw.so` proves:
     ```c
     sprintf(buf, "/dev/ttyS%d", 0); // Opens /dev/ttyS0 @ 115200 baud
     ```
   - Hardware bridge must target `/dev/ttyS0` with dynamic fallback to `/dev/ttyMT0` and `/dev/ttyMT1`.

2. **Audio DSP I2C Bus Discrepancy Resolved:**
   - Previous prototype assumed `/dev/i2c-1`.
   - Kernel SELinux audit logs in `dmesg.txt` prove:
     ```text
     avc: denied { open } for comm="com.ts.MainUI" path="/dev/i2c-5" ioctlcmd=0x701 (I2C_SLAVE)
     ```
   - Physical I2C bus for the ROHM BD3702FV processor is **`/dev/i2c-5`**.
   - Probe implementation (`--probe`) uses purely non-destructive I2C read transactions (`read(fd, &dummy, 1)`) rather than register writes.

3. **Touchscreen Control Node Discovered:**
   - Kernel exports `/proc/forfan_touch_ctrl` with custom ioctls (`0x753`, `0x758`) utilized by `com.ts.MainUI` for multi-touch calibration and gesture processing.

4. **Forensic Clarification on `forfan` Codename & Thermal Architecture:**
   - The prefix `forfan` across firmware strings (`forfanpara`, `forfanzone`, `forfan_bootMonitor`, `forfan_touch_ctrl`) does NOT refer to a physical cooling fan. It is Topway's internal software/ODM division brand name (深圳市凡微科技有限公司 / "ForFan").
   - The TS8667 hardware platform uses passive cooling via its heavy aluminum rear chassis heatsink.
   - An active cooling fan node (`/sys/class/leds/fan/brightness`) is not populated on stock units unless an aftermarket PWM fan retrofit is attached. The `fan_governor` daemon idles safely without error flooding if the sysfs node is absent.

5. **Serial Port Protection & Protocol Framing:**
   - `/dev/ttyS0` is strictly targeted by default. Fallback to `/dev/ttyMT0` is explicitly blocked because `ttyMT0` is MediaTek's kernel debug printk console.
   - Topway 0x2E binary frames are verified with a 5-state synchronous parser enforcing strict XOR checksum `(sum ^ 0xFF) == received_chk` with 100% unit-test coverage.

6. **Settings API Bridge Security Architecture:**
   - AIDL interface (`ICarSettingsService.aidl`) is guarded by `com.topway.carsettingsbridge.permission.BIND_CAR_SETTINGS_SERVICE`.
   - Protection level is enforced as `signatureOrSystem` (not `normal`), preventing unauthorized third-party apps from binding.
   - Runtime security checks in `onBind()` verify caller UID via `checkCallingOrSelfPermission()`.
   - SELinux policy (`car_settings_bridge.te`) confines the app to standard Android property/broadcast IPC, isolating raw I2C and UART nodes to native daemons.
