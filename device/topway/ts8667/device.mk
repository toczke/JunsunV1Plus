# ==============================================================================
# device.mk for Junsun V1 Plus / TS8667 (Android 13)
# ==============================================================================

# Inherit from base AOSP / LineageOS core configs
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

DEVICE_PACKAGE_OVERLAYS += device/topway/ts8667/overlay

# Hardware Apps & Modules
PRODUCT_PACKAGES += \
    CarSettingsBridge \
    android.hardware.automotive.vehicle@2.0-service \
    android.hardware.audio@7.0-impl \
    android.hardware.audio.effect@7.0-impl \
    android.hardware.broadcastradio@2.0-service

# Vehicle Essential Properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.hwrotation=0 \
    ro.surface_flinger.primary_display_orientation=ORIENTATION_0 \
    persist.sys.orientation=landscape \
    ro.control_privapp_permissions=log \
    ro.apex.updatable=false

# Automotive Media & Audio Routing
PRODUCT_PROPERTY_OVERRIDES += \
    ro.audio.silent=0 \
    persist.sys.volume_type=1 \
    persist.sys.can.baud=115200

# Device identification
PRODUCT_NAME := ts8667
PRODUCT_DEVICE := ts8667
PRODUCT_BRAND := Topway
PRODUCT_MODEL := Junsun V1 Plus (TS8667)
PRODUCT_MANUFACTURER := Topway
