#!/system/bin/sh
# ==============================================================================
# Topway TS8667 Android 13 Automotive Bridge - Boot Service
# ==============================================================================

MODDIR=${0%/*}

# 1. Enforce device node permissions
chmod 666 /dev/ttyMT1 2>/dev/null || true
chmod 666 /dev/uinput 2>/dev/null || true
chmod 666 /dev/i2c-1 2>/dev/null || true

# 2. Initialize ROHM BD3702FV Audio DSP (sets input to MediaTek DAC, unmutes, flat EQ)
if [ -x "$MODDIR/system/bin/bd3702_init" ]; then
    "$MODDIR/system/bin/bd3702_init" > /dev/kmsg 2>&1
fi

# 3. Start Native MCU Daemon (Steering Wheel buttons -> uinput, Reverse, Day/Night)
if [ -x "$MODDIR/system/bin/ts_mcu_daemon" ]; then
    "$MODDIR/system/bin/ts_mcu_daemon" > /dev/kmsg 2>&1 &
fi

# 4. Start CPU Thermal Protection Fan Governor
if [ -x "$MODDIR/system/bin/fan_governor" ]; then
    "$MODDIR/system/bin/fan_governor" > /dev/kmsg 2>&1 &
fi
