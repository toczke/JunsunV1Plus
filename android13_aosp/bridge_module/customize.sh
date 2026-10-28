# ==============================================================================
# Topway TS8667 Android 13 Automotive Bridge - Magisk Installer
# ==============================================================================

ui_print "*****************************************************"
ui_print " Topway TS8667 Android 13 Automotive Bridge v1.0    "
ui_print "*****************************************************"

ui_print "- Installing native automotive daemons to /system/bin..."
unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2 2>/dev/null || true

ui_print "- Setting binary execution permissions..."
set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755

ui_print "  [✓] ts_mcu_daemon (SWC buttons, Reverse, Day/Night)"
ui_print "  [✓] bd3702_init   (ROHM BD3702FV DSP Audio unmute)"
ui_print "  [✓] fan_governor  (Active CPU junction thermal protection)"
ui_print "*****************************************************"
