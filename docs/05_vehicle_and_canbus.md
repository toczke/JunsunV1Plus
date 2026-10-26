# Chapter 5: Vehicle & CAN Bus Integration

Technical documentation of the 342 built-in CAN bus protocols, communication architectures, steering wheel controls, and OBD-II telemetry.

---

## 1. CAN Bus Architecture on Chinese Android Headunits

Unlike OEM car headunits where the Android processor connects directly to the vehicle CAN transceiver, Chinese automotive headunits (Topway / Junsun) use a **Two-Tier Architecture**:

```
Vehicle CAN Bus (High-Speed / Low-Speed)
       │
       ▼
[External CAN Bus Box] (Raise / Hiworld / SimpleSoft / Xinpu / Binary)
       │
       ▼ (UART Serial / TTL @ 19200 or 38400 baud)
[On-Board MCU] (Microcontroller Unit on Headunit Motherboard)
       │
       ▼ (Internal Serial bus /dev/ttyMT1 @ 115200 baud)
[MediaTek MT8667 Android SoC] (Running /system/app/MainUI/MainUI.apk)
```

1. **External CAN Box:** Interprets car-specific CAN frames (differential CAN_H and CAN_L).
2. **MCU:** Translates raw bytes into Topway unified serial packets (`0x2E` header protocol).
3. **Android SoC (`MainUI`):** Decodes the packet into Android events (door open, volume up, reverse gear engaged, AC climate control change).

---

## 2. Supported Vehicle Brands & CAN Profiles

`MainUI.apk` contains **342 built-in vehicle CAN bus profiles** under the `com.ts.can.*` namespace:

### 2.1 Volkswagen / Audi / SEAT / Skoda
- **Golf / Passat / Tiguan / Touran (`CanGolf*`):**
  - Multifunction Display (MFD) instrument cluster text sync (song titles, FM frequencies).
  - Dual-zone Climatronic pop-up overlay with seat heating indicators.
  - Driving profile selection (Normal, Sport, Eco, Individual).
  - Factory parking radar distance visualization (PDC).
  - Start-Stop status and battery voltage monitor.
- **Touareg / Porsche Cayenne (`CanTouareg*`):**
  - Air suspension level display.
  - Factory amplifier volume and fader communication.

### 2.2 BMW & Mini
- **Mini Cooper (`CanBMWMini*`):**
  - Vehicle status check, door warnings, factory service intervals.
- **BMW E90 / E60 / F10 / F30 (`CanBmwWithCD*`):**
  - iDrive controller knob rotation and push button event handling.
  - Integration with factory optical CD changer.

### 2.3 Mercedes-Benz
- **Audio 20 / NTG 4.0 / NTG 4.5 (`CanBencWithCD*`, `DrivingComputeActivity`):**
  - Factory dashboard trip computer calculation.
  - Center console rotary knob protocol handling.

### 2.4 Toyota & Lexus
- **Toyota Hybrid Synergy Drive (`CanToyotaSpyHybridActivity`):**
  - Live animated power flow diagram: Engine, Electric Motor, and Battery pack state-of-charge (SoC).
  - Historical trip fuel economy bar graph (liters per minute / km per liter).
- **Lexus IS250 / GS / RX (`CanLexusIs250*`):**
  - Climate control touchscreen interface replacement for factory HVAC screen.

### 2.5 Honda & Acura
- **Accord / Civic / CR-V (`CanAccord*`):**
  - LaneWatch camera activation: turning right signals the headunit to automatically switch the screen to the right mirror camera feed.
  - Factory dual-screen DA interface sync.

### 2.6 Ford
- **Fiesta / Focus / Mondeo / Kuga (`CanOldFiesta*`, Ford SYNC):**
  - Emulates Ford SYNC module audio commands and steering wheel voice button.

### 2.7 Other Major Brands
- **PSA (Peugeot / Citroën):** Trip computer, vehicle configuration menus (lighting, parking sensors).
- **Fiat / Chrysler / Jeep / Dodge:** Compass heading, electric parking brake, light assist.
- **Renault (Kadjar / Megane):** Park Assist trajectory, vehicle user settings.
- **Nissan:** 360° camera physical button integration.
- **Mitsubishi Outlander:** Rockford Fosgate digital amplifier volume and surround sound DSP setup.
- **Direct OBD-II (`CanObdCarInfoActivity`):** Reads engine RPM, coolant temperature, vehicle speed, intake pressure, and DTC diagnostic trouble codes directly over the CAN box.

---

## 3. Analog Steering Wheel Controls (Key1 / Key2)

For vehicles without a CAN bus (standard resistive ladder buttons):
- The headunit features two analog inputs: **Key 1** and **Key 2** connected to MediaTek MT6358 ADC channels.
- App: **Key Study (`com.ts.CStudy.CStudyMainActivity`)**.
- Learning process: Press and hold a physical steering wheel button (e.g. Volume Up), tap "Volume Up" on screen; the MCU measures the resistance voltage (0V to 3.3V) and saves the mapping into EEPROM/NVRAM.
