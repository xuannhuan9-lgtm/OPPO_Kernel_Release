#!/usr/bin/env python3
"""
从 vendor_boot 镜像里抽出 dtb 段。

用法: extract_vendor_boot_dtb.py <vendor_boot.img> <输出 dtb 路径>

依据本机 ofox-prep/vendor_boot_a.img 实测的 vendor_boot header v3 布局：
    magic[8]="VNDRBOOT" header_version(u32) page_size(u32)
    kernel_addr(u32) ramdisk_addr(u32) vendor_ramdisk_size(u32)
    cmdline[2048] tags_addr(u32) name[16] header_size(u32)
    dtb_size(u32) dtb_addr(u64)
  dtb 偏移 = align(header_size) + align(vendor_ramdisk_size)

本机实测值: page_size=4096 vendor_ramdisk_size=718853 header_size=2112
            dtb_size=4607565 dtb_addr=0x1f00000
"""
import struct
import sys
import os


def align(x, p):
    return (x + p - 1) // p * p


def main():
    if len(sys.argv) != 3:
        print("用法: %s <vendor_boot.img> <输出 dtb 路径>" % sys.argv[0], file=sys.stderr)
        return 2

    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        h = f.read(2112)

    if h[:8] != b"VNDRBOOT":
        print("::error::%s 不是 vendor_boot 镜像 (magic=%r)" % (src, h[:8]))
        return 1

    page_size = struct.unpack("<I", h[12:16])[0]
    vendor_ramdisk_size = struct.unpack("<I", h[24:28])[0]
    header_size = struct.unpack("<I", h[2096:2100])[0]
    dtb_size = struct.unpack("<I", h[2100:2104])[0]

    print("page_size=%d vendor_ramdisk_size=%d header_size=%d dtb_size=%d"
          % (page_size, vendor_ramdisk_size, header_size, dtb_size))

    offset = align(header_size, page_size) + align(vendor_ramdisk_size, page_size)
    print("dtb 偏移 = %d" % offset)

    with open(src, "rb") as f, open(dst, "wb") as o:
        f.seek(offset)
        o.write(f.read(dtb_size))

    size = os.path.getsize(dst)
    print("已写出 dtb: %s (%d 字节)" % (dst, size))

    # FDT magic 校验
    with open(dst, "rb") as f:
        magic = f.read(4)
    if magic != b"\xd0\x0d\xfe\xed":
        print("::error::dtb magic 不是 d00dfeed (实际 %s)" % magic.hex())
        return 1
    print("FDT magic 校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
