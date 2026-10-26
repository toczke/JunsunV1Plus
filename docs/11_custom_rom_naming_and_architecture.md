# Chapter 11: Custom ROM Naming, Architecture & Distribution Strategy

> **Target Platform:** Junsun V1 Plus / Topway TS8667 (MediaTek MT8667 / MT6768)  
> **Display:** 1280 × 720 (16:9 Landscape)  
> **Target OS:** Android 13 Automotive Custom ROM  

---

## 1. Candidate Names for the Custom ROM

To give the project a distinct identity in the automotive enthusiast community (similar to *Malaysk*, *Hal9k*, or *DUDU-OS*), here are four proposed name concepts tailored to this build:

| Candidate Name | Concept & Identity | Tagline / Theme |
| :--- | :--- | :--- |
| **ApexDrive OS** | Premium, performance-oriented automotive feel. Clean, fast, modern. | *"The pinnacle of open automotive Android."* |
| **ApolloAuto OS** | Space/engineering inspiration. Reliable, telemetry-free, mission-critical. | *"Clean telemetry-free cockpit for MediaTek headunits."* |
| **HorizonOS Car Edition** | Expansive widescreen view (16:9 landscape 1280×720). Modern cockpit design. | *"Broad horizons on your dashboard."* |
| **AuroraOS Auto** | Dynamic visual styling, responsive performance, privacy-first. | *"Clarity and freedom behind the wheel."* |

---

## 2. Core Custom ROM Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                   USER INTERFACE LAYER (Landscape)                     │
│  - Default Launcher: DUDU-OS Launcher (1280x720)                       │
│  - Settings Integration: Car Settings Bridge (AOSP Settings Tile)      │
│  - Projection: DiPlay / AutoKit (Clean wireless CarPlay & Android Auto)│
│  - GMS Base: MicroG Core (~30MB RAM) / Optional NikGapps Core          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Android 13 Framework / AOSP Base
┌───────────────────────────────────▼────────────────────────────────────┐
│               HARDWARE PRESERVATION DAEMONS (Retained)                 │
│  - MainUI Headless Daemon: MCU UART serial (/dev/ttyMT1)               │
│  - CAN Bus Engine: libcan59.so (340+ vehicle profiles, AC, PDC)        │
│  - Reversing & 360° AVM: BackcarService + Techpoint TP2850             │
│  - Audio Engine: ROHM BD3702FV 32-band DSP equalizer                   │
│  - Thermal Management: CpuTempUtilsService (Active cooling fan)        │
│  - Peripherals: Front DVR (com.ankai.cardvr), TPMS, DVD player         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Android 10 Vendor HAL Compatibility
┌───────────────────────────────────▼────────────────────────────────────┐
│                    KERNEL & HARDWARE ABSTRACTION                       │
│  - Kernel: Linux 4.14.186+ (arm64, MT8667 big.LITTLE 2x A75 + 6x A55)  │
│  - GPU: ARM Mali-G52 MC2 (Vulkan & OpenGL ES 3.2)                      │
│  - Partitions: Dynamic Partitions (super.img: system, vendor, product) │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Step-by-Step Build Pipeline

1. **Partition De-bloat & Pruning:**
   - Strip all OEM launchers (`vendor/tsoem/launcher/apks/*`).
   - Strip legacy phone-link services (`sd_carplay`, `CarLetter`, `EasyConnect`).
   - Strip Chinese telemetry daemons (`txz`, `cpe_agent`, `cservice`, `ximalaya`).
   - Remove insecure `/system/xbin/ffsu` backdoor (replace with clean Magisk).

2. **Integration of System Components:**
   - Inject pre-compiled `CarSettingsBridge.apk` into `/system/priv-app/CarSettingsBridge/`.
   - Pre-install DUDU-OS Launcher into `/system/priv-app/DuduLauncher/`.
   - Configure `/system/build.prop`:
     ```properties
     ro.sf.hwrotation=0
     ro.surface_flinger.primary_display_orientation=ORIENTATION_0
     persist.sys.orientation=landscape
     ro.product.model=TS8667
     ro.product.brand=Topway
     ```

3. **Packaging & Image Generation:**
   - Build updated `system.img` and `vendor.img`.
   - Re-assemble sparse `super.img` via `lpmake`.
   - Splicing into flashable `8667.bin` container with `8667.upd` MD5 checksum.
