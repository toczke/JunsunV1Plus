#!/usr/bin/env bash
# ==============================================================================
# Topway TS8667 - Flash Pure Android 13 AOSP GSI via Fastbootd
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
GSI_IMG="$BASE_DIR/gsi/aosp-arm64-ab-vanilla-13.0-20230919.img"

echo "====================================================="
echo " Topway TS8667 - Android 13 AOSP Fastbootd Flasher"
echo "====================================================="

if [ ! -f "$GSI_IMG" ]; then
    echo "[-] BŁĄD: Nie znaleziono obrazu: $GSI_IMG"
    exit 1
fi

echo "[1/4] Sprawdzanie połączenia w trybie fastbootd..."
echo "Upewnij się, że radio jest w trybie fastbootd (ekran: Fastbootd, nie klasyczny bootloader)!"
fastboot devices

echo "[2/4] Czyszczenie i przygotowanie logicznej partycji system..."
fastboot erase system || true

echo "[3/4] Wgrywanie czystego Androida 13 AOSP GSI do partycji system..."
fastboot flash system "$GSI_IMG"

echo "[4/4] Formatowanie partycji userdata i cache (wymagane przy zmianie wersji Androida)..."
fastboot -w

echo "====================================================="
echo "[✓] Android 13 AOSP został pomyślnie wgrany!"
echo "Wpisz: fastboot reboot aby uruchomić system."
echo "====================================================="
