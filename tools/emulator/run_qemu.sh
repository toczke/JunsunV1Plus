#!/usr/bin/env bash
# SojunerOS 20.0 — QEMU ARM64 Virtual Infotainment Hardware Emulator
# Target Hardware: Topway TS-8667-02 / Junsun V1 Plus (MediaTek MT8667 ARM64)
# Display: 1280x720 Landscape
# Emulated Ports: Serial 0 (Console), Serial 1 (Topway MCU UART on /tmp/mcu_uart)
# Network: VirtIO Net with ADB forwarding on localhost:5555
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default paths
KERNEL_IMG="${KERNEL_IMG:-${REPO_ROOT}/out/kernel/Image}"
RAMDISK_IMG="${RAMDISK_IMG:-${REPO_ROOT}/out/kernel/ramdisk}"
SYSTEM_IMG="${SYSTEM_IMG:-}"
MCU_UART_PATH="${MCU_UART_PATH:-/tmp/mcu_uart}"
HEADLESS=0
ADB_PORT=5555

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel)
            KERNEL_IMG="$2"
            shift 2
            ;;
        --ramdisk)
            RAMDISK_IMG="$2"
            shift 2
            ;;
        --system)
            SYSTEM_IMG="$2"
            shift 2
            ;;
        --mcu-uart)
            MCU_UART_PATH="$2"
            shift 2
            ;;
        --headless)
            HEADLESS=1
            shift
            ;;
        --adb-port)
            ADB_PORT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --kernel <path>       Kernel Image file (default: out/kernel/Image)"
            echo "  --ramdisk <path>      Ramdisk cpio/gz (default: out/kernel/ramdisk)"
            echo "  --system <path>       System / Super ext4 or raw image file"
            echo "  --mcu-uart <path>     Path to mock MCU PTY symlink (default: /tmp/mcu_uart)"
            echo "  --headless            Run without graphical window (VNC on :0)"
            echo "  --adb-port <port>     ADB port to forward to host (default: 5555)"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [ ! -f "${KERNEL_IMG}" ]; then
    # Fallback to source workspace if not in out/
    if [ -f "/home/tomasztoczek/Downloads/sojuneros_workspace/kernel_mt6768/arch/arm64/boot/Image" ]; then
        KERNEL_IMG="/home/tomasztoczek/Downloads/sojuneros_workspace/kernel_mt6768/arch/arm64/boot/Image"
    else
        echo "Error: Kernel Image not found at ${KERNEL_IMG}" >&2
        echo "Please run 'tools/build_kernel.sh' first." >&2
        exit 1
    fi
fi

echo "=========================================================="
echo "SojunerOS 20.0 — QEMU ARM64 Hardware Emulator"
echo "=========================================================="
echo "Kernel:   ${KERNEL_IMG}"
echo "Ramdisk:  ${RAMDISK_IMG}"
echo "MCU UART: ${MCU_UART_PATH}"
echo "ADB Port: localhost:${ADB_PORT} -> guest:5555"
echo "Display:  1280x720 Fixed Landscape"
echo "=========================================================="

# Check if MCU mock UART is running
if [ ! -e "${MCU_UART_PATH}" ]; then
    echo "[!] Warning: MCU mock UART not found at ${MCU_UART_PATH}."
    echo "[!] Start the MCU mock in a separate terminal: python3 tools/emulator/mock_topway_mcu.py"
    MCU_SERIAL_ARG="-serial pty"
else
    MCU_SERIAL_ARG="-chardev serial,path=${MCU_UART_PATH},id=mcu_char -serial chardev:mcu_char"
fi

# Kernel command line arguments
KERNEL_CMDLINE="console=ttyAMA0 earlycon androidboot.hardware=spm8667p1_64 androidboot.selinux=permissive androidboot.boot_devices=soc/11230000.mmc init=/init ignore_loglevel"

QEMU_ARGS=(
    qemu-system-aarch64
    -M virt,gic-version=3
    -cpu cortex-a72
    -smp 8
    -m 4G
    -kernel "${KERNEL_IMG}"
    -append "${KERNEL_CMDLINE}"
    -serial mon:stdio
    ${MCU_SERIAL_ARG}
    -device virtio-net-pci,netdev=net0
    -netdev "user,id=net0,hostfwd=tcp::${ADB_PORT}-:5555"
    -device virtio-tablet-pci
    -device virtio-keyboard-pci
    -device intel-hda
    -device hda-duplex
)

if [ -f "${RAMDISK_IMG}" ]; then
    QEMU_ARGS+=(-initrd "${RAMDISK_IMG}")
fi

if [ -n "${SYSTEM_IMG}" ] && [ -f "${SYSTEM_IMG}" ]; then
    QEMU_ARGS+=(-drive "file=${SYSTEM_IMG},format=raw,if=virtio,index=0")
fi

if [ "${HEADLESS}" -eq 1 ]; then
    QEMU_ARGS+=(
        -display none
        -vnc :0
    )
    echo "Running headless. Connect via VNC at localhost:5900"
else
    QEMU_ARGS+=(
        -device "virtio-gpu-pci,xres=1280,yres=720"
        -display default,show-cursor=on
    )
fi

echo "Launching QEMU..."
exec "${QEMU_ARGS[@]}"
