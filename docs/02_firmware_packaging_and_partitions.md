# Chapter 2: Firmware Packaging & Binary Formats

Deep-dive into the container formats, header layouts, and exact byte boundaries of the firmware package `8667Q军灿UI03-车模--1280x720_v22_20260626.zip`.

---

## 1. Archive Structure & Integrity Validation

The update ZIP file contains two files:
1. `8667.upd`: Plain-text ASCII file containing a 32-character hexadecimal MD5 hash:
   ```text
   d40ec7636699136f0036f60167a958e2
   ```
2. `8667.bin`: 3,904,865,648-byte combined firmware package.

### Flashing Validation Mechanism
When updated via a USB flash drive, the recovery updater reads `8667.upd`, calculates the standard MD5 checksum of `8667.bin`, and verifies they match. **There is no cryptographic RSA signature check on the outer container.** Any modification to `8667.bin` can be flashed as long as `8667.upd` is updated with the new MD5 hash:
```bash
md5sum 8667.bin | awk '{print $1}' > 8667.upd
```

---

## 2. MediaTek `xj66` Container Format

`8667.bin` uses the MediaTek `xj66` scatter container format:

### Header Layout (Offset `0x00000000` to `0x00000908`)
- **Magic (8 bytes):** `78 6a 36 36 00 00 00 00` (`xj66\0\0\0\0`)
- **Partition Directory Table (72-byte entries):**
  - Offset `+0x00` (48 bytes): Source filename (ASCII, null-padded)
  - Offset `+0x30` (16 bytes): Target partition name (ASCII, null-padded)
  - Offset `+0x40` (8 bytes): Allocated partition size (64-bit Little Endian integer)

### Partition Table parsed from Header
| Index | Filename | Partition | Allocated Size | Description |
|---|---|---|---|---|
| 0 | `super.img` | `super` | 8,118,904,824 B (Dynamic) | Android Logical Partition Container |
| 1 | `recovery.img` | `recovery` | 33,554,432 B (32 MB) | Recovery Boot Image |
| 2 | `md1img.img` | `md1img` | Dynamic | Modem DSP firmware |
| 3 | `logo.bin` | `logo` | Dynamic | Boot animation & splash logos |
| 4 | `spmfw.img` | `spmfw` | 49,296 B | System Power Management firmware |
| 5 | `scp.img` | `scp1` | 547,040 B | Cortex-M4 TinySys sensor hub (Slot 1) |
| 6 | `scp.img` | `scp2` | 547,040 B | Cortex-M4 TinySys sensor hub (Slot 2) |
| 7 | `sspm.img` | `sspm_1` | 504,208 B | Secure Processor firmware (Slot 1) |
| 8 | `sspm.img` | `sspm_2` | 504,208 B | Secure Processor firmware (Slot 2) |
| 9 | `lk.img` | `lk` | 1,510,160 B | Little Kernel Bootloader (Slot 1) |
| 10 | `lk.img` | `lk2` | 1,510,160 B | Little Kernel Bootloader (Slot 2) |
| 11 | `boot.img` | `boot` | 33,554,432 B (32 MB) | Production Android Boot Image |
| 12 | `dtbo.img` | `dtbo` | 8,388,608 B (8 MB) | Device Tree Overlay |
| 13 | `tee.img` | `tee1` | 128,112 B | ARM Trusted Firmware / TrustZone |
| 14 | `tee.img` | `tee2` | 128,112 B | ARM Trusted Firmware / TrustZone |

---

## 3. Byte-Level Offsets Inside `8667.bin`

```
0x00000000 ───┬─────────────────────────────────────────────────
              │ xj66 Container Header (0x908 = 2,312 bytes)
0x00000908 ───┼─────────────────────────────────────────────────
              │ super.img (Android Sparse Image v1.0)
              │ Magic: 0xed26ff3a, 3,363 chunks, Block Size: 4096
              │ Compressed Size: 3,823,937,528 bytes (3,646.8 MB)
              │ Unsparsed Raw Size: 4,294,967,296 bytes (4,096 MB)
0xe3ecb100 ───┼─────────────────────────────────────────────────
              │ recovery.img (33,554,432 bytes = 32 MB)
              │ Magic: ANDROID! (Boot Image Header v2)
0xe5ecb100 ───┼─────────────────────────────────────────────────
              │ spmfw.img (MTK header, 45,079 bytes)
0xe5ecb220 ───┼─────────────────────────────────────────────────
              │ scp1 / scp2 (Cortex-M4 TinySys binaries)
0xe60d8570 ───┼─────────────────────────────────────────────────
              │ lk.img / lk2.img (Little Kernel Bootloader + DTB)
0xe63b9c90 ───┼─────────────────────────────────────────────────
              │ boot.img (33,554,432 bytes = 32 MB)
              │ Magic: ANDROID! (Boot Image Header v2)
0xe83b9c90 ───┼─────────────────────────────────────────────────
              │ dtbo.img (8,388,608 bytes = 8 MB, DTB Magic 0xd00dfeed)
0xe8bb9c90 ───┼─────────────────────────────────────────────────
              │ logo.bin (Splash images for multiple car models)
0xe8c13b90 ───┴─────────────────────────────────────────────────
              End of File (Total: 3,904,865,648 bytes)
```

---

## 4. Logical Dynamic Partitions (`super.img`)

Unpacking `super_raw.img` via `lpunpack` yields the standard Android 10 ext4 sub-partitions:

1. **`system.img` (2,018 MB):**
   - Filesystem: ext4 (`Linux rev 1.0 ext2/ext4`)
   - Mount point: `/` (System-as-Root)
   - Contents: Android Framework, Core services, GMS, `/system/app`, `/system/priv-app`, `/system/tsoem`.
2. **`vendor.img` (1,430 MB):**
   - Filesystem: ext4 (`volume name "vendor"`)
   - Mount point: `/vendor`
   - Contents: MediaTek SoC drivers, camera tuning (`tp2850`), touch firmware (`gt1151`), HAL daemons, active launchers (`tsoem/launcher`).
3. **`product.img` (230 MB):**
   - Filesystem: ext4 (`volume name "product"`)
   - Mount point: `/product`
   - Contents: Android WebView (`app/webview/webview.apk`), Carrier configs, product overlays, icon packs.

---

## 5. Storage Partition Table (`fstab.mt6768`)

Extracted from `/boot.img` ramdisk:

```text
system     /system             ext4  ro  wait,,avb=vbmeta_system,logical,first_stage_mount
vendor     /vendor             ext4  ro  wait,,avb,logical,first_stage_mount
product    /product            ext4  ro  wait,,avb,logical,first_stage_mount
userdata   /data               ext4  noatime,nosuid,nodev  wait,check,formattable,quota,fileencryption=aes-256-xts
cache      /cache              ext4  noatime,nosuid,nodev  wait,check,formattable
avm        /mnt/avm            ext4  noatime,nosuid,nodev  wait,check,formattable (360 AVM calibration data)
nvdata     /mnt/vendor/nvdata  ext4  noatime,nosuid,nodev  wait,check,formattable (Modem & Radio calibration)
protect1   /mnt/vendor/protect_f ext4 wait,check,formattable (IMEI / serial storage)
protect2   /mnt/vendor/protect_s ext4 wait,check,formattable (SIM security parameters)
```
