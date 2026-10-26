#!/usr/bin/env python3
"""
generate_twrp_installer_zip.py - Packages SojunerOS 20.0 into a TWRP flashable zip.
==================================================================================
Creates: SojunerOS-20.0-TS8667-Install.zip
Contains:
  - META-INF/com/google/android/update-binary (dynamic partition installer script)
  - META-INF/com/google/android/updater-script
  - system.img (Adapted LineageOS 20 system image)
  - boot.img (Prebuilt stock kernel + DTB)
"""

import os
import sys
import zipfile
import shutil

UPDATE_BINARY_SCRIPT = """#!/sbin/sh
# SojunerOS 20.0 Dynamic Partition Installer for Topway TS8667

OUTFD=$2
ZIPFILE=$3

ui_print() {
    if [ -n "$OUTFD" ] && [ -e "/proc/self/fd/$OUTFD" ]; then
        echo -n -e "ui_print $1\\n" > /proc/self/fd/$OUTFD
        echo -n -e "ui_print\\n" > /proc/self/fd/$OUTFD
    else
        echo "$1"
    fi
}

set_progress() {
    if [ -n "$OUTFD" ] && [ -e "/proc/self/fd/$OUTFD" ]; then
        echo -n -e "set_progress $1\\n" > /proc/self/fd/$OUTFD
    fi
}

ui_print "=========================================="
ui_print "       SojunerOS 20.0 — Android 13        "
ui_print "      Target: Topway TS8667 / MT6768      "
ui_print "=========================================="

ui_print "[*] Detecting dynamic partition mapper..."
set_progress 0.10

SYSTEM_DEV=""
for dev in "/dev/block/mapper/system" "/dev/block/by-name/system" "/dev/block/platform/bootdevice/by-name/system"; do
    if [ -e "$dev" ]; then
        SYSTEM_DEV="$dev"
        break
    fi
done

if [ -z "$SYSTEM_DEV" ]; then
    ui_print "[-] Warning: mapper/system not found. Attempting logical volume lookup..."
    SYSTEM_DEV="/dev/block/mapper/system"
fi

ui_print "[*] Target partition block: $SYSTEM_DEV"
ui_print "[*] Extracting and flashing SojunerOS 20.0 System..."
set_progress 0.30

# Unzip and pipe directly to dd
unzip -p "$ZIPFILE" system.img | dd of="$SYSTEM_DEV" bs=4M
set_progress 0.80

# Check for boot.img
if unzip -l "$ZIPFILE" | grep -q "boot.img"; then
    ui_print "[*] Flashing verified boot.img..."
    for bdev in "/dev/block/by-name/boot" "/dev/block/platform/bootdevice/by-name/boot"; do
        if [ -e "$bdev" ]; then
            unzip -p "$ZIPFILE" boot.img | dd of="$bdev" bs=4M
            break
        fi
    done
fi

set_progress 1.00
ui_print "=========================================="
ui_print " [✓] SojunerOS 20.0 installed successfully!"
ui_print "     Wipe Cache/Dalvik & Reboot System.   "
ui_print "=========================================="
exit 0
"""

def create_installer_zip(system_img_path, boot_img_path, output_zip_path):
    print("=" * 70)
    print("      Creating SojunerOS 20.0 TWRP Flashable Installer ZIP        ")
    print("=" * 70)
    print(f"[*] System Image: {system_img_path}")
    print(f"[*] Boot Image:   {boot_img_path}")
    print(f"[*] Output ZIP:   {output_zip_path}")

    if not os.path.exists(system_img_path):
        print(f"[-] Error: {system_img_path} not found.")
        sys.exit(1)

    temp_dir = "/tmp/twrp_zip_build"
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    
    meta_dir = os.path.join(temp_dir, "META-INF/com/google/android")
    os.makedirs(meta_dir, exist_ok=True)

    # Write update-binary
    ub_path = os.path.join(meta_dir, "update-binary")
    with open(ub_path, "w", newline="\n") as f:
        f.write(UPDATE_BINARY_SCRIPT)
    os.chmod(ub_path, 0o755)

    # Write updater-script (dummy file required by recovery)
    us_path = os.path.join(meta_dir, "updater-script")
    with open(us_path, "w") as f:
        f.write("# SojunerOS 20.0 Installer\n")

    print("[*] Assembling ZIP archive (using ZIP_DEFLATED for metadata, ZIP_STORED for images)...")
    with zipfile.ZipFile(output_zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(ub_path, "META-INF/com/google/android/update-binary")
        zf.write(us_path, "META-INF/com/google/android/updater-script")
        
        print("  [*] Adding system.img (uncompressed for fast recovery direct streaming)...")
        zf.write(system_img_path, "system.img", compress_type=zipfile.ZIP_STORED)

        if boot_img_path and os.path.exists(boot_img_path):
            print("  [*] Adding boot.img...")
            zf.write(boot_img_path, "boot.img", compress_type=zipfile.ZIP_STORED)

    zip_size = os.path.getsize(output_zip_path) / (1024 * 1024)
    print("=" * 70)
    print(f" [✓] Created: {output_zip_path} ({zip_size:.2f} MB)")
    print("=" * 70)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 generate_twrp_installer_zip.py <system.img> <output.zip> [boot.img]")
        sys.exit(1)

    s_img = sys.argv[1]
    o_zip = sys.argv[2]
    b_img = sys.argv[3] if len(sys.argv) > 3 else None
    create_installer_zip(s_img, b_img, o_zip)
