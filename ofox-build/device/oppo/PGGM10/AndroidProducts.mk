#
# OPPO K10x 5G (PGGM10 / OP5295) —— OrangeFox 产品注册
#
# 这个文件告诉 build 系统「本设备树提供哪些 product」。
# lunch 的时候能看到的就是下面 COMMON_LUNCH_CHOICES 里的项。
#
# ★关于 lunch 组合注册方式★
#   Android 12+ 的 build 系统【只认】COMMON_LUNCH_CHOICES，
#   旧的 `add_lunch_combo fox_PGGM10-eng`（写在 vendorsetup.sh 里）已废弃，
#   新版本里即使写了也不会注册。所以这里必须列全。
#
#   ~eng / ~userdebug / ~user 后缀决定构建变体（BUILD_VARIANT）。
#   recovery 编译用 eng 即可（debug 全开、便于排错）。
#   如果想用 userdebug，下面也已经列上了。
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/fox_PGGM10.mk

COMMON_LUNCH_CHOICES := \
    fox_PGGM10-eng \
    fox_PGGM10-userdebug \
    fox_PGGM10-user
