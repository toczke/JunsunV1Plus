# SojunerOS 20.0 — Emergency Recovery, Unbricking & Rollback Guide

**Target Platform:** Junsun V1 Plus / JunCan UI03 (Topway TS-8667-02)  
**Safety Classification:** Level 3 Automotive Device Recovery  

---

## 1. Safety Tiers & Recovery Hierarchy

When flashing custom ROMs or modified partitions, hardware failure or bootloops must be addressed using the appropriate recovery tier:

```
+-------------------------------------------------------------+
| Tier 1: Software Recovery (TWRP / ADB Shell)                |
| - Wipe Dalvik/Data, flash ZIP updates, restore backups      |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| Tier 2: Topway Hardware Bootloader Flash (Forced USB Mode)   |
| - Little Kernel (lk.img) recovery via FAT32 8667.bin/upd    |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| Tier 3: MediaTek BROM / Preloader Mode (SP Flash Tool)      |
| - Low-level eMMC direct partition flashing via MTK UART/USB |
+-------------------------------------------------------------+
```

---

## 2. Tier 1: TWRP Recovery Partition Restore

If TWRP is flashed to the `recovery` partition:
1. Boot into TWRP:
   - Via ADB: `adb reboot recovery`
   - Or via hardware: Hold the **RST (Reset)** pin for 10 seconds while applying 12V power.
2. Under TWRP Main Menu:
   - Tap **Restore**.
   - Select your external USB drive containing the stock TWRP backup.
   - Select `Boot`, `System`, `Vendor`, and `Product` partitions.
   - Swipe to Restore.
3. Once completed, tap **Wipe Cache/Dalvik** and **Reboot System**.

---

## 3. Tier 2: Topway Forced USB Recovery Mode

If the Android OS fails to boot, the Topway Little Kernel (`lk.img`) possesses a built-in hardware recovery routine that scans USB Port 1 on cold boot.

### Step-by-Step Procedure:
1. Prepare a USB 2.0 thumb drive formatted to **FAT32** (Single MBR partition).
2. Copy the verified untouched stock firmware files to the root directory:
   ```
   8667.bin  (Size: ~4.1GB)
   8667.upd  (MD5: d40ec7636699136f0036f60167a958e2)
   ```
3. Connect the USB drive into **USB Port 1** (the 4-pin connector on the headunit harness).
4. Depress and hold the physical **RST** button (pinhole on front bezel) with a paperclip.
5. Turn on power (ACC + BATT 12V).
6. Continue holding RST for 5 seconds after power is applied, then release.
7. The bootloader detects the update package and begins flashing directly to eMMC.
8. A green progress bar appears on screen. When completed, the unit displays "SUCCESS - PLEASE REMOVE USB".
9. Unplug the USB drive; the headunit reboots into factory stock Android 10.

---

## 4. Tier 3: Unbricking via SP Flash Tool / MTK Client

If the bootloader (`lk.img`) or partition table is corrupted and the screen stays black:

### Requirements:
- MediaTek USB VCOM Drivers installed on host PC.
- `mtkclient` (Python open-source tool) or SP Flash Tool v5.21+.
- TS8667 Scatter File: `MT6768_Android_scatter.txt`.
- USB connection to PC via the headunit's 4-pin USB port.

### Flashing with `mtkclient`:
```bash
# 1. Install mtkclient dependencies
sudo apt-get install python3-pip libusb-1.0-0 libusb-1.0-0-dev
pip3 install pyusb pyserial pycryptodome

# 2. Put headunit into BROM mode:
# Disconnect power, hold Testpoint (TP) or RST, plug USB into PC
mtk print-partition

# 3. Restore vital partitions directly to eMMC:
mtk write boot /path/to/stock/boot.img
mtk write recovery /path/to/stock/recovery.img
mtk write lk /path/to/stock/lk.img
mtk write lk2 /path/to/stock/lk.img

# 4. Reboot headunit
mtk reset
```

---

## 5. Verified Stock Checksums for Rollback Validation

Before initiating any flash or rollback, verify your files against the verified SHA-256 and MD5 hashes:

| Partition / Archive | Size (Bytes) | MD5 / SHA-256 Hash |
| :--- | :--- | :--- |
| **`8667.bin` (Complete Package)** | 4,213,959,104 | MD5: `d40ec7636699136f0036f60167a958e2` |
| **`boot.img`** | 33,554,432 | SHA-256: `df89a526f669cfcfcfd50dcae76d422870bd4c045359e386469bc6b97ce285a8` |
| **`recovery.img`** | 33,554,432 | SHA-256: `7c453aef9cfcddf4c0d2dfa0fe88e2c2e4ffffd584821248a5c101b74638372f` |
| **`system.img`** | 2,116,374,528 | SHA-256: `c5a1fb85f20811f99665c77525c388e3d46235698f0b625639b906066a0a02a6` |
| **`vendor.img`** | 1,500,356,608 | SHA-256: `c5b777cc884816730f8302489578255051790d0f65854a968e598b7a75a29730` |
| **`product.img`** | 241,696,768 | SHA-256: `396b5762ca69af6e97f00194ca56264e79f2cc92e3613ed05bceab2e67858990` |
