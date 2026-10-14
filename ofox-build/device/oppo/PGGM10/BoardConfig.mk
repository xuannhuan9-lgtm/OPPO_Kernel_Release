#
# OrangeFox / TWRP BoardConfig —— OPPO K10x 5G (PGGM10 / OP5295, SM6375 holi)
#
# 所有数值均来自本工作区 ofox-prep/ 下的实测镜像头与 twrp-probe/probe.txt，
# 不是抄别的机型猜的。逐条依据写在注释里，改之前请先读注释。
#
# 所属：device/oppo/PGGM10   （放进 <源码根>/device/oppo/PGGM10）
#

DEVICE_PATH := device/oppo/PGGM10

# ============================================================================
# 0. 兼容性开关
# ============================================================================
# 我们用的是 minimal manifest（只同步 TWRP/橙狐需要的那部分 AOSP），
# 很多 device 级依赖不存在，打开这个让编译不要把缺依赖当致命错误。
# （真实设备树 device_oppo_OP4F2F / device_xiaomi_mojito 都开了）
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true

# ============================================================================
# 1. 架构 —— SM6375(holi) 是 arm64，带 32 位支持（Android 14 已基本不用）
# ============================================================================
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
# holi 是 2×A78 + 6×A55（Kryo 660 派生），-runtime 这两项对性能有影响
TARGET_CPU_VARIANT_RUNTIME := cortex-a78
TARGET_CPU_VARIANT_RUNTIME_2 := cortex-a55

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_USES_64_BIT_BINDER := true
TARGET_SUPPORTS_64_BIT_APPS := true

# 只认这两个代号；刷错机型会直接拒绝。PGGM10=产品名，OP5295=ro.product.device
TARGET_OTA_ASSERT_DEVICE := PGGM10,OP5295

# 平台（probe.txt: ro.board.platform = holi）
TARGET_BOARD_PLATFORM := holi
BOARD_USES_QCOM_HARDWARE := true
# 高通 RTC 时间修正（恢复模式下读取 rtc，避免时间回到 1970）
TARGET_RECOVERY_QCOM_RTC_FIX := true

# ============================================================================
# 2. 内核 / boot 头 —— ★关键★  依据：解析 ofox-prep/boot_a.img
# ----------------------------------------------------------------------------
# boot_a.img 头（自解析，见 ofox-build/README.md「头解析依据」）：
#   magic            = "ANDROID!"        → 标准 Android boot image
#   kernel_size      = 48595008          (46.4 MB, 未压缩 Image)
#   ramdisk_size     = 21251696          (20.3 MB, gzip cpio，解压后 51.9 MB)
#   os_version       = 0x18000189        → Android 12.0.0 / patch 393
#   header_size      = 1580
#   header_version   = 3                 → ★v3，无 base/offset 字段★
#   cmdline          = 空               （cmdline 全在 vendor_boot 里）
#
# 为什么 BASE/OFFSET 是 0：boot header v3 起，base/offset/kernel_addr 这些
# 字段已经被删掉了（bootimg.h 里 v3 结构体根本没有它们），只有 v0~v2 需要
# 指定。参考真实 v3 设备树 device_xiaomi_mojito(holi 同代, header v3)：
#     BOARD_KERNEL_BASE := 0x00000000
# 所以这里写 0 是「正确」而不是「偷懒」。下面用 TARGET_PREBUILT_KERNEL +
# --header_version 3 的走法，header_version 是这里唯一真正重要的字段。
# ============================================================================
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_BOOT_HEADER_VERSION := 3

# v3 + GKI：内核是未压缩的 Image（不是 Image.gz），与 mojito prebuilt/Image 一致。
# ★dtbo 不再作为"要构建的镜像"★：我们不编译也不刷 dtbo（原厂 dtbo_a 保持不动，
#   最终方案只动 boot 分区）。设 true 会让构建系统去找 BOARD_PREBUILT_DTBOIMAGE，
#   而那个文件我们并不提供 ⇒ 直接改成 false。
#   （BOARD_DTBOIMG_PARTITION_SIZE 仍保留，只作为分区尺寸描述，不影响构建。）
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_KERNEL_SEPARATED_DTBO := false

# cmdline：直接照抄 ofox-prep/vendor_boot_a.img 里解析出来的实机 cmdline，
# 保证进 recovery 后 usb/console 行为与出厂一致。追加 selinux=permissive
# 方便调试（recovery 本来就是 permissive 语境，但显式写更稳）。
BOARD_KERNEL_CMDLINE := console=ttyMSM0,115200n8
BOARD_KERNEL_CMDLINE += earlycon=msm_geni_serial,0x04C8C000
BOARD_KERNEL_CMDLINE += androidboot.hardware=qcom
BOARD_KERNEL_CMDLINE += androidboot.console=ttyMSM0
BOARD_KERNEL_CMDLINE += androidboot.memcg=1
BOARD_KERNEL_CMDLINE += lpm_levels.sleep_disabled=1
BOARD_KERNEL_CMDLINE += video=vfb:640x400,bpp=32,memsize=3072000
BOARD_KERNEL_CMDLINE += msm_rtb.filter=0x237
BOARD_KERNEL_CMDLINE += service_locator.enable=1
# ★这个 usbcontroller 是从 vendor_boot_a.img 头里读出来的原机值★
# （本机是 4e00000.dwc3；别抄 mojito 的 a600000.dwc3，那是别的 SoC）
BOARD_KERNEL_CMDLINE += androidboot.usbcontroller=4e00000.dwc3
BOARD_KERNEL_CMDLINE += swiotlb=0
BOARD_KERNEL_CMDLINE += loop.max_part=7
BOARD_KERNEL_CMDLINE += cgroup.memory=nokmem,nosocket
BOARD_KERNEL_CMDLINE += iptable_raw.raw_before_defrag=1
BOARD_KERNEL_CMDLINE += ip6table_raw.raw_before_defrag=1
BOARD_KERNEL_CMDLINE += kpti=off
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive

# ---- prebuilt：直接放现成文件，CI 里由 workflow 下载（别 commit 进公开仓库）----
#   prebuilt/Image   ← /mnt/sdcard/123云盘/ofox-prep/Image
#                      48595008 字节 (46.3 MB)，arm64 Linux Image
#                      magic = 4d 5a 00 91 (ARM64 Image)，含魔数 "ARM\x64"
#                      从原厂 boot_a.img 偏移 4096 处精确切出
#   prebuilt/dtb.img ← /mnt/sdcard/123云盘/ofox-prep/dtb.img
#                      4607565 字节，FDT (magic d00dfeed)
#                      从原厂 vendor_boot_a.img 偏移 724992 处切出
#
# ★这两个文件属于原厂固件，不要直接 commit 进公开仓库★
#   推荐做法：放到 GitHub Release 资产里，由 workflow 用 wget 下载
#   （具体示例见 ofox-build/README.md「prebuilt 怎么给 CI」一节）
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image

# ★★ dtb 绝不进 boot 镜像 ★★（2026-10-14 真机 CI 报错后修正）
#   实测本机 boot 分区 = header(4096) + kernel(48595008) + ramdisk，
#   【里面没有 dtb】；dtb 在 vendor_boot 里（vendor_boot dtb_size = 4607565）。
#   所以必须显式关掉 DTB-in-bootimg，并且【绝对不能】设 BOARD_PREBUILT_DTBIMAGE_DIR：
#   AOSP build/make/core/board_config.mk:816 会直接报错
#     "BOARD_PREBUILT_DTBIMAGE_DIR with 'BOARD_INCLUDE_DTB_IN_BOOTIMG != true' is not supported."
#   （这就是 run #2/#3 卡在 lunch 的原因）
#   最终镜像由 tools/ofox-splice.py 把橙狐 ramdisk 拼进【原厂 boot 模板】得到，
#   原厂 kernel/header 逐字节保留，dtb 继续留在 vendor_boot —— 我们根本不碰它。
BOARD_INCLUDE_DTB_IN_BOOTIMG := false

# 以下三个一律不设（设了就会要求提供 dtb/dtbo 镜像，而我们不需要）：
#   TARGET_PREBUILT_DTB
#   BOARD_PREBUILT_DTBIMAGE_DIR
#   BOARD_PREBUILT_DTBOIMAGE
# 说明：prebuilt/dtb.img 仍可由 CI 下载备用（仅用于人工核对），但不参与构建。

# ★本机型是 GKI 分离式：recovery 的 ramdisk 要打成一个【独立 boot 镜像】，
# 之后由手机端 ofox-merge-and-flash.sh 合进原厂 boot 分区。
# 所以这里用 recoveryimage 目标（TARGET_NO_RECOVERY 不设！本机没有 recovery
# 分区，但我们要的正是「产出一个可合并的 recovery 镜像」，两者不冲突）。
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
# 注意：这里【故意不加 --dtb】。原厂 boot 镜像里没有 dtb（见上方说明），
# 加了会导致 boot 头里混进 dtb、与原厂布局不符；dtb 留在 vendor_boot 不动。

# ============================================================================
# 3. 分区尺寸 —— 依据：probe.txt /proc/partitions（1K 块）
#    boot      sde9  = 163840 KB = 160 MB
#    dtbo      sde13 =  24576 KB =  24 MB
#    vendor_boot sde19=163840 KB = 160 MB
#    super     sda14 = 10928128 KB ≈ 10.4 GB (11190403072)
# ============================================================================
BOARD_FLASH_BLOCK_SIZE := 131072          # 4096 * 32
BOARD_BOOTIMAGE_PARTITION_SIZE := 167772160        # 160M  boot_a
BOARD_DTBOIMG_PARTITION_SIZE := 25165824           # 24M   dtbo_a
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 167772160 # 160M  vendor_boot_a
# 注意：本机【没有】recovery 分区（probe.txt by-name 里确认无 recovery 项）。
# 下面这个尺寸只是给 recoveryimage 目标一个合法上限，不与任何真实分区对应。
#
# ★单分区双模式要点★：最终刷回的就是 boot 分区本身（160MB）。
#   实测合并产物约 66MB（kernel 46.4MB + 合并后 ramdisk 约 19.6MB），
#   远小于 160MB 分区，余量充足。
#   ofox-splice.py 会原样保留原厂 160MB 镜像的头部与布局，
#   只改头部 @12 的 ramdisk_size，所以产物对 aboot 是同构的。
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 167772160

BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_USES_MKE2FS := true

# ============================================================================
# 4. 文件系统
#    /data     = f2fs (inlinecrypt)   ← probe.txt: dm-50 f2fs ... inlinecrypt
#    /metadata = ext4
#    /cache    = 实际映射到 oplusreserve2 (ext4)，见 recovery.fstab
# ============================================================================
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_ODM := odm

# /data 用了 f2fs + inlinecrypt + 元数据加密（见 recovery.fstab 的 fileencryption=）
# 格式化时必须用 mke2fs/f2fs-tools 的新实现，否则 inlinecrypt 属性会丢。
# （别用老 make_ext4fs）
TARGET_USES_MKE2FS := true

# ============================================================================
# 5. 动态分区 (super = 10.4GB)
#    依据 probe.txt: super -> /dev/block/sda14, 11190403072 字节
#    组名与成员照抄 /vendor/etc/fstab.default 里的 logical 分区清单
# ============================================================================
BOARD_SUPER_PARTITION_SIZE := 11190403072
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 11190403072
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    vendor \
    product \
    odm \
    my_product \
    my_engineering \
    my_company \
    my_carrier \
    my_region \
    my_heytap \
    my_stock \
    my_preload \
    my_bigball \
    my_manifest

# ============================================================================
# 6. A/B
#    依据 probe.txt: ro.build.ab_update=true, slot_suffix=_a,
#                    boot_a/boot_b/vendor_boot_a/b/vbmeta_a/b 都在
#    注意：本机是「非 VAB (virtual A/B)」的传统 A/B，还是 VAB 取决于
#    ro.virtual_ab.enabled。probe 没直接给这项，所以下面不设
#    OF_VIRTUAL_AB_DEVICE（合并脚本也不依赖它）。
# ============================================================================
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor_boot

# ============================================================================
# 7. AVB / Verified Boot
#    状态：已解锁（ro.boot.flash.locked=0, verifiedbootstate=orange）
#    解锁状态下 vbmeta 校验被跳过，所以我们的 recovery 镜像自带 testkey 即可。
#    ⚠ 仍然不要动 vbmeta 分区本身（保持原厂），让橙色状态维持解锁。
# ============================================================================
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 1
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# ============================================================================
# 8. Recovery 目标形态 —— ★单分区双模式（Android 与橙狐共用 boot）★
# ----------------------------------------------------------------------------
# 本机【没有 recovery 分区】，原厂 recovery 就在 boot 分区的 ramdisk 里
# （ramdisk 含 system/bin/recovery、system/bin/phoenix_recovery、
#  etc/recovery.fstab、res/OplusOS/*，已实测确认）。
#
# ★做法：橙狐和 Android 共用同一个 boot 分区★
#   同一个 AOSP init 依据启动模式选择执行哪个 recovery：
#     - 平时开机（force_normal_boot=1）→ Android；
#     - `adb reboot recovery` / root 一键 → misc 的 BCB 通道 → 橙狐。
#
#   具体三步（工具在 ofox-tools/，CI 会调用）：
#     1) CI 编出橙狐的 ramdisk；
#     2) ofox-merge-ramdisk.py 把橙狐部件合并进【原厂 ramdisk】
#        —— 原厂为底，只白名单覆盖 recovery 相关文件，
#           init/linker/libc 等正常启动所需的全部保留原厂，
#           从根上避免「Android 14 原厂 vs 橙狐 libc 版本打架」；
#     3) ofox-splice.py 把新 ramdisk 拼回【原厂 boot 镜像】
#        —— 头部与布局逐字节沿用原厂（kernel 区原样照抄，只改头部
#           @12 的 ramdisk_size，ramdisk 偏移不变），
#           对 aboot 而言产物与原生镜像同构，风险最低。
#
# ★为什么必须用 fox_14.1 分支★
#   目标机是 Android 14，原厂 ramdisk 也是 Android 14 构建的。
#   橙狐必须用同代分支（fox_14.1），libc/linker/HAL 版本才对得上。
#   若 fox_14.1 不可用而退到 fox_12.1，版本冲突风险显著上升
#   （详见 README「风险」一节）。
#
# 因此这里【故意不设】TARGET_NO_RECOVERY / BOARD_USES_RECOVERY_AS_BOOT：
# 让 AOSP 正常吐出 recovery.img（内含橙狐 ramdisk），CI 再从中解出
# ramdisk 交给合并工具。
# ============================================================================

TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888

# /sdcard（内部存储）挂在 /data 上 —— 本机没有独立的 /sdcard 分区。
# ★注意★：/data 是 FBE 加密且大概率解不开（见第 9 节），
# 所以这条开着也只是"数据能解开时内部存储可用"，解不开时 /sdcard 会挂不上，
# 属预期现象。打开它是为了在能解密的情况下让橙狐正常识别内部存储。
RECOVERY_SDCARD_ON_DATA := true

# ============================================================================
# 9. 加密 —— ★FBE 大概率解不开 /data，务必看清★
# ----------------------------------------------------------------------------
# 实测：ro.crypto.state=encrypted, ro.crypto.type=file,
#       /data f2fs + inlinecrypt, metadata_encryption=aes-256-xts:wrappedkey_v0,
#       keydirectory=/metadata/vold/metadata_encryption
#
# 这是「元数据加密 + wrapped key + Qualcomm ICE(inlinecrypt)」的组合。
# TWRP/橙狐 要解开它需要：
#   1) 正确的 keymaster/gatekeeper HAL（Qualcomm 闭源，通常要从原厂取 blob）；
#   2) 内核 ICE 驱动 + wrapped key 支持；
#   3) 与 ColorOS 14 版本匹配的 metadata 解密实现。
# 三者齐了才可能解开。所以：**打开开关是为了让代码编进去、有尝试的机会，
# 不代表一定能解开**。解不开时 /data 会显示为 0 或挂载失败，这是预期行为，
# 不代表 recovery 坏了。
# ============================================================================
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
BOARD_USES_METADATA_PARTITION := true
# 元数据加密：/metadata = ext4（probe 实测），告诉 recovery 去这里找 key
TW_INCLUDE_FBE_METADATA_DECRYPT := true

# 兼容性 / 安全
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2127-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# ============================================================================
# 10. TWRP / 橙狐 UI 与行为
#     K10x 5G：1080x2412 屏（probe「屏幕 480」是 density 的 dpi 值，不是分辨率；
#     2412 高度按同代 OPPO 机型惯例取，进 recovery 后可再调 OF_SCREEN_H）
# ============================================================================
TW_THEME := portrait_hdpi
TW_EXTRA_LANGUAGES := true
TW_USE_TOOLBOX := true
TW_INCLUDE_REPACKTOOLS := true
TW_EXCLUDE_APEX := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_RESETPROP := true
TW_SUPPORT_INPUT_AIDL_HAPTICS := true
TW_NO_SCREEN_BLANK := true
TW_SCREEN_BLANK_ON_BOOT := true
TW_DEFAULT_LANGUAGE := zh_CN

# 背光路径：高通通用节点（原厂 init.recovery.qcom.rc 里写的是
# /sys/class/backlight/panel0-backlight/brightness，见 ofox-prep/init.recovery.qcom.rc）
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 900

# ★安全擦除抑制★：本机是 f2fs + 元数据加密，secure erase 会把加密元数据抹掉，
# 导致解锁后的机器再也读不回原数据。必须抑制。
BOARD_SUPPRESS_SECURE_ERASE := true

# ============================================================================
# 11. 调试
# ============================================================================
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true

# ---------------------------------------------------------------------------
# TWRP 版本串（设置里显示的版本）
#   TWRP 主版本由源码决定：variables.h 里 TW_MAIN_VERSION_STR = "3.7.1_14"
#   最终版本串 = TW_MAIN_VERSION_STR + TW_DEVICE_VERSION
#   ⇒ 本机将显示  3.7.1_14-PGGM10
# ---------------------------------------------------------------------------
TW_DEVICE_VERSION := -PGGM10


# ============================================================================
# 12. 端口/依赖（QCOM 平台）
# ============================================================================
TARGET_RECOVERY_DEVICE_MODULES += \
    libion \
    libdisplayconfig.qti \
    vendor.display.config@1.0 \
    vendor.display.config@2.0
