# Chapter 3: Operating System & Version Spoofing Analysis

Technical breakdown of the actual Android operating system version, the vendor's spoofing mechanisms, and Project Treble / GSI compatibility.

---

## 1. True Android OS Specifications

Extracted from `/system/build.prop`, `/vendor/build.prop`, and `/recovery.img`:

| Property | True Value | Description |
|---|---|---|
| **Android Version** | **10 (Q)** | `ro.build.version.release=10` |
| **API / SDK Level** | **29** | `ro.build.version.sdk=29` |
| **VNDK Version** | **29** | `ro.vndk.version=29` |
| **First API Level** | **29** | `ro.product.first_api_level=29` |
| **Build ID** | `QP1A.190711.020` | Official Android 10 QPR1 release tag |
| **Incremental Version** | `p5spm8666p164P2` | Topway vendor build incremental identifier |
| **Kernel Version** | **Linux 4.14.186+** | 64-bit ARMv8 (`aarch64`) |
| **Security Patch** | `2021-06-05` | Real security patch level |
| **Build Type** | **`userdebug`** | ADB enabled by default, debuggable, test-keys |
| **Root Method** | Native pre-installed | `/system/xbin/ffsu` and `/system/bin/rootremount` |

---

## 2. The Version Spoofing Trick ("Fake Android 13")

### Marketing vs. Reality
Junsun / Topway / JunCan headunit sellers advertise these units on AliExpress, Amazon, and eBay as **"Android 12"** or **"Android 13"**. When users install diagnostic tools like **AIDA64**, **CPU-Z**, or check **Settings > About Device**, the system proudly reports Android 13.

### How the Firmware Fakes Android 13
Inside `/system/build.prop`, the vendor injected targeted overrides that explicitly intercept diagnostic apps:

```properties
# scj add
ro.forfan.version.release=13
ro.ui.style_r=0
ro.forfan.aida64.version.sdk=33
ro.forfan.aida64.version.sdkstr=33
#for android 13
```

#### How it works under the hood:
1. **Settings App Hook:** Topway's custom `Settings.apk` does not read `ro.build.version.release`. Instead, it checks `ro.forfan.version.release`. Because that property is set to `13`, Settings displays "Android 13".
2. **AIDA64 / Diagnostic Hook:** The Android framework (`framework.jar`) was modified by Topway engineers to check calling package signatures. When `com.finalwire.aida64` requests the build SDK integer or release string, the framework returns `ro.forfan.aida64.version.sdk` (`33`, which is Android 13 Tiramisu).
3. **Legacy Fingerprint Spoof:** In `/vendor/build.prop`, there is also an ancient fingerprint string spoofed to Android 6.0 Marshmallow:
   ```properties
   ro.build.fingerprint=alps/full_evb3561sv_w_65_m0/evb3561sv_w_65_m0:6.0/MRA58K/1564481527:userdebug/test-keys
   ```
   This is legacy code leftover from older Topway board designs (`evb3561sv`).

---

## 3. Project Treble & GSI Compatibility

Because this unit runs real Android 10 with a separated vendor partition:
- **Project Treble Enabled:** `ro.treble.enabled=true`
- **Dynamic Partitions:** `ro.boot.dynamic_partitions=true`
- **System-as-Root:** Enabled

### Built-in GSI Public Keys
In `/boot.img/fstab.mt6768`, the system explicitly trusts Google's standard GSI public keys:
```text
avb_keys=/avb/q-gsi.avbpubkey:/avb/r-gsi.avbpubkey:/avb/s-gsi.avbpubkey
```
This means the bootloader allows booting:
- **Android 10 Q GSIs**
- **Android 11 R GSIs**
- **Android 12 S GSIs**

### The Trade-off of Flashing a Clean GSI
While a Generic System Image (like LineageOS or Pixel Experience GSI) will boot, standard Android lacks the proprietary Topway automotive hardware drivers:
- No CAN bus communication for steering wheel buttons or AC controls.
- No Techpoint TP2850 360° AVM camera integration.
- No ROHM BD3702 DSP equalizer and fader control.
- No native CarPlay daemon (`sd_carplay`).
