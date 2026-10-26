#!/usr/bin/env bash
# ==============================================================================
# build_adapted_sojuneros20.sh - End-to-end SojunerOS 20.0 (Android 13) Builder
# ==============================================================================
# Adapts LineageOS 20 (API 33 / Android 13) for Topway TS8667 / Junsun V1 Plus:
#   1. Expands system image filesystem
#   2. Mounts ext4 loopback
#   3. Injects CarSettingsBridge APK into /system/priv-app/CarSettingsBridge
#   4. Injects Topway CAN bus protocol engine (libcan59.so, 340+ vehicle models)
#   5. Injects MCU serial communication layer (libts67xhw.so, libts70xicfg.so)
#   6. Injects Topway MainUI vehicle daemon (/system/app/MainUI)
#   7. Injects Front USB Dashcam (/system/app/CarDVR) & DVDBox (/system/app/DvdBox)
#   8. Configures SurfaceFlinger forced 1280x720 landscape orientation
#   9. Injects init.ts8667.rc device node permissions (/dev/ttyMT1, /dev/ts07_dsp)
#  10. Generates TWRP flashable zip (SojunerOS-20.0-TS8667-Install.zip)
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="/home/tomasztoczek/Downloads/sojuneros_workspace"
GSI_RAW="${WORKSPACE}/lineage-20.img"
OUTPUT_IMG="${WORKSPACE}/sojuneros-20.0-ts8667-system.img"
OUTPUT_ZIP="${REPO_DIR}/out/sojuneros/SojunerOS-20.0-TS8667-Install.zip"
PROPRIETARY_DIR="${REPO_DIR}/vendor/topway/ts8667/proprietary"
PREBUILT_APKS="${REPO_DIR}/prebuilt_apks"
MOUNT_POINT="/tmp/sojuneros_mount"

echo "========================================================================"
echo "          SojunerOS 20.0 (Android 13) Automotive Custom ROM Builder     "
echo "        Target: Topway TS8667 / Junsun V1 Plus (MediaTek MT8667)        "
echo "========================================================================"

if [[ ! -f "$GSI_RAW" ]]; then
    echo "[-] Error: Raw LineageOS 20 image not found at $GSI_RAW"
    exit 1
fi

mkdir -p "${REPO_DIR}/out/sojuneros"

echo "[1/6] Preparing SojunerOS 20.0 base system image..."
cp -f "$GSI_RAW" "$OUTPUT_IMG"

echo "[2/6] Resizing filesystem to accommodate automotive packages (2800 MB)..."
# Expand raw file size to 2800M first, then resize ext4
truncate -s 2936012800 "$OUTPUT_IMG"
e2fsck -f -y "$OUTPUT_IMG" || true
resize2fs "$OUTPUT_IMG"
e2fsck -f -y "$OUTPUT_IMG" || true

echo "[3/6] Mounting SojunerOS 20.0 system image..."
sudo mkdir -p "$MOUNT_POINT"
# In case it was already mounted
sudo umount "$MOUNT_POINT" 2>/dev/null || true
sudo mount -o loop,rw "$OUTPUT_IMG" "$MOUNT_POINT"

echo "[4/6] Injecting Topway Automotive Hardware Stack..."

# Determine system root (system-as-root vs /system)
SYS_ROOT="$MOUNT_POINT"
if [[ -d "$MOUNT_POINT/system" ]]; then
    SYS_ROOT="$MOUNT_POINT/system"
fi

# A. CarSettingsBridge (Settings Tile Integration)
echo "  [*] Injecting CarSettingsBridge..."
sudo mkdir -p "$SYS_ROOT/priv-app/CarSettingsBridge"
sudo cp -f "$PREBUILT_APKS/TS8667_Car_Settings_Bridge_APK/app-debug.apk" "$SYS_ROOT/priv-app/CarSettingsBridge/CarSettingsBridge.apk"
sudo chmod 644 "$SYS_ROOT/priv-app/CarSettingsBridge/CarSettingsBridge.apk"
sudo chown 0:0 "$SYS_ROOT/priv-app/CarSettingsBridge/CarSettingsBridge.apk"

# B. Automotive Hardware Daemons & Apps
echo "  [*] Injecting Topway MainUI Daemon..."
sudo mkdir -p "$SYS_ROOT/app/MainUI"
sudo cp -f "$PROPRIETARY_DIR/app/MainUI/MainUI.apk" "$SYS_ROOT/app/MainUI/MainUI.apk"
sudo chmod 644 "$SYS_ROOT/app/MainUI/MainUI.apk"
sudo chown 0:0 "$SYS_ROOT/app/MainUI/MainUI.apk"

echo "  [*] Injecting Front Dashcam (CarDVR)..."
sudo mkdir -p "$SYS_ROOT/app/CarDVR"
sudo cp -f "$PROPRIETARY_DIR/app/CarDVR/com.ankai.cardvr_v1.0.0_20231226_104230_myx44.apk" "$SYS_ROOT/app/CarDVR/CarDVR.apk"
sudo chmod 644 "$SYS_ROOT/app/CarDVR/CarDVR.apk"
sudo chown 0:0 "$SYS_ROOT/app/CarDVR/CarDVR.apk"

echo "  [*] Injecting USB DVD Box Player..."
sudo mkdir -p "$SYS_ROOT/app/DvdBox"
sudo cp -f "$PROPRIETARY_DIR/app/DvdBox/DvdBox.apk" "$SYS_ROOT/app/DvdBox/DvdBox.apk"
sudo chmod 644 "$SYS_ROOT/app/DvdBox/DvdBox.apk"
sudo chown 0:0 "$SYS_ROOT/app/DvdBox/DvdBox.apk"

# C. Proprietary 32-bit Vehicle Libraries
echo "  [*] Injecting Topway CAN bus engine and MCU communication libraries..."
sudo mkdir -p "$SYS_ROOT/lib"
for lib in "libcan59.so" "libts67xhw.so" "libts67xlogo.so" "libts70xicfg.so" "libsdvdplayer.so"; do
    if [[ -f "$PROPRIETARY_DIR/lib/$lib" ]]; then
        sudo cp -f "$PROPRIETARY_DIR/lib/$lib" "$SYS_ROOT/lib/$lib"
        sudo chmod 644 "$SYS_ROOT/lib/$lib"
        sudo chown 0:0 "$SYS_ROOT/lib/$lib"
        echo "    [+] Injected: $lib"
    fi
done

# D. Automotive Properties & SurfaceFlinger Landscape Lock
echo "  [*] Configuring Landscape SurfaceFlinger & Automotive properties in build.prop..."
cat << 'EOF' | sudo tee -a "$SYS_ROOT/build.prop" > /dev/null

# ==============================================================================
# SojunerOS 20.0 Automotive Configurations for TS8667
# ==============================================================================
ro.sf.hwrotation=0
ro.surface_flinger.primary_display_orientation=ORIENTATION_0
persist.sys.orientation=landscape
ro.sf.lcd_density=213
persist.sys.sf.native_mode=1
persist.sys.can.baud=115200
ro.audio.silent=0
ro.topway.sojuneros.version=20.0-TS8667
EOF

# E. Device Node Initialization (init.ts8667.rc)
echo "  [*] Injecting init.ts8667.rc device node permissions..."
sudo mkdir -p "$SYS_ROOT/etc/init"
cat << 'EOF' | sudo tee "$SYS_ROOT/etc/init/init.ts8667.rc" > /dev/null
# Topway TS8667 Automotive Hardware Initialization for SojunerOS 20.0
on boot
    # MCU UART Communication (/dev/ttyMT1 @ 115200)
    chmod 0666 /dev/ttyMT1
    chown system radio /dev/ttyMT1
    setprop persist.sys.can.baud 115200

    # ROHM BD3702FV DSP I2C driver
    chmod 0666 /dev/ts07_dsp
    chown media audio /dev/ts07_dsp

    # Techpoint TP2850 Reversing Video Decoder
    chmod 0666 /dev/video0
    chmod 0666 /dev/video1

    # Forced 16:9 Landscape SurfaceFlinger configuration
    setprop ro.sf.hwrotation 0
    setprop ro.surface_flinger.primary_display_orientation ORIENTATION_0
    setprop persist.sys.orientation landscape
    setprop ro.audio.silent 0
EOF
sudo chmod 644 "$SYS_ROOT/etc/init/init.ts8667.rc"
sudo chown 0:0 "$SYS_ROOT/etc/init/init.ts8667.rc"

echo "[5/6] Unmounting and verifying filesystem integrity..."
sync
sudo umount "$MOUNT_POINT"
sudo e2fsck -f -y "$OUTPUT_IMG" || true

echo "[6/6] Generating TWRP Flashable Installer ZIP..."
python3 "${REPO_DIR}/tools/generate_twrp_installer_zip.py" \
    "$OUTPUT_IMG" \
    "$OUTPUT_ZIP" \
    "/home/tomasztoczek/Downloads/fw_8667_extract/partitions/boot.img"

echo "========================================================================"
echo " [✓] SojunerOS 20.0 Build Pipeline Complete!"
echo "     System Image: ${OUTPUT_IMG}"
echo "     Install ZIP:  ${OUTPUT_ZIP}"
echo "========================================================================"
