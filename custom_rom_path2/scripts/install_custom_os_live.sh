#!/system/bin/sh
# ==============================================================================
# Topway TS8667 / Junsun V1 Plus - Live Custom OS Installer (Ścieżka 2)
# ==============================================================================
# Executes on the radio with Root / Magisk privileges.
# Installs DUDU-OS, Car Settings Bridge, Viper4Android, MicroG & applies debloat.
# ==============================================================================

set -e

echo "====================================================="
echo " Topway TS8667 / Junsun V1 Plus Modern Custom OS"
echo " Ścieżka 2: Debloated Base + DUDU-OS + Car Bridge"
echo "====================================================="

# Check for root
if [ "$(id -u)" != "0" ]; then
    echo "[-] BŁĄD: Ten skrypt musi być uruchomiony z uprawnieniami roota (su)!"
    exit 1
fi

echo "[1/4] Sprawdzanie środowiska Magisk..."
if ! command -v magisk >/dev/null 2>&1; then
    echo "[-] BŁĄD: Magisk nie został wykryty w PATH!"
    echo "    Zainstaluj najpierw Magiska (użyj boot_magisk_patched.img)."
    exit 1
fi
echo "[+] Magisk wykryty poprawnie: $(magisk -v)"

# Locate module zip
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

ZIP_FILE=""
if [ -f "$PARENT_DIR/TS8667_Custom_OS_Sciezka2_Full.zip" ]; then
    ZIP_FILE="$PARENT_DIR/TS8667_Custom_OS_Sciezka2_Full.zip"
elif [ -f "/sdcard/TS8667_Custom_OS_Sciezka2_Full.zip" ]; then
    ZIP_FILE="/sdcard/TS8667_Custom_OS_Sciezka2_Full.zip"
elif [ -f "/mnt/media_rw/*/*/08_SCIEZKA_2_CUSTOM_ROM/TS8667_Custom_OS_Sciezka2_Full.zip" ]; then
    ZIP_FILE=$(ls /mnt/media_rw/*/*/08_SCIEZKA_2_CUSTOM_ROM/TS8667_Custom_OS_Sciezka2_Full.zip | head -n 1)
elif [ -f "$PARENT_DIR/TS8667_Custom_OS_Sciezka2_Lite.zip" ]; then
    ZIP_FILE="$PARENT_DIR/TS8667_Custom_OS_Sciezka2_Lite.zip"
fi

if [ -z "$ZIP_FILE" ] || [ ! -f "$ZIP_FILE" ]; then
    echo "[-] BŁĄD: Nie znaleziono paczki modułu TS8667_Custom_OS_Sciezka2_*.zip!"
    exit 1
fi

echo "[2/4] Instalacja modułu Custom OS przez Magisk CLI..."
echo "      Plik: $ZIP_FILE"
magisk --install-module "$ZIP_FILE"

echo "[3/4] Konfiguracja właściwości systemowych i ekranu..."
setprop ro.sf.hwrotation 0
settings put global wifi_sleep_policy 2
if [ -e /dev/ttyMT1 ]; then
    chmod 666 /dev/ttyMT1
fi

echo "[4/4] Instalacja zakończona sukcesem!"
echo "====================================================="
echo "Moduł został zarejestrowany w Magisku."
echo "Po ponownym uruchomieniu stacji:"
echo " 1. DUDU-OS uruchomi się jako nowoczesny launcher."
echo " 2. Car Settings Bridge umożliwi dostęp do ustawień CAN/MCU."
echo " 3. Viper4Android FX zapewni pełne sterowanie procesorem BD3702."
echo " 4. Chińskie trackery i bloatware zostaną ukryte."
echo "====================================================="
echo "Czy zrestartować urządzenie teraz? (Wpisz 'reboot' aby zrestartować)"
