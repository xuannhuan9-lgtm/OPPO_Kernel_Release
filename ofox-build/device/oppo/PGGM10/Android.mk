#
# 设备树入口
#
# 只在本设备被选中时才递归包含子目录（与真实设备树写法一致）。
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),PGGM10)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
