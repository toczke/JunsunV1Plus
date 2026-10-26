# Chapter 1: Hardware & Platform Architecture

Detailed low-level hardware breakdown extracted directly from firmware device tree blobs (`kernel.dts`), kernel binaries, and vendor HAL libraries.

---

## 1. System on Chip (SoC) & Processing Units

- **SoC Identity:** MediaTek MT8667 (Automotive variant of the MT6768 / Helio P65/G85 platform).
- **CPU Cluster Architecture:** Octa-core big.LITTLE 64-bit ARMv8.2-A:
  - **Performance Cluster:** 2× ARM Cortex-A75 cores clocked up to 2.0 GHz.
  - **Efficiency Cluster:** 6× ARM Cortex-A55 cores clocked up to 2.0 GHz.
  - Core configuration in Device Tree: `cpu0` - `cpu5` (Cortex-A55), `cpu6` - `cpu7` (Cortex-A75).
- **GPU:** ARM Mali-G52 MC2 (Bifrost architecture, 2 execution engines) supporting:
  - OpenGL ES 3.2 (Driver version `196610`)
  - Vulkan 1.1
  - OpenCL 2.0
- **Power Management IC (PMIC):** MediaTek **MT6358** managing dynamic voltage scaling (DVFS), power sequencing, battery/ignition line sensing, and audio DAC/ADC.
- **Hardware Co-Processors (TinySys):**
  - **SCP (`scp.img`):** ARM Cortex-M4 dedicated System Co-Processor running RTOS for sensor fusion, low-power audio, and power modes.
  - **SSPM (`sspm.img`):** Dedicated System Security Processor running cryptographic acceleration and secure boot verification.

---

## 2. Display Engine & Touch Controllers

### MIPI DSI Display Interface
The system includes built-in timing profiles and initialization sequences in `/system/tsoem/mipifile/` supporting multiple automotive screens:
- **720×1280 / 1280×720 (Standard 9" & 10.1" panels):**
  - Jadard `JD9365` (`KL-JD9365-9.bin`, `KL-JD9365-10.bin`)
  - Sitronix `ST7705` (`SAT-7705N-9.bin`, `SAT-7705N-10.bin`, `XHS-7705-10D.bin`)
  - Sitronix `ST9707` (`SAT-9707-C.bin`, `XHS-9707.bin`, `YT-9707-10.bin`)
  - Jadard `JD9366` (`YT-9366-9.bin`, `YT-9366-10.bin`)
- **1200×1920 (High-Resolution 10.1" and 12.95" In-Cell panels):**
  - `XHS_INCELL_10_1.bin`, `XHS_INCELL_12_95.bin`
- **1200×2000 (2K Panoramic panels 9.5", 10.36", 11.5"):**
  - `YT_TBD_10_36-1.bin`, `YT_TBD_11_5.bin`

### Capacitive Touch Digitizer
- Controllers: **Goodix GT1151** and **Goodix GT9886**.
- Communication: Dedicated I2C bus with interrupt line (`/dev/v4l-touch` / `/dev/input/event*`).
- Firmware blobs loaded on boot from `/vendor/firmware/gt1151_default_firmware*.img` and `/vendor/firmware/gt9886_*.bin`.

---

## 3. Audio & DSP Subsystem

- **Dedicated DSP Sound Processor:** **ROHM BD3702FV / BD37033**
  - I2C-controlled audio processor.
  - Multi-band parametric equalizer.
  - Independent Subwoofer crossover low-pass filter, phase switch (0°/180°), and gain.
  - 6-channel pre-out volume & fader attenuation.
  - Time-alignment sound field delay calculation ("Emperor" driver sweet spot).
- **Internal PMIC Codec:** MediaTek **MT6358** stereo DAC (SNR > 100 dB) and multi-channel ADC.
- **Audio Routing:**
  - 4 High-power speaker outputs (FL, FR, RL, RR).
  - Pre-amplified RCA outputs: Front L/R, Rear L/R, Subwoofer.
  - Dual microphone inputs: Internal front-panel mic + Rear 3.5mm external noise-canceling mic.
  - Dedicated analog I2S input from FM/AM tuner.

---

## 4. Connectivity & Radios

- **FM/AM Radio Tuner:** **MediaTek MT6631** FM receiver (`mt6631_fm_v1_patch.bin`) with worldwide frequency stepping and hardware RDS (Radio Data System) decoder.
- **Wi-Fi Subsystem:** Dual-band 802.11 a/b/g/n/ac (2.4 GHz + 5.0 GHz) running via WMT combo framework (`soc1_0_ram_wifi_1a_1_hdr.bin`).
- **Bluetooth Subsystem:** Bluetooth 5.0 Dual Mode (BLE + BR/EDR) with A2DP, AVRCP, HFP, PBAP profiles (`soc1_0_ram_bt_1a_1_hdr.bin`).
- **Cellular Subsystem:** Integrated 4G LTE Cat-7 (DL up to 300 Mbps) / Cat-13 (UL up to 150 Mbps) modem supporting dual SIM + external eSIM (`slot1`, `slot2`, `slot3`) with VoLTE and IMS HD voice calling.
- **GNSS / Satellite Navigation:** Multi-constellation GNSS supporting GPS (L1), GLONASS, Galileo, and Beidou.

---

## 5. Vision & 360° AVM Hardware

- **Dedicated Video Receiver Chip:** **Techpoint TP2850**
  - 4-channel High-Definition AHD (Analog High Definition) and HD-TVI video decoder.
  - Interfaced via `/vendor/lib64/tp2850_yuv_tuning.so` and `tp2850_yuv_IdxMgr.so`.
  - Captures 4 simultaneous 720p/1080p camera streams (Front, Rear, Left mirror, Right mirror) for real-time 360° bird-eye view panoramic stitching.
- **USB / MIPI Dashcam (DVR):** Dedicated MIPI CSI hardware interface for front recording dashcam (`MIPIDVRActivity`).

---

## 6. Hardware Debugging: UART Serial Console

The Device Tree reveals an active low-level serial console enabled in bootargs:
```text
console=tty0 console=ttyS0,921600n1 root=/dev/ram vmalloc=400M
```
- **Port:** `ttyS0` (MediaTek UART0 header on motherboard test pads).
- **Baud Rate:** **`921600`** baud.
- **Format:** 8 Data bits, No parity, 1 Stop bit (8N1), No flow control.
- **Functionality:** Provides full Little Kernel (LK) bootloader output, Linux kernel `dmesg`, and root shell access on boot.
