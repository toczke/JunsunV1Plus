#!/system/bin/sh
# ==============================================================================
# Topway TS8667 Automotive Hardware Initialization Daemon (Android 13)
# ==============================================================================

# 1. Enforce device permissions
chmod 666 /dev/ttyMT1 2>/dev/null || true
chmod 666 /dev/uinput 2>/dev/null || true
chmod 666 /dev/i2c-1 2>/dev/null || true

# 2. Initialize ROHM BD3702FV Audio DSP (sets differential input, unmutes, flat EQ)
if [ -x /system/bin/bd3702_init ]; then
    /system/bin/bd3702_init > /dev/kmsg 2>&1
fi

# 3. Start Native Topway MCU Daemon (SWC buttons -> uinput keys, Reverse camera, Day/Night)
if [ -x /system/bin/ts_mcu_daemon ]; then
    /system/bin/ts_mcu_daemon > /dev/kmsg 2>&1 &
fi

# 4. Start Active CPU Junction Cooling Fan Governor
if [ -x /system/bin/fan_governor ]; then
    /system/bin/fan_governor > /dev/kmsg 2>&1 &
fi
