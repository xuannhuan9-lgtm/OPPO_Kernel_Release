#!/usr/bin/env python3
"""
从 Android boot 镜像里抽出内核段。

用法: extract_boot_kernel.py <boot.img> <输出路径>

依据本机 ofox-prep/boot_a.img 实测的 boot header v3 布局：
    magic[8] kernel_size(u32) ramdisk_size(u32) os_version(u32) header_size(u32)
    reserved[16] header_version(u32) cmdline[1536] ...
  kernel 偏移 = align(header_size, page_size)
"""
import struct
import sys
import os

PAGE_SIZE = 4096


def align(x, p=PAGE_SIZE):
    return (x + p - 1) // p * p


def main():
    if len(sys.argv) != 3:
        print("用法: %s <boot.img> <输出路径>" % sys.argv[0], file=sys.stderr)
        return 2

    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        h = f.read(4096)

    if h[:8] != b"ANDROID!":
        print("::error::%s 不是 Android boot 镜像 (magic=%r)" % (src, h[:8]))
        return 1

    kernel_size = struct.unpack("<I", h[8:12])[0]
    ramdisk_size = struct.unpack("<I", h[12:16])[0]
    header_size = struct.unpack("<I", h[20:24])[0]
    header_version = struct.unpack("<I", h[40:44])[0]

    print("header_version=%d kernel_size=%d ramdisk_size=%d header_size=%d"
          % (header_version, kernel_size, ramdisk_size, header_size))

    offset = align(header_size)
    with open(src, "rb") as f, open(dst, "wb") as o:
        f.seek(offset)
        o.write(f.read(kernel_size))

    size = os.path.getsize(dst)
    print("已写出内核: %s (%d 字节)" % (dst, size))
    if size != kernel_size:
        print("::error::写出大小与头部声明不符 (%d != %d)" % (size, kernel_size))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
