# Inherit basic Omni / AOSP configurations
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

ifneq ($(wildcard vendor/omni/config/common.mk),)
$(call inherit-product, vendor/omni/config/common.mk)
endif

ifneq ($(wildcard vendor/twrp/config/common.mk),)
$(call inherit-product, vendor/twrp/config/common.mk)
endif

# Inherit TWRP configuration
$(call inherit-product, $(LOCAL_PATH)/twrp_ts8667.mk)

PRODUCT_NAME := omni_ts8667
PRODUCT_DEVICE := ts8667
PRODUCT_BRAND := Topway
PRODUCT_MODEL := TS8667
PRODUCT_MANUFACTURER := Topway
