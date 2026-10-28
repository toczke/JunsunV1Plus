# Kompleksowy Przewodnik Przywracania Fabrycznego: SP Flash Tool & Emergency Restore
## Junsun V1 Plus / Topway TS8667 (MediaTek Helio P65 MT6768 / spm8667p1_64)

Niniejszy pakiet zawiera kompletny, zweryfikowany zestaw fabrycznych obrazów partycji oraz oficjalny plik mapowania pamięci `MT6768_Android_scatter.txt` przeznaczony do ratowania stacji multimedialnej w przypadku twardego unieruchomienia (hard-brick, pętla bootloadera, czarny ekran) przy użyciu oprogramowania **SP Flash Tool** lub **mtkclient**.

---

## 1. Wykaz Zawartości Pakietu (`SP_FLASH_TOOL_RESTORE_TS8667`)

| Plik | Rozmiar | Partycja docelowa | Opis zawartości |
| :--- | :--- | :--- | :--- |
| **`MT6768_Android_scatter.txt`** | ~16 KB | - | Tablica układu pamięci eMMC zgodna z BootROM MT6768 |
| **`super.img`** | 3 823 937 528 B | `super` | Kontener dynamiczny: fabryczny `system`, `vendor`, `product` |
| **`boot.img`** | 33 554 432 B | `boot` | Fabryczne jądro Android Boot v2 (Kernel 4.14 + ramdisk) |
| **`recovery.img`** | 33 554 432 B | `recovery` | Fabryczne recovery Topway z podpisem AVB 1.0 |
| **`lk.img`** | 1 510 160 B | `lk` oraz `lk2` | LittleKernel (główny i zapasowy bootloader MediaTek) |
| **`dtbo.img`** | 8 388 608 B | `dtbo` | Device Tree Blob Overlay |
| **`spmfw.img`** | 49 296 B | `spmfw` | System Power Management firmware |
| **`scp.img`** | 547 040 B | `scp1` oraz `scp2` | TinySys Cortex-M4 Sensor Hub |
| **`sspm.img`** | 504 208 B | `sspm_1`, `sspm_2`| Secure System Power Manager |
| **`tee.img`** | 128 112 B | `tee1`, `tee2` | ARM Trusted Firmware / TrustZone TEE |
| **`vbmeta.img`** | 1 048 576 B | `vbmeta` | Klucze kryptograficzne Android Verified Boot (AVB 2.0) |
| **`vbmeta_system.img`** | 1 048 576 B | `vbmeta_system` | Sumy kontrolne dm-verity dla partycji system |
| **`vbmeta_vendor.img`** | 1 048 576 B | `vbmeta_vendor` | Sumy kontrolne dm-verity dla partycji vendor |
| **`seccfg.img`** | 1 048 576 B | `seccfg` | Konfiguracja blokady bootloadera (Orange/Green state) |
| **`sec1.img`** | 1 048 576 B | `sec1` | Flagi strefy bezpieczeństwa MTK |
| **`tszone.img`** | 1 048 576 B | `tszone` | Konfiguracja sprzętowa Topway |
| **`forfanzone.img`** | 1 048 576 B | `forfanzone` | Parametry platformy ForFan / JunCan |
| **`forfanpara.img`** | 1 048 576 B | `forfanpara` | Parametry kalibracji peryferiów |
| **`misc.img`** | 524 288 B | `misc` | Rejestr flag rozruchu (m.in. flaga "ffup") |
| **`para.img`** | 524 288 B | `para` | Flagi środowiskowe u-boot / lk |
| **`checksums.sha256`** | ~1 KB | - | Kryptograficzne sumy kontrolne SHA-256 wszystkich plików |

---

## 2. KRYTYCZNE OSTRZEŻENIE DOTYCZĄCE BEZPIECZEŃSTWA

> [!CAUTION]
> **ZASADA NR 1: W SP FLASH TOOL UŻYWAJ WYŁĄCZNIE TRYBU "Download Only"!**
> 
> **KATEGORYCZNIE ZABRANIA SIĘ** wybierania opcji **"Format All + Download"** ani **"Firmware Upgrade"**!
> Wybranie opcji "Format All" bezpowrotnie wymazuje fabryczne partycje kalibracyjne eMMC:
> - `nvram` / `nvdata` / `nvcfg`: Unikalna kalibracja radiowa, filtry antenowe, IMEI modemu 4G, adresy MAC Wi-Fi i Bluetooth.
> - `protect1` / `protect2`: Klucze licencyjne i identyfikatory bezpieczeństwa.
> - `proinfo`: Unikalny numer seryjny płyty głównej.
> - `avm`: Fabryczna kalibracja kamer 360 stopni (AVM).
> 
> W dostarczonym pliku scatter powyższe partycje kalibracyjne zostały celowo oznaczone jako `is_download: false` i `PROTECTED`, aby uniemożliwić ich przypadkowe uszkodzenie.

---

## 3. Trzy Metody Przywracania Stacji (Od Najprostszej do Ostatecznej)

### Metoda 1: Sprzętowy Flash USB Topway (Tier 2 Recovery)
*Zalecana, gdy stacja wisi na logo Topway/Junsun lub bootloopie, a bootloader LK żyje.*
1. Upewnij się, że pendrive ma format **FAT32** z jedną partycją MBR.
2. Na głównym poziomie pendrive'a (katalog główny `/`) muszą znajdować się dwa pliki:
   - `8667.bin` (fabryczny pakiet 3.9 GB)
   - `8667.upd` (plik sumy kontrolnej MD5)
3. Wepnij pendrive do **4-pinowego portu USB** w tylnej wiązce stacji (port 1).
4. Za pomocą spinacza biurowego wciśnij i przytrzymaj przycisk **RST** (otworek na przednim panelu).
5. Podłącz/włącz zasilanie 12V (BATT + ACC).
6. Trzymaj RST przez 5 sekund po pojawieniu się napięcia, po czym zwolnij.
7. LittleKernel wykryje pakiet na USB i rozpocznie automatyczne wgrywanie eMMC (zielony pasek).
8. Po komunikacie "SUCCESS - PLEASE REMOVE USB" wyjmij pendrive; stacja uruchomi się z fabrycznym systemem.

---

### Metoda 2: Przywracanie przez SP Flash Tool (MediaTek BROM / VCOM)
*Stosowana, gdy stacja ma czarny ekran, nie reaguje na przycisk RST lub bootloader został uszkodzony.*

#### Krok 2.1: Przygotowanie środowiska na PC
- **System:** Windows 10/11 lub Linux (Ubuntu/Debian).
- **Sterowniki:** MediaTek USB VCOM Drivers zainstalowane na PC.
- **Wersja SP Flash Tool:** v5.1952, v5.2124 lub v6.x (wersja Linux: `flash_tool`).

#### Krok 2.2: Konfiguracja programu
1. Uruchom SP Flash Tool jako administrator (lub `sudo ./flash_tool` na Linuxie).
2. W polu **Download-Agent** wybierz oficjalny `MTK_AllInOne_DA.bin` (znajduje się w katalogu SP Flash Tool).
3. W polu **Scatter-loading File** kliknij `Choose` i wskaż:
   `SP_FLASH_TOOL_RESTORE_TS8667/MT6768_Android_scatter.txt`.
4. Sprawdź, czy tryb rozwijany ustawiony jest na: **Download Only**.
5. Weryfikacja zaznaczonych partycji:
   - Upewnij się, że `preloader` jest **ODZNACZONY** (odznaczenie preloadera zapobiega ucegleniu układu zasilania/RAM).
   - Zaznaczone powinny być: `recovery`, `boot`, `super`, `lk`, `dtbo`, `tee1`, `tee2`, `spmfw`, `scp1`, `scp2`, `sspm_1`, `sspm_2`, `vbmeta`, `vbmeta_system`, `vbmeta_vendor`.

#### Krok 2.3: Podłączenie stacji w trybie BROM
1. Kliknij przycisk **Download** (zielona strzałka w górnej części programu). Program przejdzie w tryb oczekiwania na port COM.
2. Odłącz całkowicie zasilanie 12V od stacji radiowej.
3. Wepnij kabel USB (wiązka 4-pin lub 6-pin OTG) z tyłu radia do portu USB w komputerze.
4. Wciśnij i przytrzymaj przycisk **RST** na przednim panelu radia, a następnie podłącz zasilanie 12V (lub podłącz wtyczkę USB trzymając RST).
5. Komputer wykryje urządzenie: `MediaTek USB VCOM Port` (USB ID `0e8d:0003` lub `0e8d:2000`).
6. SP Flash Tool natychmiast rozpocznie wgrywanie:
   - Czerwony pasek: Nawiązanie komunikacji z BootROM i wysłanie agenta DA.
   - Fioletowy / żółty pasek: Formatowanie bloków i strumieniowanie obrazów na eMMC.
7. Po ukończeniu pojawi się okno z **zielonym kółkiem (Download OK)**.
8. Odłącz kabel USB i zresetuj zasilanie stacji.

---

### Metoda 3: Przywracanie za pomocą `mtkclient` (Alternatywa Open Source dla Linux)
Jeśli SP Flash Tool sprawia problemy ze sterownikami VCOM na systemie Linux:

```bash
# 1. Instalacja zależności mtkclient
sudo apt-get install python3-pip libusb-1.0-0 libusb-1.0-0-dev
pip3 install pyusb pyserial pycryptodome

# 2. Przejście do katalogu z obrazami
cd /run/media/tomasztoczek/TS8667_ROOT/SP_FLASH_TOOL_RESTORE_TS8667

# 3. Weryfikacja wykrycia radia w BROM (przytrzymaj RST i podłącz USB)
python3 -m mtk print-partition

# 4. Bezpośrednie wgranie newralgicznych partycji
python3 -m mtk write boot boot.img
python3 -m mtk write recovery recovery.img
python3 -m mtk write lk lk.img
python3 -m mtk write lk2 lk.img
python3 -m mtk write dtbo dtbo.img
python3 -m mtk write vbmeta vbmeta.img
python3 -m mtk write vbmeta_system vbmeta_system.img
python3 -m mtk write vbmeta_vendor vbmeta_vendor.img
python3 -m mtk write super super.img

# 5. Reset stacji do normalnego rozruchu
python3 -m mtk reset
```

---

## 4. Weryfikacja Integralności Plików (SHA-256)

Przed procedurą wgrania zaleca się uruchomienie weryfikacji sum kontrolnych w terminalu:

```bash
cd /run/media/tomasztoczek/TS8667_ROOT/SP_FLASH_TOOL_RESTORE_TS8667
sha256sum -c checksums.sha256
```

Wszystkie wpisy powinny zwrócić status **OK**.
