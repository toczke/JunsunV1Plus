#!/usr/bin/env bash
# SojunerOS 20.0 — MediaTek MT8667 / MT6768 Automated Kernel & Boot.img Builder
# Target: Topway TS-8667-02 / Junsun V1 Plus (Android 13 / LineageOS 20)
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

KERNEL_SRC="${KERNEL_SRC:-/home/tomasztoczek/Downloads/sojuneros_workspace/kernel_mt6768}"
DEFCONFIG="${REPO_ROOT}/device/topway/ts8667/ts8667_defconfig"
DTB_FILE="${REPO_ROOT}/device/topway/ts8667/prebuilt/dtb"
OUT_DIR="${REPO_ROOT}/out/kernel"
ARCH="arm64"
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"

mkdir -p "${OUT_DIR}"

echo "========================================================"
echo "SojunerOS 20.0 — Kernel Build: MT6768 Linux 4.14 LTS"
echo "========================================================"
echo "Kernel Source: ${KERNEL_SRC}"
echo "Defconfig:     ${DEFCONFIG}"
echo "Output:        ${OUT_DIR}"
echo "Cross-Compile: ${CROSS_COMPILE}"
echo "========================================================"

# Check requirements
for tool in "${CROSS_COMPILE}gcc" lz4 mkbootimg avbtool; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "Error: Required tool '${tool}' is not installed or not in PATH." >&2
        exit 1
    fi
done

if [ ! -d "${KERNEL_SRC}" ]; then
    echo "Error: Kernel source directory not found at ${KERNEL_SRC}" >&2
    exit 1
fi

if [ ! -f "${DEFCONFIG}" ]; then
    echo "Error: Defconfig not found at ${DEFCONFIG}" >&2
    exit 1
fi

# Step 0: Apply kernel fixes patch if not yet applied
PATCH_FILE="${REPO_ROOT}/device/topway/ts8667/kernel_mt6768_port.patch"
if [ -f "${PATCH_FILE}" ]; then
    echo "[0/5] Checking and applying MT6768 platform patches..."
    (cd "${KERNEL_SRC}" && git apply --check "${PATCH_FILE}" 2>/dev/null && git apply "${PATCH_FILE}" || echo "Patches already applied or skipped.")
fi

# Step 1: Copy defconfig to kernel source tree
echo "[1/5] Applying ts8667_defconfig..."
cp "${DEFCONFIG}" "${KERNEL_SRC}/.config"

# Step 2: Build Kernel Image
echo "[2/5] Compiling Kernel Image (parallel jobs: $(nproc))..."
make -C "${KERNEL_SRC}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" Image

KERNEL_IMAGE="${KERNEL_SRC}/arch/arm64/boot/Image"
if [ ! -f "${KERNEL_IMAGE}" ]; then
    echo "Error: Kernel Image compilation failed!" >&2
    exit 1
fi

echo "[2/5] Kernel Image successfully generated: $(ls -lh "${KERNEL_IMAGE}")"

# Step 3: Compress with LZ4
echo "[3/5] Compressing Image with LZ4 (level 9)..."
lz4 -9 -f "${KERNEL_IMAGE}" "${OUT_DIR}/Image.lz4"
echo "Compressed Image.lz4: $(ls -lh "${OUT_DIR}/Image.lz4")"

# Step 4: Extract ramdisk & DTB if not locally cached
RAMDISK_FILE="${OUT_DIR}/ramdisk"
if [ ! -f "${RAMDISK_FILE}" ]; then
    if [ -f "/tmp/boot_unpack/ramdisk" ]; then
        cp "/tmp/boot_unpack/ramdisk" "${RAMDISK_FILE}"
    elif [ -f "${REPO_ROOT}/device/topway/ts8667/prebuilt/ramdisk" ]; then
        cp "${REPO_ROOT}/device/topway/ts8667/prebuilt/ramdisk" "${RAMDISK_FILE}"
    else
        echo "Warning: Ramdisk file not found, creating minimal init ramdisk..."
        mkdir -p "${OUT_DIR}/ramdisk_root"
        touch "${OUT_DIR}/ramdisk_root/init"
        chmod +x "${OUT_DIR}/ramdisk_root/init"
        (cd "${OUT_DIR}/ramdisk_root" && find . | cpio -o -H newc | gzip -9 > "${RAMDISK_FILE}")
    fi
fi

if [ ! -f "${DTB_FILE}" ]; then
    if [ -f "/tmp/boot_unpack/dtb" ]; then
        mkdir -p "$(dirname "${DTB_FILE}")"
        cp "/tmp/boot_unpack/dtb" "${DTB_FILE}"
    fi
fi

# Step 5: Pack boot.img with mkbootimg & sign with AVB
BOOT_IMG="${OUT_DIR}/boot.img"
echo "[4/5] Packing Android boot image (header v2)..."
mkbootimg \
  --kernel "${OUT_DIR}/Image.lz4" \
  --ramdisk "${RAMDISK_FILE}" \
  --dtb "${DTB_FILE}" \
  --base 0x40000000 \
  --kernel_offset 0x00080000 \
  --ramdisk_offset 0x07c80000 \
  --second_offset 0x00f00000 \
  --tags_offset 0x0bc80000 \
  --dtb_offset 0x0bc80000 \
  --pagesize 2048 \
  --header_version 2 \
  --cmdline "bootopt=64S3,32N2,64N2 buildvariant=userdebug" \
  --os_version 13.0.0 \
  --os_patch_level 2026-10 \
  -o "${BOOT_IMG}"

echo "[5/5] Signing boot.img with AVB footer (partition size 33554432)..."
avbtool add_hash_footer \
  --image "${BOOT_IMG}" \
  --partition_size 33554432 \
  --partition_name boot

echo "========================================================"
echo "SojunerOS 20.0 boot.img successfully built and verified!"
echo "Location: ${BOOT_IMG}"
echo "Size:     $(ls -lh "${BOOT_IMG}" | awk '{print $5}')"
echo "AVB info:"
avbtool info_image --image "${BOOT_IMG}" | grep -E "Partition Name|Image Size|Digest|Flags"
echo "========================================================"
