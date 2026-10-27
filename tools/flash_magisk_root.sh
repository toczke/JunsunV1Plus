#!/bin/bash
set -e

IP="${1:-192.168.0.178}"
PORT="5555"
BACKDOOR="@#zxcvbnmasdfghjklqwertyuiop1234567890,."

echo "=================================================="
echo "Wgrywanie Roota Magisk na Topway TS8667"
echo "Cel: $IP:$PORT"
echo "=================================================="

echo "[1/4] Łączenie przez ADB..."
adb connect "$IP:$PORT" || true

echo "[2/4] Przesyłanie spatchowanego obrazu boot.img..."
adb push output_images/boot_magisk_patched.img /data/local/tmp/boot_magisk_patched.img

echo "[3/4] Wgrywanie na partycję /dev/block/by-name/boot..."
adb shell << EOF
/system/xbin/ffsu $BACKDOOR
dd if=/data/local/tmp/boot_magisk_patched.img of=/dev/block/by-name/boot bs=4M
sync
rm -f /data/local/tmp/boot_magisk_patched.img
exit
exit
EOF

echo "[4/4] Restartowanie stacji..."
adb reboot

echo "=================================================="
echo "SUKCES! Stacja uruchomi się z pełnym Rootem Magisk."
echo "Zainstaluj Magisk-v27.0.apk z pendrive'a po starcie."
echo "=================================================="
