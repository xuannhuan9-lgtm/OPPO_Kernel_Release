#
# OPPO K10x 5G (PGGM10 / OP5295) —— device.mk
#
# 只放「产品级别的包与服务」，开关类环境变量在 vendorsetup.sh。
#

LOCAL_PATH := device/oppo/PGGM10

# ---------------------------------------------------------------------------
# A/B + 动态分区
#   实测：ro.build.ab_update=true、ro.boot.dynamic_partitions=true
# ---------------------------------------------------------------------------
PRODUCT_USE_DYNAMIC_PARTITIONS := true
AB_OTA_UPDATER := true
ENABLE_VIRTUAL_AB := true
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

PRODUCT_SHIPPING_API_LEVEL := 34

# ---------------------------------------------------------------------------
# fastbootd（recovery 里的用户态 fastboot，刷动态分区要用）
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    fastbootd \
    android.hardware.fastboot@1.0-impl-mock

# ---------------------------------------------------------------------------
# bootctl / update_engine：A/B 切换槽位、OTA 用
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.boot@1.1-impl-qti.recovery

PRODUCT_PACKAGES_DEBUG += \
    bootctl \
    update_engine_client

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

# ---------------------------------------------------------------------------
# 高通解密（★不保证能解开 /data，见 BoardConfig 第 9 节★）
#   这两个是 TWRP 侧的 qcom FBE 解密实现。
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    qcom_decrypt \
    qcom_decrypt_fbe

# ---------------------------------------------------------------------------
# recovery 需要的额外库
#   本机 recovery 里原厂带了 librecovery_updater.so、
#   vendor.oplus.hardware.commondcs / fido 等（见 boot ramdisk 清单）。
#   橙狐自身需要下面这些显示/图形相关库才能出画面。
# ---------------------------------------------------------------------------
# ★注意★ 这里加的模块如果源码树里不存在，make 会直接报
#   "ninja: error: unknown target ..." 或 "No rule to make target"
# 而失败。twrp_minimal 这种精简 manifest 里【没有】QTI 的私有库
# （libdisplayconfig.qti / vendor.display.config@* 都来自 vendor/qcom）。
# 所以按存在性逐一决定要不要加，避免"因为少一个可选库而整个编译挂掉"。
TARGET_RECOVERY_DEVICE_MODULES += libion

ifneq ($(wildcard vendor/qcom/opensource/display),)
TARGET_RECOVERY_DEVICE_MODULES += \
    libdisplayconfig.qti \
    vendor.display.config@1.0 \
    vendor.display.config@2.0

RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES)/vendor.display.config@1.0.so \
    $(TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES)/vendor.display.config@2.0.so \
    $(TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES)/libdisplayconfig.qti.so
else
$(warning [PGGM10] 没找到 vendor/qcom/opensource/display，跳过 QTI 显示库（recovery 用默认 gralloc 渲染）)
endif

RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libion.so

# ---------------------------------------------------------------------------
# 属性
# ---------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.twrp.target.devices=PGGM10,OP5295 \
    ro.hardware=qcom \
    ro.board.platform=holi \
    ro.boot.dynamic_partitions=true \
    ro.adb.secure=0

# ---------------------------------------------------------------------------
# 语言
# ---------------------------------------------------------------------------
PRODUCT_LOCALES := zh_CN,en_US
