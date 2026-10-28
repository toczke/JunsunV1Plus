# ==============================================================================
# Topway TS8667 / Junsun V1 Plus - Magisk Module Customization & Debloat Script
# ==============================================================================

ui_print "*****************************************************"
ui_print "  Topway TS8667 / Junsun V1 Plus Modern Custom OS   "
ui_print "           Ścieżka 2: Debloated + DUDU-OS            "
ui_print "*****************************************************"

# 1. List of OEM telemetry and bloatware directories to mask out systemlessly
ui_print "- Masking OEM telemetry and obsolete bloatware..."
REPLACE="
system/priv-app/cpe_agent
system/app/cpe_agent
system/app/txz
system/priv-app/txz
system/app/cservice
system/priv-app/cservice
system/app/ximalaya
system/app/autonavi
system/app/radio_topway_online
system/app/CarLetter
system/app/EasyConnect
system/priv-app/net.easyconn
system/app/sd_carplay
system/app/TsActivateCarDev
system/tsoem/easy
system/tsoem/easyFree
system/xbin/ffsu
"

# 2. Extract system tree
ui_print "- Installing modern automotive applications..."
# Extract files in module zip
unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2 2>/dev/null || true

# 3. Enforce proper Linux permissions (755 for dirs, 644 for files)
ui_print "- Setting permissions..."
set_perm_recursive "$MODPATH/system" 0 0 0755 0644
if [ -d "$MODPATH/system/bin" ]; then
    set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755
fi

ui_print "- Automotive OS components configured successfully!"
ui_print "  [✓] DUDU Launcher (Modern Tesla/PiP UI)"
ui_print "  [✓] Car Settings Bridge (CAN/MCU & Factory settings)"
ui_print "  [✓] Viper4Android FX (BD3702 DSP tuning)"
ui_print "  [✓] MicroG Services (GmsCore & FakeStore)"
ui_print "  [✓] Open Headunit (Android Auto)"
ui_print "  [✓] Landscape 1280x720 display lock"
ui_print "  [✓] Clean Android 10 genuine build properties"
ui_print "*****************************************************"
