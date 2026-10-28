#!/sbin/sh
# ==============================================================================
# Topway TS8667 - Flash Pure Android 13 AOSP GSI via TWRP Terminal
# ==============================================================================

echo "====================================================="
echo " Topway TS8667 - Flash Android 13 AOSP in TWRP"
echo "====================================================="

GSI_IMG="/sdcard/aosp-arm64-ab-vanilla-13.0-20230919.img"
[ ! -f "$GSI_IMG" ] && GSI_IMG=$(ls /external_sd/09_ANDROID_13_AOSP_GSI/*.img 2>/dev/null | head -n 1)
[ ! -f "$GSI_IMG" ] && GSI_IMG=$(ls /usb_otg/09_ANDROID_13_AOSP_GSI/*.img 2>/dev/null | head -n 1)

if [ -z "$GSI_IMG" ] || [ ! -f "$GSI_IMG" ]; then
    echo "[-] BŁĄD: Nie znaleziono obrazu system.img na USB OTG ani w /sdcard!"
    exit 1
fi

echo "[1/3] Wykryto obraz GSI: $GSI_IMG"

# Locate mapped system block device
SYS_BLOCK="/dev/block/mapper/system"
if [ ! -b "$SYS_BLOCK" ]; then
    SYS_BLOCK="/dev/block/by-name/system"
fi

echo "[2/3] Zapisywanie obrazu Android 13 do partycji system..."
dd if="$GSI_IMG" of="$SYS_BLOCK" bs=4M
sync

echo "[3/3] Zakończono pomyślnie!"
echo "Pamiętaj: Wykonaj w menu TWRP 'Wipe -> Format Data' przed pierwszym uruchomieniem!"
