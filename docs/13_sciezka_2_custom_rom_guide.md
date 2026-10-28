# Chapter 13: Przewodnik Wdrożenia Custom ROM - Ścieżka 2 (Topway TS8667)

Kompleksowa dokumentacja instalacji, architektury i konfiguracji zoptymalizowanego hybrydowego Custom ROM-u (**Ścieżka 2**) dla stacji multimedialnej **Topway TS8667 / Junsun V1 Plus (MediaTek Helio P65 MT6768, MCU: G6-TS)**.

---

## 1. Czym jest Ścieżka 2 (Hybrydowy Custom ROM)?

Wybór **Ścieżki 2** to wdrożenie nowoczesnego, bezpiecznego i w 100% zintegrowanego z autem środowiska systemowego:
1. **Stabilny, przetestowany fundament:**
   - Wykorzystuje oficjalne jądro Linux 4.14 i certyfikowane sterowniki MediaTek MT6768 (VNDK 29).
   - Zero problemów ze sterownikami Wi-Fi MT6631, Bluetooth, dotykiem Goodix czy akceleracją Mali-G52 GPU.
2. **Całkowity debloating (Usunięcie chińskiego oprogramowania szpiegującego):**
   - Usunięto telemetryczne daemony: `cpe_agent`, `txz`, `cservice`, `TsActivateCarDev`.
   - Usunięto nieużywane chińskie serwisy: `ximalaya`, `autonavi`, `radio_topway_online`.
   - Usunięto przestarzały, zbugowany moduł CarPlay: `sd_carplay`, `CarLetter`, `EasyConnect`.
   - Zlikwidowano podatność fabryczną backdoor shella `ffsu` (zastąpionego oficjalnym Magisk v27).
3. **Nowoczesna warstwa UX (DUDU-OS + Car Settings Bridge):**
   - **DUDU Launcher Global (wersja z podpisem systemowym Public Topway):** Daje nowoczesny pulpit w stylu Tesla / PiP (Picture-in-Picture) z płynną mapą na żywo (Google Maps, Waze) i kafelkami multimediów.
   - **Car Settings Bridge:** Dedykowany mostek ustawień fabrycznych i magistrali CAN.
   - **Open Headunit:** Alternatywny, otwarty klient Android Auto.
   - **Viper4Android FX v8.0:** Profesjonalny silnik korekcji akustycznej wnętrza współpracujący z procesorem DSP ROHM BD3702FV.
   - **MicroG (GmsCore + FakeStore):** Ultralekkie usługi Google (zamiast ciężkich 500MB GApps).

---

## 2. Dlaczego ta metoda jest w 100% BEZPIECZNA (Anti-Brick)?

Zastosowaliśmy technologię **Magisk Systemless Magic Mount**:
- **Brak naruszania fizycznej partycji `super.img` na eMMC:**
  Pliki na partycji logicznej `system` pozostają nienaruszone na poziomie bitów.
- **Dynamiczne nakładanie warstwy (Overlay):**
  Magisk montuje puste katalogi w miejscach chińskich aplikacji (całkowicie je ukrywając) oraz wstrzykuje nowe aplikacje do `/system/priv-app/` w trakcie startu jądra (przed startem Zygote i frameworku Androida).
- **100% Odwracalność:**
  Jeśli z jakiegokolwiek powodu zechcesz powrócić do stanu fabrycznego, wystarczy wyłączyć moduł w aplikacji Magisk lub usunąć katalog `/data/adb/modules/ts8667-custom-os` w TWRP.

---

## 3. Zachowanie Krytycznych Funkcji Pojazdu

| Funkcja pojazdu | Stan w Ścieżce 2 | Sposób realizacji |
|---|---|---|
| **Przyciski z kierownicy (SWC / CAN)** | **DZIAŁA (100%)** | `MainService` z `MainUI.apk` działa w tle na porcie `/dev/ttyMT1`. Kalibrator rezystancyjny `CStudy` jest zachowany. |
| **Kamera cofania / Panoramiczna 360°** | **DZIAŁA (100%)** | Zachowano moduły `AVM2.apk` i sterownik układu Techpoint TP2850. Wrzucenie biegu wstecznego natychmiast wyzwala obraz z kamer. |
| **Dźwięk & Korektor DSP (ROHM BD3702FV)** | **ULEPSZONY (150%)** | MTK Audio HAL przesyła strumień, a Viper4Android FX oraz fabryczny mikser I2C pozwalają na pełną kontrolę tonów i subwoofera. |
| **Aktywne chłodzenie (Wiatrak CPU)** | **CHRONIONE (100%)** | Równoległy demon w `service.sh` monitoruje `/sys/class/thermal/thermal_zone0/temp` i załącza wiatrak PWM przy temp > 52°C i 65°C. |
| **Ekran i rozdzielczość** | **1280x720 Landscape** | `system.prop` wymusza `ro.sf.hwrotation=0` oraz usuwa fałszywe oznaczenia wersji Androida (`ro.forfan.version.release=10`). |

---

## 4. Zawartość Pakietu (Folder `08_SCIEZKA_2_CUSTOM_ROM`)

```
08_SCIEZKA_2_CUSTOM_ROM/
├── TS8667_Custom_OS_Sciezka2_Full.zip   (Główny moduł: DUDU, Car Bridge, ViperFX, MicroG, Android Auto)
├── TS8667_Custom_OS_Sciezka2_Lite.zip   (Wersja lekka: DUDU, Car Bridge, ViperFX - bez usług Google)
├── APKI_DO_RECZNEJ_INSTALACJI/
│   ├── DuduAutoUiGlobalAs_Public_Topway.apk (Wersja z podpisem Public - obsługa PIP na Topway)
│   ├── DuduAutoUiGlobal_Private_Fallback.apk (Wersja uniwersalna)
│   ├── CarSettingsBridge.apk                (Nasz mostek ustawień pojazdu)
│   ├── ViperFX_v8.0.apk                     (Panel dźwięku Viper4Android)
│   ├── MicroG_GmsCore.apk                   (Silnik MicroG)
│   ├── MicroG_FakeStore.apk                 (Sklep FakeStore)
│   └── OpenHeadunit_AndroidAuto.apk         (Klient Android Auto)
├── SKRYPTY_INSTALACJI/
│   ├── install_custom_os_live.sh            (Instalator uruchamiany z roota w działającym systemie)
│   ├── install_custom_os_twrp.sh            (Instalator uruchamiany w TWRP)
│   └── uninstall_custom_os.sh               (Skrypt przywracania stanu fabrycznego)
└── INSTRUKCJA_SCIEZKA_2.txt
```

---

## 5. Instrukcja Instalacji Krok po Kroku

### Krok 0: Wymagania wstępne
1. Stacja ma odblokowany bootloader (Orange State).
2. Zrootowałeś stację za pomocą naszego spatchowanego obrazu `boot_magisk_patched.img` (zgodnie z `INSTRUKCJA_PL.txt`).
3. W systemie działa aplikacja **Magisk v27.0**.

---

### Metoda A: Instalacja z poziomu aplikacji Magisk (Najwygodniejsza)
1. Włóż pendrive do portu USB w stacji multimedialnej.
2. Otwórz aplikację **Magisk**.
3. Przejdź do zakładki **Moduły** (ikona puzzla w dolnym prawym rogu).
4. Kliknij **Zainstaluj z pamięci podręcznej** (Install from storage).
5. Wybierz pendrive i wskaż plik:
   `08_SCIEZKA_2_CUSTOM_ROM/TS8667_Custom_OS_Sciezka2_Full.zip`
6. Magisk automatycznie:
   - Rozpakuje DUDU-OS Launcher i Car Settings Bridge,
   - Zaaplikuje systemless debloat (ukrycie chińskiego bloatware),
   - Ustawi właściwości orientacji i audio.
7. Po zakończeniu kliknij **Uruchom ponownie** (Reboot).

---

### Metoda B: Instalacja przez TWRP Recovery
1. Uruchom TWRP Recovery (np. przez naszą aplikację `TS8667_Root_TWRP_Flasher.apk` lub przez 4 palce na ekranie).
2. Wybierz opcję **Install**.
3. Wybierz pamięć **Select Storage -> USB OTG**.
4. Wskaż katalog `08_SCIEZKA_2_CUSTOM_ROM` i plik `TS8667_Custom_OS_Sciezka2_Full.zip`.
5. Przesuń suwak **Swipe to confirm Flash**.
6. Wybierz **Reboot System**.

---

### Metoda C: Instalacja przez Terminal / ADB Shell
Wystarczy wykonać na zrootowanej stacji:
```bash
su
sh /sdcard/TS8667_ROOT/08_SCIEZKA_2_CUSTOM_ROM/SKRYPTY_INSTALACJI/install_custom_os_live.sh
reboot
```

---

## 6. Procedura Awaryjna (Cofnięcie Zmian)
Jeśli chcesz natychmiast wrócić do czystego fabrycznego launchera Topway:
1. W aplikacji Magisk przejdź do zakładki **Moduły** i odznacz lub usuń moduł `Topway TS8667 Modern Automotive OS`.
2. Zrestartuj stację.
3. System uruchomi się w 100% fabrycznej postaci.
