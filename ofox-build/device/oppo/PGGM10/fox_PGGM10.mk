#
# OrangeFox 产品定义 —— OPPO K10x 5G (PGGM10 / OP5295)
#
# 这是 lunch 的目标：fox_PGGM10-eng
#
# ⚠ 关于 OF_* 开关放哪：真实橙狐设备树里，OF_* / FOX_* 是【环境变量】，
#   由 vendorsetup.sh 在 lunch 之前 export，而不是写在 .mk 里。
#   本文件负责「产品身份 + 继承」，OF_* 开关见同目录 vendorsetup.sh。
#

# 继承基础产品
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# 继承本设备
$(call inherit-product, device/oppo/PGGM10/device.mk)

# ===========================================================================
# 继承橙狐 / TWRP 公共配置
#
# 三种源码树，路径不一样，必须按存在性判断，否则 inherit-product 会
# 指向不存在的文件、直接 $(error) 让 lunch 挂掉：
#
#   A) 橙狐完整 manifest (gitlab) → vendor/fox/config/common.mk 存在
#   B) minimal-manifest-twrp     → 只有 vendor/twrp/config/common.mk
#   C) 两者都没有（极小 manifest）→ 走下面的内置最小兜底
#
# ★注意★ 原来的写法是错的：
#     -include vendor/fox/config/common.mk          ← -include 对 .mk 无效
#     ifeq ($(wildcard vendor/fox/config/common.mk),)
#     $(call inherit-product, vendor/twrp/config/common.mk)   ← 没查存在性
#   -include 只是 GNU make 的语法，Android 的 inherit-product 不认；
#   而第二条没做 wildcard 检查，C) 情况下会去 inherit 一个不存在的文件。
# ===========================================================================
ifeq ($(wildcard vendor/fox/config/common.mk),)
  ifeq ($(wildcard vendor/twrp/config/common.mk),)
    # ---- C) 内置最小兜底 ----
    # 不走任何 vendor common.mk，自己把 recovery 必需的东西钉住。
    # 这样即使是极小 manifest 也能 lunch 成功、编出 recovery.img。
    $(info [fox_PGGM10] vendor/fox 与 vendor/twrp 的 common.mk 都不存在，启用内置最小配置)

    PRODUCT_PACKAGES += \
        recovery \
        twrp

    # TWRP 的核心：这些标志告诉 build/make 生成 recovery 相关目标
    TARGET_RECOVERY_UI_LIB := librecovery_ui_default

    # recovery 的基本属性
    PRODUCT_PROPERTY_OVERRIDES += \
        ro.twrp.version=builtin-fallback \
        ro.recovery.version=builtin-fallback
  else
    # ---- B) minimal-manifest-twrp ----
    $(info [fox_PGGM10] 使用 vendor/twrp/config/common.mk)
    $(call inherit-product, vendor/twrp/config/common.mk)
  endif
else
  # ---- A) 橙狐完整源 ----
  $(info [fox_PGGM10] 使用 vendor/fox/config/common.mk)
  $(call inherit-product, vendor/fox/config/common.mk)
endif

# ---------------------------------------------------------------------------
# 产品身份
#   实测：ro.product.name=PGGM10  ro.product.device=OP5295  ro.product.model=PGGM10
# ---------------------------------------------------------------------------
PRODUCT_DEVICE := PGGM10
PRODUCT_NAME := fox_PGGM10
PRODUCT_BRAND := OPPO
PRODUCT_MODEL := PGGM10
PRODUCT_MANUFACTURER := OPPO
PRODUCT_BOARD := holi
PRODUCT_PLATFORM := holi

# API 级别：Android 14
PRODUCT_SHIPPING_API_LEVEL := 34

# ★PRODUCT_TARGET_VNDK_VERSION 只在 A12+ 的 build/make 里生效★
# TWRP 12.1 没有这个变量也没关系（赋值不存在的变量不会报错，只是无效），
# 但为稳妥起见只在新版本上设。
ifeq ($(shell test -f build/make/core/version_util.mk && echo ok),ok)
PRODUCT_TARGET_VNDK_VERSION := 34
endif

# 认领备用代号（OTA/assert 用）
PRODUCT_DEVICE_ALT := OP5295
PRODUCT_MODEL_ALT := OP5295

PRODUCT_PROPERTY_OVERRIDES += \
    ro.twrp.target.devices=PGGM10,OP5295
