#!/usr/bin/env bash
# ==============================================================================
# Topway TS8667 - Build & Package Custom ROM (Ścieżka 2)
# ==============================================================================
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
APKS_DIR="$BASE_DIR/apks"
MODULE_DIR="$BASE_DIR/magisk_module"

mkdir -p "$APKS_DIR"

echo "===> [1/3] Checking required APKs..."
if [ ! -f "$APKS_DIR/DuduAutoUiGlobalAs_Public_Topway.apk" ]; then
    echo "Downloading DUDU Launcher (Public Topway)..."
    URL=$(curl -sL "https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=https%3A%2F%2Fdisk.yandex.com%2Fd%2FmuE5dHNEb0LzjA" | jq -r .href)
    curl -L -o "$APKS_DIR/DuduAutoUiGlobalAs_Public_Topway.apk" "$URL"
fi

if [ ! -f "$APKS_DIR/DuduAutoUiGlobal_Private_Fallback.apk" ]; then
    echo "Downloading DUDU Launcher (Private Fallback)..."
    URL=$(curl -sL "https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=https%3A%2F%2Fdisk.yandex.com%2Fd%2FA81nx5beAPak3A" | jq -r .href)
    curl -L -o "$APKS_DIR/DuduAutoUiGlobal_Private_Fallback.apk" "$URL"
fi

if [ ! -f "$APKS_DIR/ViperFX_v8.0.apk" ]; then
    echo "Downloading ViperFX RE v8.0..."
    curl -L -o "$APKS_DIR/ViperFX_v8.0.apk" "https://github.com/WSTxda/ViperFX-RE-Releases/releases/download/8.0/viperfx-release.apk"
fi

if [ ! -f "$APKS_DIR/MicroG_GmsCore.apk" ]; then
    echo "Downloading MicroG GmsCore..."
    curl -L -o "$APKS_DIR/MicroG_GmsCore.apk" "https://github.com/microg/GmsCore/releases/download/v0.3.17.252432/com.google.android.gms-252432034.apk"
fi

if [ ! -f "$APKS_DIR/MicroG_FakeStore.apk" ]; then
    echo "Downloading MicroG FakeStore..."
    curl -L -o "$APKS_DIR/MicroG_FakeStore.apk" "https://github.com/microg/GmsCore/releases/download/v0.3.17.252432/com.android.vending-84022634.apk"
fi

if [ ! -f "$APKS_DIR/OpenHeadunit_AndroidAuto.apk" ]; then
    echo "Downloading Open Headunit..."
    curl -L -o "$APKS_DIR/OpenHeadunit_AndroidAuto.apk" "https://github.com/andreknieriem/open-headunit/releases/download/v.4.0.0-beta1/com.andrerinas.headunitrevived_4.0.0-beta1.apk"
fi

if [ -f "$BASE_DIR/../prebuilt_apks/TS8667_Car_Settings_Bridge_APK/app-debug.apk" ]; then
    cp "$BASE_DIR/../prebuilt_apks/TS8667_Car_Settings_Bridge_APK/app-debug.apk" "$APKS_DIR/CarSettingsBridge.apk"
fi

echo "===> [2/3] Assembling priv-app system tree..."
mkdir -p "$MODULE_DIR/system/priv-app/DuduLauncher"
mkdir -p "$MODULE_DIR/system/priv-app/CarSettingsBridge"
mkdir -p "$MODULE_DIR/system/priv-app/ViperFX"
mkdir -p "$MODULE_DIR/system/priv-app/GmsCore"
mkdir -p "$MODULE_DIR/system/priv-app/FakeStore"
mkdir -p "$MODULE_DIR/system/priv-app/OpenHeadunit"

cp "$APKS_DIR/DuduAutoUiGlobalAs_Public_Topway.apk" "$MODULE_DIR/system/priv-app/DuduLauncher/DuduLauncher.apk"
cp "$APKS_DIR/CarSettingsBridge.apk" "$MODULE_DIR/system/priv-app/CarSettingsBridge/CarSettingsBridge.apk"
cp "$APKS_DIR/ViperFX_v8.0.apk" "$MODULE_DIR/system/priv-app/ViperFX/ViperFX.apk"
cp "$APKS_DIR/MicroG_GmsCore.apk" "$MODULE_DIR/system/priv-app/GmsCore/GmsCore.apk"
cp "$APKS_DIR/MicroG_FakeStore.apk" "$MODULE_DIR/system/priv-app/FakeStore/FakeStore.apk"
cp "$APKS_DIR/OpenHeadunit_AndroidAuto.apk" "$MODULE_DIR/system/priv-app/OpenHeadunit/OpenHeadunit.apk"

echo "===> [3/3] Packing Full & Lite Magisk zips..."
cd "$MODULE_DIR"
zip -r9 "$BASE_DIR/TS8667_Custom_OS_Sciezka2_Full.zip" META-INF module.prop system.prop customize.sh service.sh system

# Lite version
mkdir -p system_lite/priv-app/DuduLauncher system_lite/priv-app/CarSettingsBridge system_lite/priv-app/ViperFX
cp system/priv-app/DuduLauncher/DuduLauncher.apk system_lite/priv-app/DuduLauncher/
cp system/priv-app/CarSettingsBridge/CarSettingsBridge.apk system_lite/priv-app/CarSettingsBridge/
cp system/priv-app/ViperFX/ViperFX.apk system_lite/priv-app/ViperFX/
mv system system_full
mv system_lite system
zip -r9 "$BASE_DIR/TS8667_Custom_OS_Sciezka2_Lite.zip" META-INF module.prop system.prop customize.sh service.sh system
mv system system_lite
mv system_full system
rm -rf system_lite

echo "[✓] Build complete: TS8667_Custom_OS_Sciezka2_Full.zip & TS8667_Custom_OS_Sciezka2_Lite.zip"
