#!/bin/bash
set -e

IP="${1:-192.168.0.178}"
PORT="5555"
BACKDOOR="@#zxcvbnmasdfghjklqwertyuiop1234567890,."

echo "=================================================="
echo "Przywracanie fabrycznego boot.img i czyszczenie misc"
echo "Cel: $IP:$PORT"
echo "=================================================="

echo "[1/4] Łączenie przez ADB..."
adb connect "$IP:$PORT" || true

echo "[2/4] Przesyłanie fabrycznego boot_stock.img..."
adb push output_images/boot_stock.img /data/local/tmp/boot_stock.img

echo "[3/4] Przywracanie boot i zerowanie misc..."
adb shell << EOF
/system/xbin/ffsu $BACKDOOR
dd if=/data/local/tmp/boot_stock.img of=/dev/block/by-name/boot bs=4M
dd if=/dev/zero of=/dev/block/by-name/misc bs=4 count=1 conv=notrunc
sync
rm -f /data/local/tmp/boot_stock.img
exit
exit
EOF

echo "[4/4] Restartowanie stacji..."
adb reboot

echo "=================================================="
echo "SUKCES! Stacja przywrócona do stanu fabrycznego."
echo "=================================================="
