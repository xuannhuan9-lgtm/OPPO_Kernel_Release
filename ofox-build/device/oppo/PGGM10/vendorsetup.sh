#
# OPPO K10x 5G (PGGM10) —— 橙狐构建开关
#
# 这个文件由 lunch 自动 source，橙狐的 OF_* / FOX_* 开关都写在这里。
# 每个开关后面都写了它的作用，改之前先读。
#
# 结构照抄真实设备树（device_xiaomi_mojito / beryllium 的 fox_12.1 分支）。
#

FDEVICE="PGGM10"

fox_get_target_device() {
    local chkdev=$(echo "$BASH_SOURCE" | grep -w $FDEVICE)
    if [ -n "$chkdev" ]; then
        FOX_BUILD_DEVICE="$FDEVICE"
    else
        chkdev=$(set | grep BASH_ARGV | grep -w $FDEVICE)
        [ -n "$chkdev" ] && FOX_BUILD_DEVICE="$FDEVICE"
    fi
}

if [ -z "$1" -a -z "$FOX_BUILD_DEVICE" ]; then
    fox_get_target_device
fi

if [ "$1" = "$FDEVICE" -o "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then

    # ========================================================================
    # A. 基本环境
    # ========================================================================
    # 中文界面（橙狐自带多语言，zh_CN 是完整的）
    export TW_DEFAULT_LANGUAGE="zh_CN"
    export LC_ALL="C"
    # minimal manifest 下允许缺依赖，否则编不过
    export ALLOW_MISSING_DEPENDENCIES=true
    # 橙狐构建日志（CI 里方便排错）
    export FOX_BUILD_LOG_FILE="$PWD/fox_build.log"

    # 认领代号：主 PGGM10，备用 OP5295
    export TARGET_DEVICE_ALT="OP5295"
    export OF_TARGET_DEVICES="PGGM10,OP5295"

    # ========================================================================
    # B. ★本机型最关键的几个开关★
    # ========================================================================

    # 本机【没有 recovery 分区】，原厂 recovery 在 boot 的 ramdisk 里。
    # 橙狐要能正常工作，必须知道自己是「boot 里的 recovery」而不是独立分区。
    # 打开这个让橙狐走 recovery-in-boot 的挂载/查找逻辑。
    export OF_USE_TWRP_RECOVERY_IMAGE_BUILDER=1

    # magiskboot：橙狐打补丁（给 boot 装 Magisk、修 vbmeta）用的工具。
    # ★本机依赖它★，因为手机端 ofox-merge-and-flash.sh 也要用同样的
    # unpack/repack 逻辑把 ramdisk 合进原厂 boot，两边行为保持一致。
    export OF_USE_MAGISKBOOT=1
    export OF_USE_MAGISKBOOT_FOR_ALL_PATCHES=1
    export OF_USE_NEW_MAGISKBOOT=1

    # ★vbmeta 处理★ 本机已解锁（ro.boot.flash.locked=0 / verifiedbootstate=orange），
    # 解锁态下 vbmeta 校验被 bootloader 跳过，不需要再打补丁。
    # 保持 1 是橙狐默认行为（打补丁时同步处理 vbmeta header），
    # 但我们的合并脚本【不写 vbmeta 分区】，所以这里开着也无害。
    export OF_PATCH_VBMETA_FLAG="1"
    export OF_PATCH_AVB20=1

    # ========================================================================
    # C. 加密相关 —— 见 BoardConfig.mk 第 9 节的详细说明
    #    ★FBE 大概率解不开 /data★，这里的开关只是让代码行为合理，不是解锁保证
    # ========================================================================

    # 不要自动给「已加密的设备」打补丁：避免把 f2fs+inlinecrypt 的元数据搞坏
    export OF_DONT_PATCH_ENCRYPTED_DEVICE=1
    # 保留强制加密标志，防止恢复后 Android 把 /data 当成明文重新初始化
    export OF_KEEP_FORCED_ENCRYPTION=1
    # 本机确定不是 MIUI（ColorOS 14），关掉 MIUI 专属逻辑，避免误判
    export OF_DISABLE_MIUI_SPECIFIC_FEATURES=1
    export OF_NO_MIUI_PATCH_WARNING=1
    export OF_DISABLE_MIUI_OTA_BY_DEFAULT=1
    # 纯 AOSP 风格构建（不做 MIUI 兼容 hack）
    export OF_VANILLA_BUILD=1

    # ========================================================================
    # D. 动态分区
    #    super = 11190403072 字节（probe.txt 实测），与 BoardConfig 一致
    # ========================================================================
    export OF_DYNAMIC_FULL_SIZE=11190403072
    # 逻辑分区挂不上时不要中止（本机 logical 分区很多，含一堆 my_* 分区）
    export OF_IGNORE_LOGICAL_MOUNT_ERRORS=1

    # ========================================================================
    # E. 分区路径（recovery 内部用）
    #    本机是动态分区，system/vendor 实体在 /dev/block/mapper/
    # ========================================================================
    export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
    export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"

    # ========================================================================
    # F. 常用工具（塞进 recovery 的 busybox/二进制）
    # ========================================================================
    export FOX_USE_BASH_SHELL=1
    export FOX_ASH_IS_BASH=1
    export FOX_USE_NANO_EDITOR=1
    export FOX_USE_TAR_BINARY=1
    export FOX_USE_ZIP_BINARY=1
    export FOX_USE_SED_BINARY=1
    export FOX_USE_XZ_UTILS=1
    export FOX_REPLACE_BUSYBOX_PS=1
    export OF_ENABLE_LPTOOLS=1
    export FOX_DELETE_AROMAFM=1
    export FOX_ENABLE_APP_MANAGER=1
    export OF_NO_TREBLE_COMPATIBILITY_CHECK=1

    # 兼容 AOSP 某段时间的 ARB 时间戳 bug（真实设备树通用做法）
    export FOX_BUGGED_AOSP_ARB_WORKAROUND="1616300800"

    # f2fs 修复/格式化前先解绑 /sdcard，避免 f2fs.fsck 报错
    export OF_UNBIND_SDCARD_F2FS=1

    # 快捷备份列表：本机没有 recovery 分区，不列 recovery
    export OF_QUICK_BACKUP_LIST="/boot;/data;/vendor_boot;"

    # ========================================================================
    # G. 屏幕（K10x 5G，1080x2412，density 480）
    #    进 recovery 后如果状态栏位置不对，调这几个值重编
    # ========================================================================
    export OF_SCREEN_H=2412
    export OF_STATUS_H=100
    export OF_STATUS_INDENT_LEFT=48
    export OF_STATUS_INDENT_RIGHT=48
    export OF_HIDE_NOTCH=1
    export OF_CLOCK_POS=1
    export OF_ALLOW_DISABLE_NAVBAR=0

    # ========================================================================
    # H. 版本信息
    # ========================================================================
    export FOX_VERSION="R11.1_1"
    export FOX_BUILD_TYPE="Unofficial"
    export OF_MAINTAINER="K10x"

    # ---- 构建变量落盘（排错用，真实设备树都有这段）----
    if [ -n "$FOX_BUILD_LOG_FILE" -a -f "$FOX_BUILD_LOG_FILE" ]; then
        export | grep "FOX" >> $FOX_BUILD_LOG_FILE
        export | grep "OF_" >> $FOX_BUILD_LOG_FILE
        export | grep "TARGET_" >> $FOX_BUILD_LOG_FILE
        export | grep "TW_" >> $FOX_BUILD_LOG_FILE
    fi
fi
