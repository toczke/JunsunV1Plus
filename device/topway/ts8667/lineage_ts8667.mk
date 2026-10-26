# ==============================================================================
# lineage_ts8667.mk for SojunerOS (LineageOS 20 / Android 13)
# ==============================================================================

# Inherit from LineageOS product configurations
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)

# Inherit device makefile
$(call inherit-product, device/topway/ts8667/device.mk)

# Device & ROM identification
PRODUCT_NAME := lineage_ts8667
PRODUCT_DEVICE := ts8667
PRODUCT_BRAND := Topway
PRODUCT_MODEL := SojunerOS TS8667 (Android 13)
PRODUCT_MANUFACTURER := Topway

# LineageOS specific branding
PRODUCT_GMS_CLIENTID_BASE := android-topway
LINEAGE_BUILDTYPE := UNOFFICIAL
SOJUNEROS_VERSION := 20.0-TS8667
