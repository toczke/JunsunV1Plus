# Audyt i Selekcja Aplikacji dla Custom ROM Android 13 (Junsun V1 Plus / TS8667)

Ten dokument kategoryzuje każdą fabryczną aplikację z firmware, wyjaśnia jej rolę sprzętową i wskazuje, co jest **bezwzględnie wymagane**, a co podlega Twojej decyzji.

---

## 🟢 Kategoria 1: RDZENNE USŁUGI SAMOCHODOWE (Bezwzględnie Wymagane)
Te komponenty odpowiadają za komunikację z mikrokontrolerem płyty głównej (MCU), szyną CAN, kamerami i wzmacniaczem audio. Bez nich radio staje się zwykłym tabletem bez łączności z samochodem.

| Aplikacja / Plik | Rola sprzętowa | Czy zostaje w Androidzie 13? |
|---|---|---|
| **`MainUI.apk`** (`com.ts.MainUI`) | **Mózg sprzętowy radia**: Obsługuje port `/dev/ttyMT1` łączący z MCU i szyną CAN. Przetwarza sygnał biegu wstecznego, przyciski z kierownicy (SWC), radio FM, regulację głośności. | **TAK (w trybie tła)**. Odchudzamy go z brzydkiego fabrycznego interfejsu, ale zostawiamy jego silnik w tle. |
| **`AVM2.apk` / `360Camera.apk`** | Obsługa kamer 360° oraz procesora **Techpoint TP2850**. Odpowiada za łączenie 4 obrazów w rzut z góry oraz linie skrętne kamery cofania. | **TAK**. Podpięty pod wyzwalacz biegu wstecznego. |
| **`CStudyMainActivity`** (część MainUI) | Programowanie analogowych przycisków kierownicy (Key1 / Key2) w autach bez magistrali cyfrowej CAN. | **TAK**. Niezbędne do przypisania przycisków na kierownicy. |
| **`SetDspMainActivity`** (część MainUI) | Panel sterowania procesorem dźwięku **ROHM BD3702FV** (korektor, fader, odcięcie subwoofera 80/120/160 Hz). | **TAK**. Zapewnia prawidłowe wysterowanie głośników i subwoofera. |
| **`fan.apk`** | Sterowanie wentylatorem chłodzenia procesora na podstawie odczytów temperatury CPU. | **TAK (lub lekki skrypt/demon C++)**. Chroni MediaTeka przed przegrzaniem latem. |
| **`MyTouch_sign.apk`** | Narzędzie kalibracji 5-punktowej ekranu dotykowego Goodix (w razie rozkalibrowania dotyku). | **TAK**. Bezpiecznik serwisowy. |
| **`logoset.apk`** | Zmiana logo startowego marki samochodu w pamięci flash. | **TAK**. |

---

## 🔴 Kategoria 2: ŚMIECI I ZASTĘPOWANE RZECZY (Do Całkowitego Usunięcia)
Te aplikacje usuwamy, aby zwolnić zasoby, wyczyścić szpiegujące skrypty i zapobiec konfliktom z **DiPlay**:

| Aplikacja | Dlaczego usuwamy? | Czym zastępujemy? |
|---|---|---|
| **`sd_carplay`** (`/system/bin`) | Zamknięty w tle proces SuDing blokujący porty USB. | Zastąpiony przez **DiPlay** / zewnętrzny adapter. |
| **`CarLetter.apk`** | Fabryczna aplikacja do CarPlay/Android Auto. | Zastąpiona przez **DiPlay**. |
| **`EasyConnect*.apk`** | Chiński program do klonowania ekranu zbierający telemetrię o telefonie. | Całkowicie zbędny. |
| **`TsActivateCarDev.apk`** | Skrypt sprawdzający chińską licencję online na CarPlay. | Całkowicie zbędny. |
| **Fabryczne launchery UI00-UI04** | Przestarzałe nakładki graficzne z fałszywym 3D. | **DUDU Launcher** lub **Agama Car Launcher**. |

---

## 🟡 Kategoria 3: APLIKACJE DO TWOJEJ DECYZJI (Pytania do Ciebie)

Poniżej znajduje się lista fabrycznych aplikacji z prośbą o Twoją decyzję, czy chcesz je zachować w nowym systemie:

### 1. `com.ankai.cardvr` (Rejestrator Jazdy / Dashcam)
- **Opis:** Obsługuje przednią kamerę USB/MIPI marki Ankai montowaną na przedniej szybie (rejestruje trasę w pętli na kartę SD/pendrive i wyświetla podgląd ADAS).
- **Czy masz dedykowaną kamerkę USB Dashcam w aucie wpiętą do tego radia?**

### 2. `TPMSMainActivity` (Czujniki Ciśnienia w Oponach)
- **Opis:** Odbiera sygnał z zewnętrznych lub wewnętrznych nakręcanych czujników ciśnienia i temperatury opon (przez odbiornik USB TPMS).
- **Czy korzystasz z czujników TPMS podłączonych do radia?**

### 3. `DvdBoxMainActivity` & `CmmbMainActivity` / `AtvMainActivity`
- **Opis:** Obsługa zewnętrznego napędu płyt DVD oraz analogowego/cyfrowego tunera telewizji naziemnej CMMB/DVB-T.
- **Czy planujesz podłączać napęd DVD lub tuner TV w aucie?** (Zalecane: usunąć, nikt tego dziś nie używa).

### 4. `Velvet.apk` (Google App) & Google Assistant
- **Opis:** Pełna aplikacja Google (wyszukiwarka, asystent głosowy, Google Feed). Jest to najcięższa aplikacja w systemie, zużywająca stale ~350–450 MB pamięci RAM w tle.
- **Czy wolisz zachować pełne usługi Google (Play Store + Asystent), czy odchudzone MicroG / sam Sklep Play, aby radio uruchamiało się błyskawicznie?**

### 5. Wybór Launchera (Ekranu Głównego)
Ponieważ usuwamy fabryczny launcher `UI03 (车模)`:
- Czy Twoim domyślnym ekranem ma być **DUDU-OS Launcher** (nowoczesny pulpit samochodowy z widżetem mapy w czasie rzeczywistym i sterowaniem muzyką), czy klasyczny **Agama Car Launcher**?
