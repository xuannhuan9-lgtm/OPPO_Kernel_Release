#!/bin/bash
#
# extract-files.sh —— 从原厂系统里抽取 recovery 需要的闭源 blob
#
# ⚠ 这不是必须的：不做 /data 解密的话，橙狐不需要任何厂商 blob 也能起来。
#    只有当你想要「解开 FBE / 正常显示电量 / 振动 / 快充界面」时才需要它。
#
# 用法（在电脑上，手机已用 USB 连上且 adb 可用）：
#     ./extract-files.sh
# 产物：device/oppo/PGGM10/proprietary/  (配合 proprietary-files.txt)
#
# ★注意★：本机是 ColorOS 14 + Android 14，很多 blob 在动态分区里，
# adb pull 需要用 /system、/vendor 的挂载路径（不是块设备）。
#

set -e

DEVICE_PATH="device/oppo/PGGM10"
PROPRIETARY_PATH="${DEVICE_PATH}/proprietary"
FILES_LIST="${DEVICE_PATH}/proprietary-files.txt"

if [ -z "$ANDROID_BUILD_TOP" ]; then
    echo "错误：请先在源码树里 source build/envsetup.sh 并 lunch fox_PGGM10-eng" >&2
    exit 1
fi

if [ ! -f "$FILES_LIST" ]; then
    echo "错误：找不到 $FILES_LIST" >&2
    exit 1
fi

echo "==> 检查 adb"
if ! command -v adb >/dev/null 2>&1; then
    echo "错误：找不到 adb 命令" >&2
    exit 1
fi

adb get-state >/dev/null 2>&1 || { echo "错误：adb 连不上设备" >&2; exit 1; }

mkdir -p "$PROPRIETARY_PATH"

echo "==> 开始抽取（行首带 - 的是从 vendor 取，否则从 system 取）"
while read -r line; do
    # 跳过注释与空行
    case "$line" in
        ''|'#'*) continue ;;
    esac

    if [ "${line#-}" != "$line" ]; then
        SRC="vendor/${line#-}"
    else
        SRC="system/$line"
    fi

    DST="${PROPRIETARY_PATH}/${SRC}"
    mkdir -p "$(dirname "$DST")"

    printf '  %-70s' "$SRC"
    if adb pull "/$SRC" "$DST" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "缺失（可忽略，若不影响功能）"
    fi
done < "$FILES_LIST"

echo
echo "==> 完成。产物在 $PROPRIETARY_PATH"
echo "    接着可以用 extract_utils 生成 Android.mk / .bp（可选）"
