#!/usr/bin/env bash
# ==============================================================================
# Topway TS8667 / Junsun V1 Plus - Reproducible Android 13 Custom ROM Build Pipeline
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$BASE_DIR/out"
GSI_DIR="$BASE_DIR/gsi"
ZIP_TEMPLATE_DIR="$BASE_DIR/flashable_zip"
REPORT_FILE="$OUT_DIR/build_report.txt"
MANIFEST_FILE="$OUT_DIR/sha256_manifest.txt"

# TS8667 Storage Limits (eMMC 32 GB, Dynamic Partition super volume)
MAX_SYSTEM_PARTITION_BYTES=2384809984 # Exact allocated size of stock system partition

mkdir -p "$OUT_DIR"
exec > >(tee "$REPORT_FILE") 2>&1

echo "================================================================="
echo " Topway TS8667 Android 13 Custom ROM Build Pipeline             "
echo " Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')                         "
echo " Host: $(uname -s -m)                                           "
echo "================================================================="

# ------------------------------------------------------------------------------
# STEP 1: Toolchain and Prerequisites Validation
# ------------------------------------------------------------------------------
echo "===> [1/6] Validating build toolchain prerequisites..."
command -v zip >/dev/null 2>&1 || { echo "ERROR: zip is required"; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum is required"; exit 1; }

# Determine C compiler for native bridges
CLANG_NDK=""
if [ -n "${ANDROID_NDK_ROOT:-}" ] && [ -d "$ANDROID_NDK_ROOT" ]; then
    NDK_BIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
    if [ -x "$NDK_BIN/aarch64-linux-android29-clang" ]; then
        CLANG_NDK="$NDK_BIN/aarch64-linux-android29-clang"
        echo "Found Android NDK Clang (API 29): $CLANG_NDK"
    fi
fi

# Fallback: check aarch64-linux-gnu-gcc
if [ -z "$CLANG_NDK" ]; then
    if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        echo "Android NDK not set; using host aarch64-linux-gnu-gcc compiler..."
    else
        echo "Using pre-built native binaries..."
    fi
fi

# ------------------------------------------------------------------------------
# STEP 2: Compile Native Automotive Hardware Bridges
# ------------------------------------------------------------------------------
echo "===> [2/6] Compiling native automotive hardware bridges..."
BRIDGE_OUT="$OUT_DIR/bridge"
mkdir -p "$BRIDGE_OUT"

if [ -n "$CLANG_NDK" ]; then
    echo "Compiling with Android NDK Bionic libc..."
    "$CLANG_NDK" -Wall -Wextra -O2 -static "$BASE_DIR/mcu_daemon/ts_mcu_daemon.c" -o "$BRIDGE_OUT/ts_mcu_daemon"
    "$CLANG_NDK" -Wall -Wextra -O2 -static "$BASE_DIR/dsp_audio/bd3702_init.c" -o "$BRIDGE_OUT/bd3702_init"
    "$CLANG_NDK" -Wall -Wextra -O2 -static "$BASE_DIR/thermal/fan_governor.c" -o "$BRIDGE_OUT/fan_governor"
elif command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 && aarch64-linux-gnu-gcc -Wall -Wextra -O2 "$BASE_DIR/mcu_daemon/ts_mcu_daemon.c" -o /tmp/null_test 2>/dev/null; then
    echo "Compiling with aarch64-linux-gnu-gcc..."
    aarch64-linux-gnu-gcc -Wall -Wextra -O2 -static "$BASE_DIR/mcu_daemon/ts_mcu_daemon.c" -o "$BRIDGE_OUT/ts_mcu_daemon"
    aarch64-linux-gnu-gcc -Wall -Wextra -O2 -static "$BASE_DIR/dsp_audio/bd3702_init.c" -o "$BRIDGE_OUT/bd3702_init"
    aarch64-linux-gnu-gcc -Wall -Wextra -O2 -static "$BASE_DIR/thermal/fan_governor.c" -o "$BRIDGE_OUT/fan_governor"
else
    echo "Copying existing validated bridge binaries..."
    cp "$BASE_DIR/mcu_daemon/ts_mcu_daemon" "$BRIDGE_OUT/"
    cp "$BASE_DIR/dsp_audio/bd3702_init" "$BRIDGE_OUT/"
    cp "$BASE_DIR/thermal/fan_governor" "$BRIDGE_OUT/"
fi

# Copy init scripts
cp "$ZIP_TEMPLATE_DIR/bridge/ts_automotive.rc" "$BRIDGE_OUT/"
cp "$ZIP_TEMPLATE_DIR/bridge/ts_automotive_init.sh" "$BRIDGE_OUT/"
chmod 755 "$BRIDGE_OUT/ts_mcu_daemon" "$BRIDGE_OUT/bd3702_init" "$BRIDGE_OUT/fan_governor" "$BRIDGE_OUT/ts_automotive_init.sh"
chmod 644 "$BRIDGE_OUT/ts_automotive.rc"

# ------------------------------------------------------------------------------
# STEP 3: Verify GSI Base Image & Capacity Boundary
# ------------------------------------------------------------------------------
echo "===> [3/6] Verifying GSI base image and dynamic partition capacity..."
GSI_IMAGE="$GSI_DIR/aosp-arm64-ab-vanilla-13.0-20230919.img"
if [ ! -f "$GSI_IMAGE" ]; then
    echo "ERROR: GSI image not found at $GSI_IMAGE"
    exit 1
fi

GSI_SIZE=$(stat -c%s "$GSI_IMAGE")
echo "  GSI Image: $(basename "$GSI_IMAGE")"
echo "  Actual Size: $GSI_SIZE bytes"
echo "  Max Partition Capacity: $MAX_SYSTEM_PARTITION_BYTES bytes"

if [ "$GSI_SIZE" -gt "$MAX_SYSTEM_PARTITION_BYTES" ]; then
    echo "ERROR: GSI image exceeds TS8667 system partition limit!"
    exit 1
fi
echo "[✓] Dynamic partition capacity check PASSED ($GSI_SIZE < $MAX_SYSTEM_PARTITION_BYTES)."

# ------------------------------------------------------------------------------
# STEP 4: Package All-in-One Flashable ROM ZIP
# ------------------------------------------------------------------------------
echo "===> [4/6] Assembling flashable ZIP payload..."
ZIP_BUILD_STAGING="$OUT_DIR/staging"
rm -rf "$ZIP_BUILD_STAGING"
mkdir -p "$ZIP_BUILD_STAGING"

# Copy META-INF and hardened updater-binary
cp -r "$ZIP_TEMPLATE_DIR/META-INF" "$ZIP_BUILD_STAGING/"
cp -r "$BRIDGE_OUT" "$ZIP_BUILD_STAGING/bridge"

# Symlink system.img into staging
ln -sf "$GSI_IMAGE" "$ZIP_BUILD_STAGING/system.img"

FINAL_ZIP="$OUT_DIR/AOSP13-TS8667-CustomROM-UNOFFICIAL.zip"
rm -f "$FINAL_ZIP"

echo "Compressing flashable ZIP archive..."
(cd "$ZIP_BUILD_STAGING" && zip -r1 "$FINAL_ZIP" META-INF bridge system.img)

# ------------------------------------------------------------------------------
# STEP 5: Package Standalone Magisk Bridge Module
# ------------------------------------------------------------------------------
echo "===> [5/6] Packaging standalone Magisk automotive bridge module..."
MAGISK_STAGING="$OUT_DIR/magisk_staging"
rm -rf "$MAGISK_STAGING"
cp -r "$BASE_DIR/bridge_module" "$MAGISK_STAGING"

# Update module binaries from newly built bridge
cp "$BRIDGE_OUT/ts_mcu_daemon" "$MAGISK_STAGING/system/bin/"
cp "$BRIDGE_OUT/bd3702_init" "$MAGISK_STAGING/system/bin/"
cp "$BRIDGE_OUT/fan_governor" "$MAGISK_STAGING/system/bin/"

MAGISK_ZIP="$OUT_DIR/TS8667_Android13_Automotive_Bridge.zip"
rm -f "$MAGISK_ZIP"
(cd "$MAGISK_STAGING" && zip -r9 "$MAGISK_ZIP" META-INF customize.sh module.prop service.sh system.prop system)

# ------------------------------------------------------------------------------
# STEP 6: Compute Cryptographic Hashes & Final Manifest
# ------------------------------------------------------------------------------
echo "===> [6/6] Generating SHA-256 integrity manifest..."
cd "$OUT_DIR"
sha256sum "$(basename "$FINAL_ZIP")" > "$MANIFEST_FILE"
sha256sum "$(basename "$MAGISK_ZIP")" >> "$MANIFEST_FILE"
sha256sum "bridge/ts_mcu_daemon" >> "$MANIFEST_FILE"
sha256sum "bridge/bd3702_init" >> "$MANIFEST_FILE"
sha256sum "bridge/fan_governor" >> "$MANIFEST_FILE"

echo ""
echo "================================================================="
echo " BUILD COMPLETE: Android 13 Custom ROM Package Generated       "
echo "================================================================="
cat "$MANIFEST_FILE"
echo ""
echo "Build report saved to: $REPORT_FILE"
