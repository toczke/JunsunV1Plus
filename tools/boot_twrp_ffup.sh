#!/bin/bash
set -e

IP="${1:-192.168.0.178}"
PORT="5555"
BACKDOOR="@#zxcvbnmasdfghjklqwertyuiop1234567890,."

echo "=================================================="
echo "Wgrywanie TWRP i start Recovery (metoda ffup)"
echo "Cel: $IP:$PORT"
echo "=================================================="

echo "[1/4] Łączenie przez ADB..."
adb connect "$IP:$PORT" || true

echo "[2/4] Przesyłanie obrazu TWRP..."
adb push output_images/twrp_fixed_32mb.img /data/local/tmp/twrp.img

echo "[3/4] Wgrywanie na recovery i ustawianie triggera ffup w misc..."
adb shell << EOF
/system/xbin/ffsu $BACKDOOR
dd if=/data/local/tmp/twrp.img of=/dev/block/by-name/recovery bs=4M
printf "ffup" | dd of=/dev/block/by-name/misc bs=4 count=1 conv=notrunc
sync
rm -f /data/local/tmp/twrp.img
exit
exit
EOF

echo "[4/4] Restartowanie stacji (zwykły reboot - LK odczyta ffup)..."
adb reboot

echo "=================================================="
echo "SUKCES! Stacja uruchomi się do TWRP."
echo "Jeśli dotyk nie odpowiada, podłącz myszkę USB!"
echo "=================================================="
