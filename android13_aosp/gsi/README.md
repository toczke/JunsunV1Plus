# Android 13 AOSP GSI Image (Pure Vanilla TrebleDroid)

This directory hosts the pure **Android 13.0 (API 33)** Generic System Image (GSI) targeting **Topway TS8667 / Junsun V1 Plus (MT6768)**.

---

## Image Manifest
- **Build:** `AOSP 13.0 v2023.09.19` (Maintainer: ponces / TrebleDroid)
- **Architecture:** `arm64` (64-bit ARMv8-A)
- **Partition Scheme:** `ab` (System-as-Root, Dynamic Partitions compatible)
- **Flavor:** `vanilla` (Clean AOSP without Google Apps, bloatware, or vendor modifications)
- **Uncompressed Size:** `1,932,656,640 bytes` (1.8 GB)
- **Dynamic Partition Target:** `system` logical partition inside `super` (fits completely inside the 2.1 GB stock allocation)
- **MD5:** `51baef7cb6256956636735e054baeb3c`

---

## Direct Download
If pulling the image fresh, run:
```bash
curl -L -o aosp-arm64-ab-vanilla-13.0-20230919.img.xz \
  "https://github.com/ponces/treble_aosp/releases/download/v2023.09.19/aosp-arm64-ab-vanilla-13.0-20230919.img.xz"
xz -dk aosp-arm64-ab-vanilla-13.0-20230919.img.xz
```
