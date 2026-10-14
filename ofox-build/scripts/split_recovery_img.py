#!/usr/bin/env python3
"""
把 CI 编出来的 recovery.img 拆成三个文件，供手机端合并脚本使用：
    recovery-kernel       内核段
    recovery-ramdisk.gz   ramdisk 段（原始 gz）
    recovery-ramdisk.cpio ramdisk 解压后的 cpio（可选，失败则跳过）

用法: split_recovery_img.py <recovery.img> <输出目录>

为什么要拆：手机端 ofox-merge-and-flash.sh 需要「橙狐的 ramdisk」。
给出拆好的段能让手机端少一步解析、少一个出错点；同时保留完整
recovery.img 作为 magiskboot 走法的输入。
"""
import gzip
import hashlib
import os
import struct
import sys


def parse_v3(h):
    kernel_size, ramdisk_size = struct.unpack("<2I", h[8:16])
    header_size = struct.unpack("<I", h[20:24])[0]
    header_version = struct.unpack("<I", h[40:44])[0]
    cmdline = h[44:44 + 1536].split(b"\0")[0]
    return header_version, kernel_size, ramdisk_size, header_size, cmdline


def parse_v012(h):
    kernel_size, _kaddr, ramdisk_size, _raddr = struct.unpack("<4I", h[8:24])
    header_size = 1632
    cmdline = h[64:64 + 512].split(b"\0")[0]
    return 0, kernel_size, ramdisk_size, header_size, cmdline


def main():
    if len(sys.argv) != 3:
        print("用法: %s <recovery.img> <输出目录>" % sys.argv[0], file=sys.stderr)
        return 2

    img, outdir = sys.argv[1], sys.argv[2]
    with open(img, "rb") as f:
        h = f.read(4096)

    if h[:8] != b"ANDROID!":
        print("::warning::%s 不是 ANDROID! 镜像，跳过拆分" % img)
        return 0

    ver, ksz, rsz, hsz, cmd = parse_v3(h)
    if not (1024 <= hsz <= 65536) or rsz > 512 * 1024 * 1024:
        print("::notice::v3 解析不合理，回退 v0-v2 布局")
        ver, ksz, rsz, hsz, cmd = parse_v012(h)

    print("header_version=%d kernel_size=%d ramdisk_size=%d header_size=%d"
          % (ver, ksz, rsz, hsz))
    print("cmdline=%s" % cmd.decode(errors="replace").strip())

    page = 4096

    def align(x):
        return (x + page - 1) // page * page

    koff = align(hsz)
    roff = koff + align(ksz)

    with open(img, "rb") as f:
        if ksz > 0:
            f.seek(koff)
            kdata = f.read(ksz)
            kpath = os.path.join(outdir, "recovery-kernel")
            with open(kpath, "wb") as o:
                o.write(kdata)
            print("写出 recovery-kernel: %d 字节" % len(kdata))

        f.seek(roff)
        rdata = f.read(rsz)
        rpath = os.path.join(outdir, "recovery-ramdisk.gz")
        with open(rpath, "wb") as o:
            o.write(rdata)
        print("写出 recovery-ramdisk.gz: %d 字节" % len(rdata))
        print("sha256(ramdisk) = %s" % hashlib.sha256(rdata).hexdigest())

    try:
        raw = gzip.decompress(rdata)
        cpath = os.path.join(outdir, "recovery-ramdisk.cpio")
        with open(cpath, "wb") as o:
            o.write(raw)
        print("解压出 cpio: %d 字节" % len(raw))
    except Exception as e:
        print("::warning::cpio 解压失败 (%s)，只保留 .gz" % e)

    return 0


if __name__ == "__main__":
    sys.exit(main())
