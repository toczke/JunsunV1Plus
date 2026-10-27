# Gotowe obrazy partycji dla Topway TS8667 / MT6768 (Junsun V1 Plus)

Katalog zawiera przetestowane, zweryfikowane obrazy w formacie Android Boot v2 o dokładnym rozmiarze 32 MB (`33,554,432` bajtów), z nienaruszonym kompresowanym strumieniem jądra MediaTek (`lz4_lg`).

## Pliki obrazów

### 1. `boot_magisk_patched.img`
- **Rozmiar:** 33,554,432 bajtów (32 MB)
- **SHA-256:** `3a8a1d1d14db01d92c71f6a61c075624a0fa96907dd9eb9b83cc1241cf7906b3`
- **Opis:** Fabryczny `boot.img` ze spatchowanym ramdiskiem Magisk v26/v27.
- **Przeznaczenie:** Wgranie na partycję `/dev/block/by-name/boot` daje natychmiastowego, trwałego roota systemless (Zygisk + Magisk App) na normalnym starcie Androida.

### 2. `twrp_fixed_32mb.img`
- **Rozmiar:** 33,554,432 bajtów (32 MB)
- **SHA-256:** `54227d9280104bccf780e967d5f0d53bc4fa22ecb7bd8e3f7844004a8d89f494`
- **Opis:** Odchudzone TWRP z zachowanym fabrycznym kernelem, drzewem DTB i DTBO recovery.
- **Przeznaczenie:** Wgranie na `/dev/block/by-name/recovery` lub `/dev/block/by-name/boot`.

### 3. `boot_stock.img`
- **Rozmiar:** 33,554,432 bajtów (32 MB)
- **SHA-256:** `9c7f01d94ae090ccd03ccad36caaf95f6b14de79e58529669e0b80ee74c35ac4`
- **Opis:** Oryginalny, fabryczny zrzut partycji boot bez żadnych modyfikacji.
- **Przeznaczenie:** Przywrócenie stanu fabrycznego.
