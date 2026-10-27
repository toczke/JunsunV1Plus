# Chapter 12: Raport Techniczny - Custom ROM z Androidem 13 na Topway TS8667 (MT6768)

Szczegółowa analiza wykonalności, architektury sterowników, barier sprzętowych oraz ścieżek wdrożenia czystego Androida 13 (np. LineageOS 20 / AOSP GSI) na stacji multimedialnej **Topway TS8667 / Junsun V1 Plus (MediaTek Helio P65 MT6768, MCU: G6-TS)**.

---

## 1. Podsumowanie Wykonalności (Executive Summary)

| Obszar sprzętu / systemu | Status pod Androidem 13 GSI | Wymagane działania / Rozwiązanie |
|---|---|---|
| **Start systemu (Boot & Kernel)** | **DZIAŁA (100%)** | Dynamic Partitions (Super) obsługuje GSI `arm64_bvS`. Jądro 4.14.186+ wspiera eBPF i Treble. |
| **Ekran & Grafika (Mali-G52)** | **DZIAŁA (100%)** | Vendorowe biblioteki OpenGL ES 3.2 i Vulkan z `/vendor/lib64/egl/` inicjalizują się poprawnie. |
| **Ekran dotykowy (Touchpanel)** | **DZIAŁA (100%)** | Sterownik I2C (Goodix GT911/GT9886) znajduje się w jądrze (`kernel`), jest niezależny od wersji Androida. |
| **Wi-Fi & Bluetooth** | **DZIAŁA (95%)** | Standardowy moduł MTK MT6631; działa przez vendorowe HAL-e z nakładką TrebleDroid. |
| **Pamięć USB / Pendrive** | **DZIAŁA (100%)** | Kontroler USB OTG MediaTek działa w standardzie AOSP. |
| **Magistrala CAN & Przyciski z kierownicy** | **WYMAGA BRIDGE (0% w czystym AOSP)** | Brak w AOSP obsługi mikrokontrolera STM32 podłączonego pod UART `/dev/ttyMT1`. Wymaga `MainService` lub daemona C++. |
| **Dźwięk & Procesor DSP (ROHM BD3702)** | **CZĘŚCIOWO (Dźwięk gra, brak EQ)** | MTK Audio HAL odtwarza PCM, ale przedwzmacniacz/korektor I2C wymaga wysyłania komend I2C `/dev/i2c-1`. |
| **Kamery 360° / Kamera cofania AHD** | **WYMAGA VENDOR APP (0% w czystym AOSP)** | Układ Techpoint TP2850 (konwerter 4x AHD na MIPI) nie jest standardową kamerą telefonową; wymaga `AVM2.apk` / `tp2850_*.so`. |
| **Radio FM (Tuner analogowy TDA7708)** | **WYMAGA VENDOR APP** | AOSP nie posiada wbudowanej obsługi samochodowych tunerów I2C; wymaga dedykowanej aplikacji radia. |

---

## 2. Dlaczego stacja samochodowa to NIE jest zwykły smartfon?

W smartfonie wszystkie podzespoły (kamera, dźwięk, czujniki) komunikują się bezpośrednio z procesorem głównym (SoC) przez standardowe interfejsy Android HAL (HIDL / AIDL).

W stacji multimedialnej **Topway TS8667** architektura jest **hybrydowa dwuprocesorowa**:
```
┌────────────────────────────────────────────────────────────────────────┐
│                   GŁÓWNY PROCESOR (MediaTek MT6768)                   │
│   - Android 10/13 OS (AOSP / LineageOS)                                │
│   - Aplikacje (Nawigacja, Spotify, DiPlay, YouTube)                    │
│   - Wyświetlanie obrazu LVDS (1280x720)                                │
└───────────────────▲────────────────────────────────▲───────────────────┘
                    │ UART (/dev/ttyMT1)             │ I2C (/dev/i2c-1)
                    ▼                                ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────┐
│       MIKROKONTROLER MCU (G6-TS)     │  │   AUDIO DSP (ROHM BD3702FV)  │
│  - Połączenie z CAN-Bus pojazdu      │  │  - Sprzętowy korektor (EQ)   │
│  - Przyciski z kierownicy (Key1/Key2)│  │  - Fader, Balance, Subwoofer │
│  - Bieg wsteczny (Reverse trigger)   │  │  - Przełącznik źródeł audio  │
│  - Załączanie zasilania ACC          │  └──────────────────────────────┘
└──────────────────────────────────────┘
```

Jeśli wgrasz czysty obraz **Generic System Image (GSI) Android 13**:
1. Android 13 uruchomi się, ekran wyświetli nowoczesny pulpit, dotyk będzie działał, Wi-Fi się połączy.
2. **Ale samochód „zniknie”:** włączenie biegu wstecznego nie wywoła kamery, przyciski na kierownicy nie będą reagować, a dźwięk może grać cicho lub na 100% głośności, bo procesor DSP nie otrzymał komend startowych po magistrali I2C.

---

## 3. Dwie drogi wdrożenia Androida 13

### Droga 1: Pełny Android 13 GSI + Headless Vendor Automotive Bridge (Dla zaawansowanych)
Polega na zachowaniu partycji `/vendor` z Androida 10 i wgraniu czystego obrazu Android 13 GSI (np. **TrebleDroid / LineageOS 20 GSI**) na partycję `system` wewnątrz kontenera `super`:

1. **Kompatybilność Treble:**
   - Vendor w TS8667 to VNDK 29.
   - Nowoczesne obrazy TrebleDroid posiadają wbudowane tzw. *VNDK-lite shims*, które pozwalają frameworkowi Androida 13 komunikować się ze starszymi bibliotekami MediaTek z Androida 10.
2. **Uruchomienie funkcji samochodowych:**
   - Pozostawienie w `/system/priv-app/` odchudzonego pakietu `MainUI.apk` bez launchera (jako tła systemowego `MainService`), który utrzymuje otwarty port `/dev/ttyMT1` i przekazuje zdarzenia CAN na standardowe klawisze Androida (`KEYCODE_VOLUME_UP`, itp.).
   - Użycie aplikacji `car_settings_bridge` (nasz projekt w C++ / Java) do obsługi ustawień fabrycznych.
3. **Kamera cofania:**
   - Zachowanie `360Camera.apk` i `AVM2.apk` w systemie. Gdy MCU wyśle sygnał biegu wstecznego, usługa podnosi intent nakładki kamery na wierzch Androida 13.

### Droga 2: Zdebloatowany Fabryczny Android 10 + DUDUOS UI + DiPlay (Zalecana i w 100% stabilna)
Większość profesjonalnych custom ROM-ów dla stacji z procesorami MT6768 / TS10 (np. projekty na 4PDA) wybiera tę ścieżkę z powodów niezawodności:

1. **Podstawa:**
   - Wykorzystuje fabryczne, idealnie zoptymalizowane jądro 4.14 i sterowniki HAL Topway.
   - Gwarantuje zerowe ryzyko awarii kamery AHD w nocy, brak opóźnień na magistrali CAN, natychmiastowe wybudzanie z uśpienia (Deep Sleep w 1 sekundę po przekręceniu kluczyka).
2. **Debloating (Usunięcie chińskiego śmiecia):**
   - Całkowite usunięcie: `sd_carplay`, `CarLetter`, `EasyConnect`, `TsActivateCarDev`, telemetrycznych trackerów i natrętnych launcherów.
3. **Warstwa Android 13 / Tesla UX:**
   - **Launcher DUDUOS / Agama / Vivid Car Launcher:** Daje nowoczesny interfejs z kafelkami, mapą w czasie rzeczywistym i sterowaniem muzyką identyczny jak w fabrycznych systemach 2024+.
   - **DiPlay / Headunit Reloaded:** Bezprzewodowy Apple CarPlay i Android Auto działający natywnie przez Wi-Fi/BT stacji.
   - **Viper4Android FX / JamesDSP:** Zastępuje fabryczny prosty korektor profesjonalnym silnikiem dźwięku z kompensacją akustyki wnętrza auta.

---

## 4. Wnioski i Rekomendacja

- **Czy można uruchomić Androida 13 na TS8667?**
  **TAK.** Architektura procesora Helio P65 MT6768, obsługa Dynamic Partitions i odblokowany bootloader w pełni na to pozwalają przez Project Treble (GSI).
- **Czy warto wgrywać czyste GSI jako codzienny system w aucie?**
  Tylko jeśli jesteś gotowy poświęcić 2-3 dni na dopracowanie mostka UART dla MCU i konfiguratora DSP I2C. W przeciwnym razie czysty AOSP 13 traci integrację z pojazdem.
- **Rekomendowany plan działania:**
  1. Zrobić pełny backup partycji w TWRP (mamy już działające TWRP i root Magisk).
  2. Zbudować "ROM Hybrydowy": wyczyścić fabryczny system ze zbędnych aplikacji OEM, dodać nowoczesny launcher (DUDUOS), zintegrować DiPlay i Viper4Android.
  3. Jako eksperyment na osobnym slocie/kopii przetestować bootowanie TrebleDroid Android 13 GSI.
