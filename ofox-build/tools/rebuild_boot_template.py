#!/usr/bin/env python3
"""
重建 boot 模板（原厂 boot_a.img 的前 48603136 字节）。

用法: rebuild_boot_template.py <boot-header.bin> <Image> <输出路径>

原理（已实测验证）：
    原厂 boot_a.img 的前 48603136 字节 =
        boot-header.bin (4096 字节, 原厂头部)
      + Image          (48595008 字节, 原厂内核)
      + 4032 个零字节   (填充到 48603136)

  48603136 = align(4096, 4096) + align(48595008, 4096)
           = 4096 + 48599040

  这就是 ofox-splice.py 需要的「拼装模板」：它只读 stock 的
  头部 + kernel 区，然后接上新 ramdisk。
  因为模板里不需要原厂 ramdisk，所以不必上传 160MB 的 boot_a.img。
"""
import os
import sys

HEADER_SIZE = 4096
EXPECT_KERNEL = 48595008
EXPECT_TOTAL = 48603136


def main():
    if len(sys.argv) != 4:
        print("用法: %s <boot-header.bin> <Image> <输出路径>" % sys.argv[0], file=sys.stderr)
        return 2

    hdr_path, img_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    hdr = open(hdr_path, "rb").read()
    img = open(img_path, "rb").read()

    print("boot-header.bin : %d 字节" % len(hdr))
    print("Image           : %d 字节" % len(img))

    if len(hdr) != HEADER_SIZE:
        print("::error::boot-header.bin 应为 %d 字节，实际 %d" % (HEADER_SIZE, len(hdr)))
        return 1
    if hdr[:8] != b"ANDROID!":
        print("::error::boot-header.bin 开头不是 ANDROID! (magic=%r)" % hdr[:8])
        return 1
    if len(img) != EXPECT_KERNEL:
        print("::warning::Image 大小 %d 与预期 %d 不同（仍按实际大小拼接）"
              % (len(img), EXPECT_KERNEL))

    # 头部里的 kernel_size 必须与实际 Image 大小一致，否则模板不自洽
    import struct
    ks = struct.unpack_from("<I", hdr, 8)[0]
    if ks != len(img):
        print("::error::头部声明 kernel_size=%d，但 Image 实际 %d 字节，不自洽"
              % (ks, len(img)))
        return 1

    pad = (-(HEADER_SIZE + len(img))) % 4096
    print("填充 %d 个零字节" % pad)

    out = hdr + img + b"\x00" * pad
    open(out_path, "wb").write(out)

    print("重建模板: %s (%d 字节)" % (out_path, len(out)))
    if len(out) == EXPECT_TOTAL:
        print("::notice::✓ 大小与原厂一致 (%d)" % EXPECT_TOTAL)
    return 0


if __name__ == "__main__":
    sys.exit(main())
