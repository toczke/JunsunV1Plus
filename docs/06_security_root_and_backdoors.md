# Chapter 6: Security Audits, Root Access & Backdoors

Analysis of the security posture, pre-installed root binaries, ADB elevation methods, and factory menu passwords on the Junsun V1 Plus / TS8667.

---

## 1. Pre-installed Root Binaries

Unlike smartphones which ship locked with dm-verity enforced, this headunit runs a **`userdebug`** build (`ro.build.type=userdebug`) with test-keys and pre-installed root utilities:

### 1.1 ForFan SU (`/system/xbin/ffsu`)
- **Path:** `/system/xbin/ffsu`
- **File Type:** 64-bit ELF ARMv8 shared object / binary.
- **Function:** Custom setuid-root binary developed by ForFan / Topway.
- **Usage:**
  ```bash
  adb shell
  ffsu
  # You are now root: uid=0(root) gid=0(root)
  ```

### 1.2 Root Remount Tool (`/system/bin/rootremount`)
- **Path:** `/system/bin/rootremount`
- **Content:**
  ```bash
  # Script to start "am" on the device, which has a very rudimentary shell.
  remount
  setprop service.adb.root 1
  ```
- **Function:** Remounts `/system`, `/vendor`, and `/product` as read-write (`rw`), and forces the ADB daemon (`adbd`) to restart with root privileges.

---

## 2. ADB Access Over Wi-Fi & USB

- **USB Configuration:**
  - `persist.sys.usb.config=adb` is hardcoded in `/default.prop`.
  - Plugging a male-to-male USB-A cable into the 4-pin or 6-pin USB port on the back of the headunit exposes ADB directly to a connected PC.
- **Wireless ADB:**
  - Because ADB is enabled, wireless debugging can be activated from a terminal or terminal emulator app:
    ```bash
    setprop service.adb.tcp.port 5555
    stop adbd
    start adbd
    ```
  - Connect from your laptop over the vehicle's Wi-Fi hotspot:
    ```bash
    adb connect 192.168.43.1:5555
    adb root
    adb shell
    ```

---

## 3. Factory Settings PIN Codes & Passwords

Topway headunits feature hidden menus under **Car Settings > Factory Settings** (`com.ts.factoryset.FsMainActivity`) used to configure the CAN box model, radio region, boot logo, touch calibration, and audio gain.

The following master passwords were extracted from `classes.dex` of `MainUI.apk`:

| PIN Code | Menu / Function |
|---|---|
| **`8888`** | **Master Factory Settings Menu** (CAN box selection, screen resolution, mic gain, logo switcher) |
| **`3368`** | Alternative Topway / TengShi Factory Settings |
| **`1617`** | Advanced Hardware & Audio Gain Settings |
| **`123456`** | Protocol & MCU Update Menu |
| **`8878`** | Touch Screen Key Coordinate Calibration |
| **`*#*#3646633#*#*`** | **MediaTek Engineer Mode** (Dialer code to access baseband, sensor ADC, and GPS testing) |

---

## 4. SELinux & Verity Posture

- **SELinux:** Set to `Enforcing` in user space, but because the kernel is a `userdebug` kernel, it can be set to permissive on-the-fly:
  ```bash
  adb shell ffsu
  setenforce 0
  ```
- **AVB (Android Verified Boot):** Configured with AVB 1.0 test-keys (`ro.oem_unlock_supported=1`).
- **Rescue Party:** Explicitly disabled in `/system/build.prop`:
  ```properties
  persist.sys.disable_rescue=true
  ```
  This prevents the system from triggering factory resets if a boot loop occurs during development.
