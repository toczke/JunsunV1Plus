LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),ts8667)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
