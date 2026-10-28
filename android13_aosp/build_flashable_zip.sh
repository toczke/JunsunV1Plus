#!/usr/bin/env bash
# ==============================================================================
# Topway TS8667 - Build Industry-Standard TWRP Flashable Android 13 Custom ROM Zip
# ==============================================================================
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
GSI_DIR="$BASE_DIR/gsi"
ZIP_DIR="$BASE_DIR/flashable_zip"
OUT_ZIP="$BASE_DIR/AOSP13-TS8667-CustomROM-20261028-UNOFFICIAL.zip"

echo "===> [1/3] Verifying AOSP 13 GSI system image..."
if [ ! -f "$GSI_DIR/aosp-arm64-ab-vanilla-13.0-20230919.img" ]; then
    if [ -f "$GSI_DIR/aosp-arm64-ab-vanilla-13.0-20230919.img.xz" ]; then
        echo "Decompressing GSI image..."
        xz -dk "$GSI_DIR/aosp-arm64-ab-vanilla-13.0-20230919.img.xz"
    else
        echo "Downloading AOSP 13 GSI..."
        curl -L -o "$GSI_DIR/aosp-arm64-ab-vanilla-13.0-20230919.img.xz" \
            "https://github.com/ponces/treble_aosp/releases/download/v2023.09.19/aosp-arm64-ab-vanilla-13.0-20230919.img.xz"
        xz -dk "$GSI_DIR/aosp-arm64-ab-vanilla-13.0-20230919.img.xz"
    fi
fi

echo "===> [2/3] Linking system.img into zip template..."
cd "$ZIP_DIR"
ln -sf "../gsi/aosp-arm64-ab-vanilla-13.0-20230919.img" system.img

echo "===> [3/3] Packing All-in-One Flashable ROM Zip..."
zip -r1 "$OUT_ZIP" META-INF bridge system.img

echo "[✓] Flashable ZIP built successfully: $OUT_ZIP"
ls -lh "$OUT_ZIP"
