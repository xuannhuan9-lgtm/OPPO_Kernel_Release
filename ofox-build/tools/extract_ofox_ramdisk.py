#!/usr/bin/env python3
"""
从 CI 编出的橙狐 recovery.img 里解出 ramdisk。

用法: extract_ofox_ramdisk.py <recovery.img> <输出 ramdisk.gz>

依据 boot header v3 布局（本机原厂 boot_a 实测）：
    kernel_size@8  ramdisk_size@12  header_size@20  header_version@40
    ramdisk 偏移 = align(header_size,4096) + align(kernel_size,4096)
"""
import gzip
import io
import struct
import sys


def align(x, p=4096):
    return (x + p - 1) // p * p


def main():
    if len(sys.argv) != 3:
        print("用法: %s <recovery.img> <输出 ramdisk.gz>" % sys.argv[0], file=sys.stderr)
        return 2

    img, out = sys.argv[1], sys.argv[2]
    b = open(img, "rb").read()

    if b[:8] != b"ANDROID!":
        print("::error::%s 不是 Android boot 镜像 (magic=%r)" % (img, b[:8]))
        return 1

    ks = struct.unpack_from("<I", b, 8)[0]
    rs = struct.unpack_from("<I", b, 12)[0]
    hsz = struct.unpack_from("<I", b, 20)[0]

    ro = align(hsz) + align(ks)
    rd = b[ro:ro + rs]

    if rd[:2] != b"\x1f\x8b":
        print("::error::ramdisk 段不是 gzip (magic=%s)" % rd[:2].hex())
        return 1

    open(out, "wb").write(rd)

    head = gzip.GzipFile(fileobj=io.BytesIO(rd)).read(6)
    print("橙狐 ramdisk: %d 字节 (偏移 %d)" % (len(rd), ro))
    print("解压后首 6 字节: %r" % head)

    if head != b"070701":
        print("::error::解压后不是 newc cpio")
        return 1
    print("✓ ramdisk 格式确认（gzip + newc cpio）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
