#!/system/bin/sh
# ==============================================================================
# Topway TS8667 / Junsun V1 Plus - Late Boot Background Service
# ==============================================================================

# 1. Enforce MCU serial port permissions for automotive bridge
if [ -e /dev/ttyMT1 ]; then
    chmod 666 /dev/ttyMT1
fi

# 2. Prevent deep sleep freeze on GPS/USB
settings put global wifi_sleep_policy 2

# 3. Active thermal fan daemon (SoC junction protection)
(
    while true; do
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
            # Temp is in millidegrees C (e.g. 60000 = 60C)
            if [ "$TEMP" -gt 65000 ]; then
                [ -f /sys/class/leds/fan/brightness ] && echo 255 > /sys/class/leds/fan/brightness
            elif [ "$TEMP" -gt 52000 ]; then
                [ -f /sys/class/leds/fan/brightness ] && echo 160 > /sys/class/leds/fan/brightness
            else
                [ -f /sys/class/leds/fan/brightness ] && echo 0 > /sys/class/leds/fan/brightness
            fi
        fi
        sleep 10
    done
) &
