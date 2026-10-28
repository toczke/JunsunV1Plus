#!/system/bin/sh
# ==============================================================================
# Topway TS8667 / Junsun V1 Plus - Custom OS Rollback / Uninstaller
# ==============================================================================

if [ "$(id -u)" != "0" ]; then
    echo "[-] BŁĄD: Wymagane uprawnienia roota (su)!"
    exit 1
fi

echo "===> Usuwanie modułu Custom OS (Ścieżka 2)..."
if [ -d "/data/adb/modules/ts8667-custom-os" ]; then
    touch "/data/adb/modules/ts8667-custom-os/remove"
    echo "[+] Utworzono flagę 'remove'. Moduł zostanie usunięty przy następnym starcie."
    echo "[+] Alternatywnie usuwam katalog bezpośrednio:"
    rm -rf /data/adb/modules/ts8667-custom-os
    echo "[✓] Moduł usunięty. Wszystkie aplikacje fabryczne i launcher powrócą po restarcie."
else
    echo "[!] Moduł nie był zainstalowany w /data/adb/modules/ts8667-custom-os."
fi
