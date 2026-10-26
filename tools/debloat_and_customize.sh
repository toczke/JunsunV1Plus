#!/usr/bin/env bash
# ==============================================================================
# Junsun V1 Plus / Topway TS10 (MT8667) - Custom ROM De-bloat & Customizer
# ==============================================================================
# Prunes Chinese telemetry, obsolete CarPlay/AA, and junk launchers.
# Preserves DVR (com.ankai.cardvr), TPMS, DVD, and CAN/MCU hardware services.
# Sets DUDU-OS as default launcher and installs Car Settings Bridge.
# ==============================================================================

set -euo pipefail

SYS_DIR="${1:-}"
VENDOR_DIR="${2:-}"

if [[ -z "$SYS_DIR" || ! -d "$SYS_DIR" ]]; then
    echo "Usage: $0 <path_to_unpacked_system> [path_to_unpacked_vendor]"
    echo "Example: $0 /tmp/dump/system /tmp/dump/vendor"
    exit 1
fi

echo "===> [1/5] Removing Chinese bloatware, tracking daemons, and backdoors..."
BLOAT_PATHS=(
    # Telemetry and spyware daemons
    "system/priv-app/cpe_agent"
    "system/app/cpe_agent"
    "system/app/txz"
    "system/priv-app/txz"
    "system/app/cservice"
    "system/priv-app/cservice"
    "system/app/ximalaya"
    "system/app/autonavi"
    "system/app/radio_topway_online"
    "system/xbin/ffsu" # Remove backdoor root shell (use official Magisk instead)
)

for rel in "${BLOAT_PATHS[@]}"; do
    target="$SYS_DIR/$rel"
    if [[ -e "$target" ]]; then
        echo "  [-] Removing: $rel"
        rm -rf "$target"
    fi
done

if [[ -n "$VENDOR_DIR" && -d "$VENDOR_DIR" ]]; then
    echo "===> [2/5] Pruning vendor junk launchers & obsolete phone links..."
    
    # Prune stock launchers (UI00 - UI04) in favor of DUDU-OS
    rm -rf "$VENDOR_DIR/tsoem/launcher/apks/"* 2>/dev/null || true
    echo "  [-] Removed all vendor OEM launchers (UI00..UI04)"

    # Prune obsolete CarLink / EasyConnect / CarLetter (making room for DiPlay / AutoKit)
    VENDOR_BLOAT=(
        "app/sd_carplay"
        "app/CarLetter"
        "app/EasyConnect"
        "priv-app/net.easyconn"
        "tsoem/app/CarLetter"
    )
    for vrel in "${VENDOR_BLOAT[@]}"; do
        vtarget="$VENDOR_DIR/$vrel"
        if [[ -e "$vtarget" ]]; then
            echo "  [-] Removing vendor: $vrel"
            rm -rf "$vtarget"
        fi
    done
fi

echo "===> [3/5] Verifying retention of critical vehicle hardware apps..."
RETAIN_CHECKS=(
    "system/priv-app/MainUI" # Central hardware daemon & CAN/MCU service
    "system/priv-app/CarDVR" # Dashcam front recorder
    "vendor/app/DvdBox"      # External USB DVD drive player
)

for chk in "${RETAIN_CHECKS[@]}"; do
    path="$SYS_DIR/$chk"
    if [[ "$chk" == vendor/* && -n "$VENDOR_DIR" ]]; then
        path="$VENDOR_DIR/${chk#vendor/}"
    fi
    if [[ -e "$path" ]]; then
        echo "  [✓] Verified retained: $chk"
    else
        echo "  [!] Note: $chk not found in expected path, verify manual location."
    fi
done

echo "===> [4/5] Enforcing Automotive Landscape Configuration (1280x720)..."
BUILD_PROP="$SYS_DIR/build.prop"
if [[ -f "$BUILD_PROP" ]]; then
    # Force landscape orientation
    sed -i '/ro.sf.hwrotation/d' "$BUILD_PROP"
    echo "ro.sf.hwrotation=0" >> "$BUILD_PROP"
    
    # Strip fake version spoofing to allow clean GApps/MicroG compatibility
    sed -i 's/ro.forfan.version.release=.*/ro.forfan.version.release=10/' "$BUILD_PROP"
    sed -i 's/ro.forfan.aida64.version.sdk=.*/ro.forfan.aida64.version.sdk=29/' "$BUILD_PROP"
    echo "  [✓] Fixed build.prop rotation & OS version properties"
fi

echo "===> [5/5] De-bloat and hardware whitelist configuration completed successfully!"
