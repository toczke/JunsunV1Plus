#!/sbin/sh
# ==============================================================================
# Topway TS8667 / Junsun V1 Plus - TWRP Custom OS Installer (Ścieżka 2)
# ==============================================================================

echo "====================================================="
echo " Topway TS8667 - TWRP Custom OS Installer (Ścieżka 2)"
echo "====================================================="

# Mount data partition
mount /data 2>/dev/null || true

if [ ! -d /data/adb ]; then
    echo "[-] BŁĄD: Partycja /data nie jest zamontowana lub brak katalogu /data/adb!"
    exit 1
fi

mkdir -p /data/adb/modules/ts8667-custom-os

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

ZIP_FILE=""
if [ -f "$PARENT_DIR/TS8667_Custom_OS_Sciezka2_Full.zip" ]; then
    ZIP_FILE="$PARENT_DIR/TS8667_Custom_OS_Sciezka2_Full.zip"
elif [ -f "/sdcard/TS8667_Custom_OS_Sciezka2_Full.zip" ]; then
    ZIP_FILE="/sdcard/TS8667_Custom_OS_Sciezka2_Full.zip"
elif [ -f "$PARENT_DIR/TS8667_Custom_OS_Sciezka2_Lite.zip" ]; then
    ZIP_FILE="$PARENT_DIR/TS8667_Custom_OS_Sciezka2_Lite.zip"
fi

if [ -n "$ZIP_FILE" ]; then
    echo "[+] Rozpakowywanie modułu do /data/adb/modules/ts8667-custom-os..."
    unzip -o "$ZIP_FILE" -d /data/adb/modules/ts8667-custom-os
    chmod -R 755 /data/adb/modules/ts8667-custom-os
    echo "[✓] Zainstalowano pomyślnie w TWRP!"
else
    echo "[-] Nie znaleziono pliku ZIP z modułem!"
    exit 1
fi
