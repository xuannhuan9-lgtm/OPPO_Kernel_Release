#
# OPPO K10x 5G (PGGM10 / OP5295) —— 产品注册
#
# ★本文件严格照抄 TWRP 官方设备树（TeamWin/android_device_xiaomi_mojito）
#   的写法：只声明 PRODUCT_MAKEFILES，【不写 COMMON_LUNCH_CHOICES】。★
#
# 为什么删掉 COMMON_LUNCH_CHOICES（run #7/#8 的教训）：
#   1) 官方 TWRP 设备树根本没有这个变量，没有它也完全能 lunch；
#      不写它时，lunch（不带参数）会把 PRODUCT_MAKEFILES 里的每个 product
#      按 <product>-<release>-<variant> 展开列出，release 由 build 系统自己推导。
#   2) COMMON_LUNCH_CHOICES 里的条目在部分 AOSP 版本里【会被格式校验】，
#      混进两段式（fox_PGGM10-eng）这种非法格式，会让整个产品列表用不了。
#   3) 实测症状：lunch 输出里【一个 fox_PGGM10-* 都没有】，
#      于是 TARGET_DEVICE/TARGET_PRODUCT 全是「未设置」。
#
# 现在文件回到最小可用形态。lunch 目标由 workflow 自动探测：
#   优先 fox_PGGM10-<release>-eng，其次 -userdebug/-user。
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/fox_PGGM10.mk
