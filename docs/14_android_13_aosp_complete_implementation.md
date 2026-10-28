# Chapter 14: Czysty Android 13 AOSP na Topway TS8667 - Pełna Implementacja

Kompleksowa dokumentacja architektury, sterowników sprzętowych, natywnego mostka mikrokontrolera (`ts_mcu_daemon`), inicjalizatora audio DSP (`bd3702_init`) oraz procedury instalacji **czystego Androida 13 (AOSP 13.0 API 33)** na stacji multimedialnej **Topway TS8667 / Junsun V1 Plus (MediaTek Helio P65 MT6768, MCU: G6-TS)**.

---

## 1. Architektura Systemu: Czysty AOSP 13 + Natywny Mostek Automotive

W odróżnieniu od wcześniejszej koncepcji opartej na modyfikowanym systemie fabrycznym, to wdrożenie instaluje **w 100% czysty Generic System Image (GSI) Android 13.0 (Tiramisu, API 33)** bezpośrednio na partycję logiczną `system` wewnątrz kontenera `super`:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CZYSTY ANDROID 13 AOSP (API 33)                     │
│  - TrebleDroid AOSP 13.0 v2023.09.19 (Vanilla, brak zbędnych apek)     │
│  - Czysty interfejs AOSP Launcher / Quickstep / Dowolny Car Launcher    │
│  - Nowoczesny stos Android 13 MediaRouter & AudioFlinger               │
└───────────────────▲────────────────────────────────▲───────────────────┘
                    │                                │
    Linux /dev/uinput virtual keys                   │ Linux I2C (/dev/i2c-1)
                    │                                │
┌───────────────────┴──────────────────┐  ┌──────────┴───────────────────┐
│        ts_mcu_daemon (C++)           │  │       bd3702_init (C)        │
│  - Otwiera /dev/ttyMT1 @ 115200 baud │  │  - Konfiguracja ROHM BD3702FV│
│  - Dekoduje ramki Topway 0x2E        │  │  - Odciszenie (Unmute) Audio │
│  - Przyciski kierownicy (SWC)        │  │  - Wejście: MTK DAC (A_DIFF) │
│  - Bieg wsteczny (Reverse broadcast) │  │  - Płaski equalizer (Flat EQ)│
│  - Światła ILLUM -> Tryb ciemny/jasny│  │  - Fader i Balance na 0 dB   │
└──────────────────────────────────────┘  └──────────────────────────────┘
```

---

## 2. Zbudowane Komponenty Sprzętowe (ARM64 Statyczne)

Wszystkie demony zostały skompilowane jako **stacjonarne 64-bitowe binaria ARM64 (ELF 64-bit LSB static-pie)**, co uniezależnia je od wersji biblioteki C (bionic/musl) i gwarantuje stabilne działanie pod każdym jądrem Linux 4.14+:

### 2.1 `ts_mcu_daemon` (Natywny Demon MCU & Magistrali CAN)
- **Lokalizacja:** `android13_aosp/mcu_daemon/ts_mcu_daemon` (67 KB)
- **Rola:**
  1. Komunikuje się z mikrokontrolerem STM32/GD32 przez `/dev/ttyMT1` (115200 baud, 8N1).
  2. Tworzy wirtualne urządzenie wejściowe Linux `/dev/uinput` pod nazwą *"Topway TS8667 Automotive SWC"*.
  3. Przekazuje kody klawiszy z kierownicy bezpośrednio do jądra Linuksa:
     - Głośniej / Ciszej (`KEY_VOLUMEUP` / `KEY_VOLUMEDOWN`)
     - Następny / Poprzedni utwór (`KEY_NEXTSONG` / `KEY_PREVIOUSSONG`)
     - Wyciszenie (`KEY_MUTE`)
     - Play / Pause (`KEY_PLAYPAUSE`)
     - Telefon Odbierz / Odrzuć (`KEY_PHONE` / `KEY_HANGUP_PHONE`)
     - Asystent głosowy (`KEY_VOICECOMMAND`)
  4. Wykrywa bieg wsteczny (Reverse Gear) i emituje broadcast systemowy:
     `am broadcast -a android.intent.action.BACKCAR_SERVICE --ez status true/false`
  5. Wykrywa załączenie świateł (przewód ILLUM / CAN) i automatycznie przełącza motyw Androida 13 (Day / Night mode):
     `cmd uimode night yes/no`

### 2.2 `bd3702_init` (Inicjalizator Przedwzmacniacza & Korektora DSP)
- **Lokalizacja:** `android13_aosp/dsp_audio/bd3702_init` (67 KB)
- **Rola:**
  Czysty Android 13 nie posiada wbudowanego sterownika dla samochodowego procesora dźwięku **ROHM BD3702FV** znajdującego się na magistrali `/dev/i2c-1` (adres `0x40`).
  Program przy starcie systemu wysyła sekwencję rejestrów:
  - Rejestr `0x01`: Wybór wejścia różnicowego z DAC procesora MediaTek (`A_DIFF`).
  - Rejestr `0x20`: Główna głośność master (`-6 dB`).
  - Rejestry `0x28 - 0x2C`: Fader głośników przód/tył/subwoofer na `0 dB`.
  - Rejestry `0x05 - 0x07`: Płaska charakterystyka tonów niskich, średnich i wysokich.
  Dzięki temu dźwięk w Androidzie 13 od razu gra głośno i czysto.

### 2.3 `fan_governor` (Bezpiecznik Termiczny Chłodzenia CPU)
- **Lokalizacja:** `android13_aosp/thermal/fan_governor` (66 KB)
- **Rola:**
  Odpytuje co 5 sekund czujnik temperatury złącza procesora Helio P65 (`/sys/class/thermal/thermal_zone0/temp`).
  Steruje wentylatorem PWM (`/sys/class/leds/fan/brightness`):
  - Temp < 45°C: Wentylator wyłączony (cisza).
  - Temp 45°C - 52°C: Obroty ciche (~35% PWM).
  - Temp 52°C - 65°C: Obroty średnie (~60% PWM).
  - Temp > 65°C: Obroty maksymalne (100% PWM, ochrona przed throttlingiem).

---

## 3. Specyfikacja Obrazu Android 13 GSI

- **Plik źródłowy:** `aosp-arm64-ab-vanilla-13.0-20230919.img` (1,932,656,640 bajtów = 1.8 GB).
- **Format:** Czysty ext4 raw image (sparse-free).
- **Zgodność z partycją:** Mieści się w całości na fabrycznej partycji `system` w kontenerze `super` (która ma 2.1 GB, więc zostaje ponad 300 MB wolnego miejsca).
- **Wersja VNDK:** VNDK 29 (Android 10 Vendor mediaTek z automatycznymi shimami TrebleDroid).

---

## 4. Metody Wgrania Czystego Androida 13

### Metoda 1 (ZALECANA / STANDARD BRANŻOWY): Jednolita Flashowalna Paczka ZIP w TWRP (All-in-One)
Idąc wzorem oficjalnych custom ROM-ów (LineageOS, PixelExperience, crDroid), stworzyliśmy kompletną, gotową paczkę flashowalną w TWRP:
- **Plik:** `AOSP13-TS8667-CustomROM-20261028-UNOFFICIAL.zip` (871 MB)
- **Co robi skrypt `update-binary` wewnątrz zipa:**
  1. Strumieniuje obraz `system.img` (AOSP 13) bezpośrednio do logicznego wolumenu `/dev/block/mapper/system`.
  2. Montuje nowy system i automatycznie kopiuje do `/system/bin/` natywne binaria: `ts_mcu_daemon`, `bd3702_init`, `fan_governor` oraz skrypt startowy `ts_automotive_init.sh`.
  3. Konfiguruje usługę startową `ts_automotive.rc` i podpina hook do `phh-on-boot.sh`.
  4. Wymusza właściwości ekranu poziomego `ro.sf.hwrotation=0` (1280x720).
  5. Czyści pamięć podręczną i zamyka instalację.

**Instrukcja instalacji w TWRP:**
1. W TWRP wejdź w: **Install**.
2. Wybierz pamięć **Select Storage: USB OTG**.
3. Wskaż plik: `AOSP13-TS8667-CustomROM-20261028-UNOFFICIAL.zip`.
4. Przesuń suwak: **Swipe to confirm Flash**.
5. Po zakończeniu wykonaj: **Wipe -> Format Data** (wpisz `yes`).
6. Kliknij: **Reboot System**.

---

### Metoda 2: Ręczne Wgranie Obrazu IMG w TWRP (Install Image)
Jeśli wolisz wgrywać sam surowy obraz:
1. W TWRP przejdź do: **Install -> Install Image** (przycisk w prawym dolnym rogu).
2. Wybierz plik `aosp-arm64-ab-vanilla-13.0-20230919.img` i wskaż partycję docelową: **System Image**.
3. Przesuń suwak **Swipe to confirm Flash**.
4. Wgraj moduł mostka: **Install -> Zip -> TS8667_Android13_Automotive_Bridge.zip**.
5. Wykonaj **Wipe -> Format Data** i zrestartuj stację.

---

### Metoda 3: Przez Fastbootd (Z laptopa przez kabel USB)
1. Uruchom radio w trybie Fastbootd:
   ```bash
   adb reboot fastboot
   ```
   *(Na ekranie radia pojawi się menu z napisem **fastbootd**).*
2. Podłącz kabel USB i uruchom z katalogu `android13_aosp/scripts`:
   ```bash
   ./flash_android13_fastbootd.sh
   ```
   Skrypt wykona sekwencję:
   - `fastboot flash system aosp-arm64-ab-vanilla-13.0-20230919.img`
   - `fastboot -w` (czyszczenie userdata i cache)
   - `fastboot reboot`

---

## 5. Pierwsze Uruchomienie i Weryfikacja

Po starcie Androida 13:
1. Zobaczysz czystą animację startową AOSP i nowoczesny pulpit Androida 13.
2. Ekran jest zablokowany w rozdzielczości poziomej **1280x720**.
3. Dotyk (Goodix) i Wi-Fi (MT6631) działają natywnie przez jądro i vendorowe HAL-e.
4. Demon `ts_mcu_daemon` automatycznie przejmuje przyciski z kierownicy i bieg wsteczny.
5. Inicjalizator `bd3702_init` odcisza procesor dźwięku.

System jest czysty, ultralekki, responsywny i w 100% zintegrowany ze sprzętem pojazdu.
