# 10. Dekompilacja MainUI i Integracja Ustawień w Stock Android Settings

> **Status:** Analiza kompletna po pełnej dekompilacji `classes.dex` i `classes2.dex` oraz deasemblacji zasobów APKTool/JADX z `MainUI.apk` (wersja `V11.1.2_20231023`).

---

## 1. Architektura `MainUI.apk`

Wbrew nazwie, `MainUI.apk` to nie tylko launcher – to **centralny demon sprzętowy stacji multimedialnej Junsun V1 Plus / Topway TS10 / MT8667**. Zawiera:
1. **Natywne biblioteki JNI:**
   - `libts67xhw.so` (381 KB) – komunikacja UART z mikrokontrolerem MCU (`/dev/ttyMT1`), sterowanie zasilaniem, radiem analogowym, fizycznymi przyciskami i podświetleniem.
   - `libcan59.so` (2.75 MB) – dekoder ramek CAN Bus dla ponad 80 marek samochodów (Raise, Hiworld, SimpleSoft, Bagoo itp.).
   - `libpymatch.so` & `libts70xicfg.so` – logika krosowania sygnałów i konfiguracji interfejsu.
2. **Kluczowe serwisy sprzętowe:**
   - `com.ts.main.common.MainService` – główny demon nasłuchujący komunikatów z MCU i CAN.
   - `com.ts.backcar.BackcarService` – automatyczne przełączanie ekranu na kamerę cofania po wykryciu biegu wstecznego (`REVERSE` pin / CAN frame).
   - `com.ts.main.cpufan.CpuTempUtilsService` – monitoring termiczny i załączanie wentylatora chłodzenia CPU.
3. **Ekrany konfiguracyjne (Activities):**
   - Ekrany ustawień fabrycznych (`com.ts.factoryset.*`)
   - Ekrany ustawień użytkownika i DSP (`com.ts.set.*`)
   - Kalibracja przycisków kierownicy (`com.ts.main.CStudy.*`)

---

## 2. Mapa Ukrytych Kodów Fabrycznych i Działań

Podczas analizy kodu `com.ts.main.common.MainSet.DealFactorySec()` oraz zasobów `res/values/strings.xml` wyekstrahowano pełną listę kodów serwisowych:

| Kod | Nazwa stałej w kodzie | Wywoływana akcja / Klasa docelowa | Opis działania |
| :--- | :--- | :--- | :--- |
| **`8878`** | `custom_fatctory_num` | `com.ts.factoryset.FsMainActivity` (`factory=true`) | **Główne pełne menu fabryczne** (bez ograniczeń) |
| **`8888`** | `custom_shop_num` | `WinShow.GotoWin(15, 0)` | Szybkie menu instalatorskie / sklepowe |
| **`7224`** | Hardcoded | `com.ts.factoryset.FsMainActivity` (`factory=true`) | Alternatywny kod dostępu do menu fabrycznego |
| **`3368`** | Hardcoded | `com.ts.factoryset.FsMainActivity` | Hasło inżynieryjne TengShi / Topway |
| **`1617`** | `custom_usbwait_id_num` | `com.ts.main.auth.FactoryMainActivity` | **Przełączenie portu USB w tryb ADB Device** |
| **`4848`** | `custom_open_system_setting_num`| `com.android.settings` | Bezpośrednie otwarcie czystych ustawień Androida |
| **`4949`** | `custom_open_filemange` | `com.ts.filemanager` | Otwarcie menedżera plików |
| **`0129`** | `custom_can_data_num` | `startCanDataService()` | **Sniffer / Monitor surowych ramek CAN w czasie rzeczywistym** |
| **`0127`** | `custom_can_keystudy_num`| `com.ts.can.CanCarInfoSub3Activity` | Zaawansowane uczenie przycisków cyfrowych z magistrali CAN |
| **`0128`** | `custom_can_update_num` | `com.ts.can.CanAllUpdateActivity` | Aktualizacja oprogramowania układowego modułu CAN Box |
| **`1414`** | `custom_reboot_id_num` | `PowerManager.reboot()` | Natychmiastowy restart stacji |
| **`1313`** | `custom_radio_reset_num`| `FtSet.ResetRadio()` | Reset układu scalonego tunera radiowego AM/FM |
| **`123`** | `custom_check_dsp_secret`| `Iop.GetDspVer()` | Wyświetlenie dokładnej wersji procesora DSP |
| **`1101`** | `custom_screenshot_num` | Toggle screenshot trigger | Włączenie/wyłączenie trybu zrzutów ekranu |
| **`1102`** | `custom_touchtest_num` | `com.ts.touchcheck` | Tryb kalibracji i testu wielodotyku panelu |
| **`1103`** | `custom_screen_adjust_num`| `com.ts.screentest.MainActivity` | Kalibracja parametrów matrycy LCD / LVDS |
| **`6666`** | `custom_fatctory_exprort_num`| `com.ts.factoryset.FsMPModeActivity` | Eksport / Import profilu fabrycznego na USB |
| **`2648`** | `custom_systemclear_pwd`| `MainSet.SystemClear()` | Pełny reset fabryczny stacji |
| **`9090`** / **`9191`** | `custom_destroy_id_*` | Usunięcie licencji / certyfikatów autoryzacji | Niszczenie kluczy aktywacyjnych producenta |
| **`1314214`** | Sekwencja dotknięć | `SettingEquipmentActivity` -> `FsMainActivity` | Ukryty backdoor dotykowy w ekranie "O urządzeniu" |

---

## 3. Kluczowe Ekrany Ustawień Auta i Parametry

Wszystkie parametry konfiguracyjne pojazdu są zapisywane do pamięci mikrokontrolera lub partycji NVRAM za pośrednictwem natywnych wywołań klasy `com.yyw.ts70xhw.FtSet`:

### A. Kamera Cofania i Parkowanie (`com.ts.factoryset.FsBackCarSetActivity`)
- **Format sygnału wideo (`FtSet.SetCamSUBfmt`):**
  - `1`: CVBS NTSC
  - `2`: CVBS PAL
  - `3`: AHD 720P 25fps
  - `4`: AHD 720P 30fps
  - `5`: AHD 1080P 25fps
  - `6`: AHD 1080P 30fps
  - `7`: TVI 720P / 1080P
- **Linie pomocnicze (`FtSet.SetLineType`, `FtSet.SetLinePos`):** statyczne, dynamiczne (skrętne z czujnika kąta kierownicy CAN) lub wyłączone.
- **Wyciszanie audio przy cofaniu (`FtSet.SetParkMuteDef`):** 0 = bez wyciszenia, 1 = -10dB, 2 = wyciszenie całkowite.
- **Lustro kamery przedniej / tylnej (`FtSet.SetCamMir`, `FtSet.SetFcamMir`):** odbicie lustrzane obrazu w poziomie.

### B. Sterowanie z Kierownicy – SWC (`com.ts.main.CStudy.CStudyMainActivity`)
- Uczenie klawiszy rezystancyjnych (KEY1 / KEY2) podłączonych bezpośrednio do wiązki ISO.
- Obsługuje 32 komendy: `GŁOŚNOŚĆ +`, `GŁOŚNOŚĆ -`, `MUTE`, `NASTĘPNY`, `POPRZEDNI`, `ODBIERZ`, `ODRZUĆ`, `NAWIGACJA`, `MODE`, `HOME`, `GŁOS / ASYSTENT`.

### C. Magistrala CAN Bus (`com.ts.factoryset.FsCanActivity`)
- Konfiguracja producenta modułu CAN (SimpleSoft, Raise, Hiworld, Bagoo, OUDI, Xinpu itp.).
- Wybór marki, modelu oraz rocznika samochodu.
- Ustawienia wyświetlania stanu klimatyzacji (Climatronic overlay), czujników parkowania (PDC radar) oraz otwarcia drzwi.

### D. Procesor Dźwięku DSP (`com.ts.set.dsp.SetDspMainActivity`)
- 32-pasmowy korektor graficzny (EQ) z niezależną regulacją częstotliwości i dobroci Q.
- Pole dźwiękowe i opóźnienia czasowe (Time Alignment / Emperor Delay) w milisekundach/centymetrach dla każdego głośnika.
- Filtr dolnoprzepustowy (LPF) i górnoprzepustowy (HPF) dla subwoofera.
- Wzmocnienie dynamiki basu (Smart Bass Boost).

### E. Chłodzenie i Wentylator CPU (`com.ts.main.cpufan.ElectricFanActivity`)
- Próg załączania wentylatora chłodzenia CPU: od 60°C do 80°C (rekomendowane: 60°C).
- Tryb pracy: automatyczny wg temperatury (`FtSet.SetFanEn`) lub manualny test.

---

## 4. Koncepcja Integracji w Czyste Ustawienia Androida (AOSP Settings)

Zamiast zmuszać użytkownika do szukania ukrytych aplikacji czy wpisywania kodów 8878/8888, integrujemy dedykowaną sekcję **"Ustawienia Samochodu"** bezpośrednio w główny interfejs Android Settings (`com.android.settings`).

### Architektura Rozwiązania: `CarSettingsBridge`
Wykorzystujemy natywny dla Androida mechanizm **Dynamic Dashboard Category** (`com.android.settings.category.ia.homepage`).

```
                    ┌──────────────────────────────────────────────┐
                    │          Stock AOSP Settings.apk             │
                    │       (Główne Ustawienia Androida)           │
                    └──────────────────────┬───────────────────────┘
                                           │ Dynamic Tile Injection
                                           ▼
             ┌───────────────────────────────────────────────────────────┐
             │       "Ustawienia Samochodu" (Car Settings)               │
             │           com.topway.carsettingsbridge                    │
             └─────────────────────────────┬─────────────────────────────┘
                                           │
         ┌───────────────────┬─────────────┴───────┬─────────────────────┐
         ▼                   ▼                     ▼                     ▼
┌─────────────────┐ ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Kamera Cofania  │ │ Przyciski Kier. │  │ Procesor DSP     │  │ Konfiguracja CAN │
│  & Parkowanie   │ │  (SWC Learning) │  │  (32-Band EQ)    │  │  (Protokół/Auto) │
│FsBackCarSetAct. │ │CStudyMainAct.   │  │SetDspMainActivity│  │  FsCanActivity   │
└─────────────────┘ └─────────────────┘  └──────────────────┘  └──────────────────┘
         │                   │                     │                     │
         └───────────────────┴─────────────┬───────┴─────────────────────┘
                                           ▼
                             ┌───────────────────────────┐
                             │        libts67xhw.so      │
                             │  Mikrokontroler MCU (UART)│
                             └───────────────────────────┘
```

### Kod manifestu mostka (`CarSettingsBridge`):
```xml
<activity
    android:name=".CarSettingsMainActivity"
    android:icon="@drawable/ic_car_settings"
    android:label="@string/car_settings_title"
    android:theme="@style/Theme.SubSettings"
    android:exported="true">
    <intent-filter>
        <action android:name="com.android.settings.action.SETTINGS_EXTENDED" />
        <category android:name="com.android.settings.category.ia.homepage" />
    </intent-filter>
    <meta-data
        android:name="com.android.settings.category"
        android:value="com.android.settings.category.ia.homepage" />
    <meta-data
        android:name="com.android.settings.title"
        android:value="@string/car_settings_title" />
    <meta-data
        android:name="com.android.settings.summary"
        android:value="@string/car_settings_summary" />
    <meta-data
        android:name="com.android.settings.icon"
        android:resource="@drawable/ic_car_settings" />
    <meta-data
        android:name="com.android.settings.order"
        android:value="-50" />
</activity>
```

Gdy użytkownik otworzy **Ustawienia**, kafelek **Ustawienia Samochodu** pojawia się bezpośrednio pod ustawieniami Sieci i Wyświetlacza. Po kliknięciu otrzymuje czytelne podmenu z kafelkami:
1. **Kamera cofania i parkowanie** -> Otwiera bezpośrednio `com.ts.factoryset.FsBackCarSetActivity`.
2. **Przyciski kierownicy (SWC)** -> Otwiera `com.ts.main.CStudy.CStudyMainActivity`.
3. **Konfiguracja magistrali CAN Bus** -> Otwiera `com.ts.factoryset.FsCanActivity`.
4. **Korektor dźwięku & Procesor DSP** -> Otwiera `com.ts.set.dsp.SetDspMainActivity`.
5. **Podświetlenie przycisków RGB** -> Otwiera `com.ts.set.SetColorKeyMainActivity`.
6. **Wentylator procesora** -> Otwiera `com.ts.main.cpufan.ElectricFanActivity`.
7. **Zaawansowane menu fabryczne** -> Otwiera `com.ts.factoryset.FsMainActivity` z flagą `factory=true` (bez pytania o kod PIN!).

---

## 5. Matryca Retencji i Odchudzania Aplikacji (De-bloat Matrix)

Zgodnie z wymaganiami projektu budujemy ultralekki, responsywny system z zachowaniem kluczowych peryferiów:

| Komponent / Aplikacja | Pakiet / Ścieżka | Decyzja | Uzasadnienie |
| :--- | :--- | :--- | :--- |
| **DUDU-OS Launcher** | `com.autonavi.dudu` | **DODAJ (Domyślny)** | Nowoczesny, stabilny ekran główny w landscape 1280x720 z integracją map i widgetów. |
| **Wideorejestrator (DVR)** | `com.ankai.cardvr` (`CarDVR.apk`) | **ZACHOWAJ** | Obsługa przedniej kamery USB/MIPI rejestratora jazdy Ankai. |
| **Czujniki ciśnienia (TPMS)**| `com.ts.main.tpms` / `MainUI.apk` | **ZACHOWAJ** | Monitoring ciśnienia i temperatury opon (zarówno USB TPMS jak i CAN TPMS). |
| **Odtwarzacz DVD USB** | `DvdBox.apk` (`/vendor/app/DvdBox/`) | **ZACHOWAJ** | Obsługa zewnętrznego napędu DVD USB. |
| **Google Mobile Services** | GMS Core, Chrome, Maps, YT | **ODCHUDŹ / OPCJA** | Zastąpienie fabrycznego bloatware przez **MicroG** (zalecane: ~30MB RAM) lub opcjonalną paczkę **NikGapps Core** (tylko Play Store + Play Services) do wyboru przez TWRP. |
| **Stock CarPlay / Android Auto**| `sd_carplay`, `CarLetter`, `EasyConnect`| **USUŃ** | Przestarzałe, chińskie rozwiązania powodujące konflikty. Użytkownik instaluje nowoczesny **DiPlay** lub AutoKit. |
| **Stock Launchery Juncani** | `8259TsLauncher2_*` (`/vendor/tsoem/`) | **USUŃ** | Zastąpione w 100% przez DUDU-OS Launcher. |
| **Telemetria i Chińskie Usługi**| `txz`, `cpe_agent`, `cservice`, `ximalaya` | **USUŃ** | Naruszenie prywatności, obciążenie CPU, zbędne procesy w tle. |
| **MainUI (Headless Hardware Daemon)**| `MainUI.apk` | **ZACHOWAJ / PRZEKROUJ** | Usunięto zbędne odtwarzacze wideo/muzyki, pozostawiono serwis sprzętowy MCU, CAN i aktywności konfiguracyjne. |
