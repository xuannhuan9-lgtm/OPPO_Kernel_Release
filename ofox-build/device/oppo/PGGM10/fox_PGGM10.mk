#
# OrangeFox 产品定义 —— OPPO K10x 5G (PGGM10 / OP5295)
#
# 这是 lunch 的目标：fox_PGGM10-eng
#
# ⚠ 关于 OF_* 开关放哪：真实橙狐设备树里，OF_* / FOX_* 是【环境变量】，
#   由 vendorsetup.sh 在 lunch 之前 export，而不是写在 .mk 里。
#   本文件负责「产品身份 + 继承」，OF_* 开关见同目录 vendorsetup.sh。
#   （这里额外用一个保险的 PRODUCT_PACKAGES 把橙狐必需的目标钉住。）
#

# 继承基础产品
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# 继承本设备
$(call inherit-product, device/oppo/PGGM10/device.mk)

# 继承橙狐/TWRP 公共配置。
# ⚠ 这两条二选一，取决于你同步的是哪套源码：
#   - 橙狐完整 manifest  → vendor/twrp/config/common.mk 与 vendor/fox/config/common.mk 都有
#   - minimal-manifest-twrp → 只有 vendor/twrp/config/common.mk
# 优先用 fox 的（橙狐专属开关多），没有就退回 twrp 的；
# 用 -include 而不是 include，缺文件时不会直接炸，便于 CI 排错。
-include vendor/fox/config/common.mk
ifeq ($(wildcard vendor/fox/config/common.mk),)
$(call inherit-product, vendor/twrp/config/common.mk)
endif

# ---------------------------------------------------------------------------
# 产品身份
#   实测：ro.product.name=PGGM10  ro.product.device=OP5295  ro.product.model=PGGM10
#   橙狐侧统一用 PGGM10 作 PRODUCT_DEVICE，同时把 OP5295 作为 alt 认领，
#   这样刷入后 assert 两种代号都能过。
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
PRODUCT_TARGET_VNDK_VERSION := 34

# 认领备用代号（OTA/assert 用）
PRODUCT_DEVICE_ALT := OP5295
PRODUCT_MODEL_ALT := OP5295

# 让 recovery 里 ro.product.device 是 PGGM10，但接受 OP5295 的 OTA 包
PRODUCT_PROPERTY_OVERRIDES += \
    ro.twrp.target.devices=PGGM10,OP5295
