#
# OPPO K10x 5G (PGGM10 / OP5295) —— OrangeFox 产品注册
#
# 这个文件告诉 build 系统「本设备树提供哪些 product」。
# lunch 的时候能看到的就是下面 COMMON_LUNCH_CHOICES 里的项。
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/fox_PGGM10.mk

COMMON_LUNCH_CHOICES := \
    fox_PGGM10-eng \
    fox_PGGM10-userdebug
