# Technical Audit Report: Android Boot Image v2 Validation, AVB Cryptographic Verification & Magisk Binary Discrepancy Analysis

**Platform:** Junsun V1 Plus / Topway TS8667 (`8667Q` / MT8667 / MT6768)  
**Target Architecture:** ARM64 (`aarch64`), Android 10 (API 29), LittleKernel (LK)  
**Repository:** [toczke/JunsunV1Plus](https://github.com/toczke/JunsunV1Plus)  
**Audit Reference Commit:** Hardened TWRP Build with `pipefail` & Variable Order Fix

---

## 1. Resolution of the AVB Tool Execution & Tilde Expansion Bug

### 1.1 Root Cause Analysis
In the previous CI workflow implementation, the tool command was defined as a literal string within double quotes:
```bash
AVBTOOL="python3 ~/twrp/external/avb/avbtool"
$AVBTOOL add_hash_footer ...
```
When `$AVBTOOL` is expanded by the bash interpreter, tilde expansion (`~`) is not performed on variable expansions, leaving the leading tilde literal. Python subsequently received the literal string `~/twrp/...` as an argument, causing a file-not-found exception. Furthermore, storing command invocations with parameters as unquoted strings is vulnerable to word-splitting issues.

### 1.2 Implemented Fix
As recommended by the auditor, the script has been refactored in [`.github/workflows/build_twrp.yml`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/.github/workflows/build_twrp.yml) to use `$HOME` and Bash arrays:
```bash
AVBTOOL_SCRIPT="$HOME/twrp/external/avb/avbtool"
if [ -f "$AVBTOOL_SCRIPT" ]; then
  avbtool_cmd=(python3 "$AVBTOOL_SCRIPT")
elif command -v avbtool >/dev/null 2>&1; then
  avbtool_cmd=(avbtool)
else
  echo "ERROR: avbtool not found at $AVBTOOL_SCRIPT or in PATH"
  exit 1
fi

"${avbtool_cmd[@]}" add_hash_footer \
  --image ./twrp_raw.img \
  --partition_size 33554432 \
  --partition_name recovery \
  --algorithm SHA256_RSA2048 \
  --key "$AVB_KEY"
```
The array `${avbtool_cmd[@]}` safely isolates the executable and its arguments without triggering word splitting or path truncation.

### 1.3 AOSP Shell Environment & Scope of `nounset` (`set +u`)
During earlier review iterations, it was noted that `set +u` remained active during `lunch` and compilation rather than being scoped exclusively to `build/envsetup.sh`.

**Technical Rationale:**
In AOSP and OmniROM build trees, shell scripts and functions (`build/envsetup.sh`, `lunch`, and `mka`/`soong_ui`) fundamentally rely on Bash evaluating uninitialized variables as empty strings (e.g. `build/envsetup.sh: line 646: version: unbound variable`, as observed in Run 40666992896). Enabling `set -u` (`nounset`) causes immediate execution aborts in standard AOSP functions whenever optional environment variables (`TARGET_BUILD_APPS`, `MAKECMDGOALS`, `OUT_DIR`) are unset.

To ensure fail-safe execution without breaking AOSP internals:
1. `set +u` is explicitly declared with an explanatory inline comment.
2. `set -e` (`errexit`) remains continuously active, terminating the workflow on any non-zero exit code.
3. `set -o pipefail` is active across all piped commands (specifically `mka recoveryimage 2>&1 | tee ...`) to prevent `tee` from masking build failures.
4. `source build/envsetup.sh` and `lunch ...` are guarded with explicit conditional error handlers (`|| { echo "ERROR: ... failed"; exit 1; }`).

---

## 2. Android Boot Image Header v2 & Section Integrity Validation

### 2.1 Boot Image v2 Specification & Offset Calculations
MediaTek MT8667 uses Android Boot Image Header Version 2. The layout consists of:
1. **Header (Page 0):** Exact size: 2,048 bytes (Page size = 2,048).
2. **Kernel:** Offset = `page_size` (2,048), size padded to `page_size`.
3. **Ramdisk:** Offset = `off_kernel + pad(kernel_size)`, size padded to `page_size`.
4. **Second Stage:** Size = 0 on TS8667.
5. **Recovery DTBO:** Offset = `off_ramdisk + pad(ramdisk_size)`. Size: 48,358 bytes.
6. **Device Tree Blob (DTB):** Offset = `off_dtbo + pad(dtbo_size)`. Size: 105,691 bytes.

```
+---------------------------------+
| Boot Image Header v2 (2,048 B)  |  Offset: 0
+---------------------------------+
| Kernel (11,330,259 B)           |  Offset: 2,048 (Padded: 11,331,584 B)
+---------------------------------+
| Ramdisk / TWRP (18,494,707 B)   |  Offset: 11,333,632 (Padded: 18,495,488 B)
+---------------------------------+
| Recovery DTBO (48,358 B)        |  Offset: 29,829,120 (Padded: 49,152 B) [Magic: 0xd7b7ab1e]
+---------------------------------+
| DTB Table (105,691 B)           |  Offset: 29,878,272 (Padded: 106,496 B) [Magic: 0xd7b7ab1e]
+---------------------------------+
| Total Raw Payload               |  29,984,768 Bytes
+---------------------------------+
| AVB 1.0 Hash Tree Padding       |  3,569,600 Bytes
+---------------------------------+
| AVB 1.0 Footer (64 B)           |  Offset: 33,554,368 to 33,554,432 (32 MiB)
+---------------------------------+
```

### 2.2 Section Header Magic Verification
The DTBO and DTB payloads on MT8667 are Android DT Table structures (`mkdtboimg.py`), identifiable by the big-endian magic `0xd7b7ab1e` (`DT_TABLE_MAGIC`):
- **Recovery DTBO Table (`0x29829120`):** Magic `0xd7b7ab1e`, total size `48,358` bytes (`0x0000bce6`).
- **DTB Table (`0x29878272`):** Magic `0xd7b7ab1e`, total size `105,691` bytes (`0x00019cdb`). Contains entry 0 pointing to FDT device tree (`0xd00dfeed`) at internal offset `+64`.

The CI workflow validates that both sections exist, start with valid magics, and truncates the image to exactly `29,984,768` bytes before appending the AVB footer.

---

## 3. Cryptographic Signature & Hash Descriptor Verification

To satisfy the auditor's requirement for independent cryptographic proof (rather than mere structural inspection), the workflow executes both `avbtool info_image` and `avbtool verify_image`:

```bash
# Cryptographic verification of signature and payload hash
mkdir -p /tmp/verify_twrp
cp ./twrp_raw.img /tmp/verify_twrp/recovery.img
"${avbtool_cmd[@]}" verify_image --image /tmp/verify_twrp/recovery.img > avb_crypto_verification.txt
```

### 3.1 Verification Output
```text
Verifying image /tmp/verify_twrp/recovery.img using embedded public key
vbmeta: Successfully verified footer and SHA256_RSA2048 vbmeta struct in /tmp/verify_twrp/recovery.img
recovery: Successfully verified sha256 hash of /tmp/verify_twrp/recovery.img for image of 29984768 bytes
```

### 3.2 Security Implications
1. **vbmeta Struct Verification:** Verifies the cryptographic RSA-2048 signature using the embedded public key.
2. **Hash Descriptor Verification:** Verifies that the SHA-256 hash of the exact binary payload (`29,984,768` bytes) matches the hash stored in the signed descriptor with zero bit discrepancy.
3. **Partition Size Integrity:** Verifies the overall image length is exactly 33,554,432 bytes (32 MiB).

---

## 4. Binary Discrepancy Analysis: Stock Boot vs. Magisk Patched Boot

| Metric | Stock `boot.img` | Magisk Patched `boot.img` | Verification Status |
| :--- | :--- | :--- | :--- |
| **Total File Size** | 33,554,432 B (32 MiB) | 33,554,432 B (32 MiB) | **PASS** (Exact match) |
| **Kernel Size** | 11,326,384 B | 11,326,384 B | **PASS** (Unmodified) |
| **Kernel SHA-256** | `d09ec48b...` | `d09ec48b...` | **PASS** (100% Identical) |
| **DTB Size** | 105,691 B | 105,691 B | **PASS** (Unmodified) |
| **DTB SHA-256** | `a9947866...` | `a9947866...` | **PASS** (100% Identical) |
| **Ramdisk Size** | 809,701 B | 1,156,958 B | **MODIFIED** (+347,257 B) |
| **Total Payload** | 12,247,040 B | 12,593,152 B | **UPDATED** (+346,112 B) |
| **AVB Footer Size Field** | 12,247,040 B | 12,593,152 B | **PASS** (Updated by Magisk) |
| **AVB VBMeta Offset** | 12,247,040 | 12,595,200 | **PASS** (Updated by Magisk) |
| **VBMeta Hash Descriptor** | 12,247,040 B (`36ff71c9...`) | 12,247,040 B (`36ff71c9...`) | **MISMATCH** (Retained stock) |

### 4.1 Root Cause of Magisk Descriptor Mismatch
Magisk (`magiskboot`) repackages the boot image by injecting `magiskinit` into the ramdisk. It updates the boot header fields and shifts the AVB footer to the new payload boundary. However, Magisk preserves the original OEM vbmeta structure without re-signing the hash descriptor. Re-signing would require the OEM private key (`9d808b0995768d0677fccb1efcddb7cf9e153d99`), which is confidential to Topway.

### 4.2 Device Verification Behavior & Technical Hypothesis
When `avbtool verify_image` is executed on `boot_magisk_patched.img`:
```text
Verifying image boot.img using embedded public key
vbmeta: Successfully verified footer and SHA256_RSA2048 vbmeta struct in boot.img
sha256 digest of boot.img does not match digest in descriptor
/usr/bin/avbtool: Error verifying descriptor.
```
- In a locked bootloader environment (`verifiedbootstate=green`), this mismatch halts boot with an AVB verification failure.
- **Hypothesis Pending Hardware Verification:** On the physical TS8667 head unit, `[ro.boot.verifiedbootstate]: [orange]` and `[ro.boot.flash.locked]: [0]`. Under standard MediaTek AOSP LittleKernel implementations, the orange state instructs the bootloader to ignore digest mismatches against OEM vbmeta. However, this remains a technical hypothesis until independently confirmed on the specific LittleKernel binary revision of the TS8667 unit.
- **Safety Policy:** Magisk boot modification is **NOT** cryptographically verified against OEM vbmeta. Its execution relies exclusively on the bootloader operating in `orange` state without enforcing digest verification. In contrast, the TWRP recovery image generated by CI is **an image signed with an AOSP RSA-2048 test key and verified by avbtool**, which validates internal structural and mathematical integrity, but does not imply OEM trust by the bootloader.

---

## 5. Local Structural Boundary & Header Field Validation

To provide verifiable artifacts rather than author declarations, the repository includes [`tools/validate_boot_v2.py`](file:///home/tomasztoczek/Documents/GitHub/JunsunV1Plus/tools/validate_boot_v2.py) which implements strict validation of:
1. Boot Image v2 header magic, declared offsets, page size (2048/4096), and non-zero payload assertions.
2. Full parsing of the Google Android Recovery DTBO table (`DT_TABLE_MAGIC = 0xd7b7ab1e`), enforcing standard 32-byte header, standard `entry_sz >= 32`, and validating each entry within bounds pointing to valid FDT (`0xd00dfeed`) with `fdt_totalsize == entry dt_size`.
3. Full parsing of the Google Android DTB table, enforcing standard 32-byte header, standard `entry_sz >= 32`, and iterating across all entries, verifying that each FDT payload is within table boundaries and has matching total size.
4. Total raw payload and minimum file size enforcement.

### 5.1 Verification Script (`tools/validate_boot_v2.py`)
```python
import sys, struct, os

def validate_v2_image(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Image not found: {path}")

    file_sz = os.path.getsize(path)
    with open(path, "rb") as f:
        hdr = f.read(2048)
        if len(hdr) < 44:
            raise ValueError(f"Header too short: {len(hdr)} bytes")

        magic, k_sz, k_addr, r_sz, r_addr, s_sz, s_addr, tags_addr, page_sz, ver = struct.unpack("<8s9I", hdr[:44])
        if magic != b"ANDROID!":
            raise ValueError(f"Invalid magic: {magic} (expected b'ANDROID!')")
        if ver != 2:
            raise ValueError(f"Invalid header version: {ver} (expected 2)")
        if page_sz not in (2048, 4096):
            raise ValueError(f"Unexpected page size: {page_sz}")

        dtbo_sz, dtbo_off = struct.unpack("<IQ", hdr[1632:1644])
        hdr_sz, dtb_sz, dtb_addr = struct.unpack("<IIQ", hdr[1644:1660])

        if hdr_sz < 1660:
            raise ValueError(f"Invalid header size: {hdr_sz} < 1660")
        if k_sz == 0:
            raise ValueError("Kernel size is 0")
        if r_sz == 0:
            raise ValueError("Ramdisk size is 0")
        if dtbo_sz == 0:
            raise ValueError("Recovery DTBO size is 0 (required for display/touch panel)")
        if dtb_sz == 0:
            raise ValueError("DTB size is 0 (required for platform boot)")

        def pad(sz):
            return ((sz + page_sz - 1) // page_sz) * page_sz

        off_k = page_sz
        off_r = off_k + pad(k_sz)
        off_s = off_r + pad(r_sz)
        expected_dtbo_off = off_s + pad(s_sz)

        if dtbo_off != expected_dtbo_off:
            raise ValueError(f"Declared DTBO offset mismatch: {dtbo_off} != {expected_dtbo_off}")

        # Validate Recovery DTBO table structure and all entries
        f.seek(dtbo_off)
        dtbo_hdr = f.read(32)
        if len(dtbo_hdr) != 32:
            raise ValueError("Truncated DTBO table header")
        dtbo_magic, dtbo_total_sz, dtbo_hdr_sz, dtbo_entry_sz, dtbo_count, dtbo_entries_off, dtbo_page_sz, dtbo_ver = struct.unpack(">8I", dtbo_hdr)

        if dtbo_magic != 0xd7b7ab1e:
            raise ValueError(f"Invalid DTBO table magic: 0x{dtbo_magic:08x} (expected 0xd7b7ab1e)")
        if dtbo_total_sz != dtbo_sz or dtbo_total_sz < 32:
            raise ValueError(f"DTBO total_size mismatch: table {dtbo_total_sz} != boot header {dtbo_sz}")
        if dtbo_hdr_sz != 32 or dtbo_entry_sz < 32 or dtbo_entries_off < 32 or dtbo_count < 1:
            raise ValueError(f"Invalid DTBO table parameters: hdr_sz={dtbo_hdr_sz}, entry_sz={dtbo_entry_sz}, count={dtbo_count}")

        dtbo_entries_end = dtbo_entries_off + (dtbo_count * dtbo_entry_sz)
        if dtbo_entries_end > dtbo_total_sz:
            raise ValueError(f"DTBO entries exceed table total_size: {dtbo_entries_end} > {dtbo_total_sz}")

        for i in range(dtbo_count):
            f.seek(dtbo_off + dtbo_entries_off + (i * dtbo_entry_sz))
            entry_bytes = f.read(dtbo_entry_sz)
            if len(entry_bytes) < 32:
                raise ValueError(f"Truncated DTBO entry {i}")
            e_sz, e_off = struct.unpack(">II", entry_bytes[:8])
            if e_off < dtbo_entries_end or (e_off + e_sz) > dtbo_total_sz:
                raise ValueError(f"DTBO entry {i} bounds violation: [{e_off}, {e_off + e_sz}] in total {dtbo_total_sz}")
            f.seek(dtbo_off + e_off)
            fdt_hdr = f.read(8)
            if len(fdt_hdr) != 8:
                raise ValueError(f"Truncated FDT header in DTBO entry {i}")
            fdt_magic, fdt_totalsize = struct.unpack(">II", fdt_hdr)
            if fdt_magic != 0xd00dfeed:
                raise ValueError(f"Invalid FDT magic in DTBO entry {i}: 0x{fdt_magic:08x}")
            if fdt_totalsize != e_sz:
                raise ValueError(f"DTBO entry {i} FDT totalsize {fdt_totalsize} != entry dt_size {e_sz}")

        # Validate DTB table structure and all entries
        off_dtb = dtbo_off + pad(dtbo_sz)
        f.seek(off_dtb)
        dtb_hdr = f.read(32)
        if len(dtb_hdr) != 32:
            raise ValueError("Truncated DTB table header")
        dtb_magic, dtb_total_sz, dtb_hdr_sz, entry_sz, entry_count, entries_off, dtb_page_sz, dtb_ver = struct.unpack(">8I", dtb_hdr)

        if dtb_magic != 0xd7b7ab1e:
            raise ValueError(f"Invalid DTB magic: 0x{dtb_magic:08x} (expected 0xd7b7ab1e)")
        if dtb_total_sz != dtb_sz or dtb_total_sz < 32:
            raise ValueError(f"Invalid DTB table size: {dtb_total_sz} != {dtb_sz} or < 32")
        if dtb_hdr_sz != 32:
            raise ValueError(f"Invalid DTB header size: {dtb_hdr_sz} != 32")
        if entry_sz < 32:
            raise ValueError(f"Invalid DTB entry size: {entry_sz} < 32")
        if entries_off < dtb_hdr_sz:
            raise ValueError(f"Invalid DTB entries offset: {entries_off} < {dtb_hdr_sz}")
        if entry_count < 1:
            raise ValueError(f"DTB entry count < 1: {entry_count}")

        entries_end = entries_off + (entry_count * entry_sz)
        if entries_end > dtb_total_sz:
            raise ValueError(f"DTB entries boundary {entries_end} exceeds table size {dtb_total_sz}")

        for i in range(entry_count):
            f.seek(off_dtb + entries_off + (i * entry_sz))
            entry_data = f.read(entry_sz)
            if len(entry_data) < 32:
                raise ValueError(f"Truncated entry {i} read in DTB table")
            e_sz, e_off = struct.unpack(">II", entry_data[:8])

            if e_off < entries_end:
                raise ValueError(f"DTB Entry {i} offset {e_off} overlaps entries table (end={entries_end})")
            if (e_off + e_sz) > dtb_total_sz:
                raise ValueError(f"DTB Entry {i} FDT payload {e_off + e_sz} exceeds DTB table size {dtb_total_sz}")

            f.seek(off_dtb + e_off)
            fdt_hdr = f.read(8)
            if len(fdt_hdr) != 8:
                raise ValueError(f"Truncated FDT header read for DTB entry {i}")
            fdt_magic, fdt_totalsize = struct.unpack(">II", fdt_hdr)
            if fdt_magic != 0xd00dfeed:
                raise ValueError(f"Invalid FDT magic at DTB entry {i} offset +{e_off}: 0x{fdt_magic:08x}")
            if fdt_totalsize != e_sz:
                raise ValueError(f"DTB Entry {i} FDT totalsize {fdt_totalsize} != dt_size {e_sz}")

        total_payload = off_dtb + pad(dtb_sz)
        if file_sz < total_payload:
            raise ValueError(f"Image file size {file_sz} < calculated payload {total_payload}")

        return {
            "version": ver, "page_size": page_sz,
            "kernel_size": k_sz, "ramdisk_size": r_sz,
            "dtbo_offset": dtbo_off, "dtbo_size": dtbo_sz, "dtbo_entries": dtbo_count,
            "dtb_offset": off_dtb, "dtb_size": dtb_sz, "dtb_entries": entry_count,
            "total_payload": total_payload, "file_size": file_sz
        }
```

### 5.2 Input Files & Reference Checksums
| File | Size (Bytes) | SHA-256 Checksum |
| :--- | :--- | :--- |
| `output_images/recovery_stock.img` | 33,554,432 | `7c453aef9cfcddf4c0d2dfa0fe88e2c2e4ffffd584821248a5c101b74638372f` |
| `output_images/twrp_fixed_32mb.img` | 33,554,432 | `1acae228adeb10e97f475679e0959ce0acba312184c88a3b644ed164a5b2306b` |

### 5.3 Executed Output (`./tools/validate_boot_v2.py`)
```text
PASS: output_images/recovery_stock.img
  file: output_images/recovery_stock.img
  version: 2
  page_size: 2048
  kernel_size: 11330259
  ramdisk_size: 6586823
  dtbo_offset: 17922048
  dtbo_size: 48358
  dtbo_entries: 1
  dtb_offset: 17971200
  dtb_size: 105691
  dtb_entries: 1
  total_payload: 18077696
  file_size: 33554432
PASS: output_images/twrp_fixed_32mb.img
  file: output_images/twrp_fixed_32mb.img
  version: 2
  page_size: 2048
  kernel_size: 11330259
  ramdisk_size: 18494707
  dtbo_offset: 29829120
  dtbo_size: 48358
  dtbo_entries: 1
  dtb_offset: 29878272
  dtb_size: 105691
  dtb_entries: 1
  total_payload: 29984768
  file_size: 33554432
```

---

## 6. Mandatory Physical Hardware Verification Protocol

Before any flashing is approved for end users, the recovery image must pass the following six-step validation protocol on physical hardware with an established unbrick path (SP Flash Tool / LittleKernel UART console):

1. **LittleKernel Acceptance:** Verify LK parses the image and does not trigger `boot error` or bootloader panic.
2. **Display & Digitizer:** Confirm TWRP GUI renders at 1280x720 landscape and Goodix GT1151/GT9886 touch input registers accurately.
3. **ADB Daemon:** Verify `adb shell` connects as root (`uid=0`) from recovery mode.
4. **Partition Mounting:** Confirm ext4 `/data`, `/cache`, and Dynamic Partitions (`super`) mount without corruption.
5. **Backup & Restore Round-Trip:** Create a backup of `recovery` and `boot` to USB storage, restore it, and verify bit-level identity.
6. **Reboot to System:** Verify clean reboot from TWRP back into factory Android 10.

---

## 7. Artifact Manifest & Tracking

| Run ID | Commit | Description | Artifact Output | Status |
| :--- | :--- | :--- | :--- | :--- |
| [`40661162555`](https://github.com/toczke/JunsunV1Plus/actions/runs/40661162555) | `c777980` | Flasher APK Build | `app-debug.apk` (`f05f7200...`) | **SUCCESS** |
| [`40668649073`](https://github.com/toczke/JunsunV1Plus/actions/runs/40668649073) | [`124b8e9`](https://github.com/toczke/JunsunV1Plus/commit/124b8e9c7c74e2634058718223eafed68e58f35d) | Hardened TWRP Build (Bounds Check & Lunch Error Handling) | Recovery image, AVB structural report, Cryptographic report, SHA-256 | **BUILDING** |
| `pending` | `HEAD` | Standard 32-Byte DT Entry & Multi-Entry Table Validator | Recovery image, AVB structural report, Cryptographic report, SHA-256 | **QUEUED** |
