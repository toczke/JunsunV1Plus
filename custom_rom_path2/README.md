# Custom ROM Architecture & Build Suite - Ścieżka 2

This directory contains the complete build and staging environment for **Ścieżka 2: Hybrydowy Custom ROM (Debloated Base + DUDU-OS UI + Car Settings Bridge + Viper4Android FX + MicroG)** for Topway TS8667 / Junsun V1 Plus (MT6768).

---

## Structure
```
custom_rom_path2/
├── build_packages.sh         # Automated fetch & pack script for Custom ROM zips
├── README.md                 # Technical manifest
├── magisk_module/            # Source tree for Magisk Systemless Custom OS module
│   ├── META-INF/             # Android recovery/Magisk installer stubs
│   ├── module.prop           # Module metadata
│   ├── system.prop           # Early boot property overrides (1280x720, true Android 10)
│   ├── customize.sh          # Installation debloat & privilege assignment
│   └── service.sh            # Background MCU permissions & SoC thermal fan governor
├── scripts/                  # Device installer & maintenance scripts
│   ├── install_custom_os_live.sh   # Live root installer
│   ├── install_custom_os_twrp.sh   # TWRP installer
│   └── uninstall_custom_os.sh      # Rollback script
└── apks/                     # (Ignored in git) Pre-downloaded companion APKs
```

## How to Build the Flashable Zips
Run:
```bash
./build_packages.sh
```
This produces:
- `TS8667_Custom_OS_Sciezka2_Full.zip` (~158 MB)
- `TS8667_Custom_OS_Sciezka2_Lite.zip` (~41 MB)

Both files are deployed directly to the root USB drive under `08_SCIEZKA_2_CUSTOM_ROM/`.
