#!/usr/bin/env python3
"""
严格校验合并产物 boot-ofox.img：必须是合法 boot 镜像、与原厂同构、大小合规。

用法: verify_boot_ofox.py <boot-ofox.img> <原厂 boot_a.img> [分区上限字节]

校验项（任一不过就 exit 1）：
  1) magic == ANDROID!
  2) header_version == 3
  3) kernel_size 与原厂一致
  4) 头部（除 @12 ramdisk_size 外）逐字节等同原厂
  5) kernel 区逐字节等同原厂
  6) 新 ramdisk 是合法 gzip newc cpio
  7) 产物大小不超过分区上限（默认 167772160 = 160MB）
"""
import gzip
import io
import struct
import sys


def align(x, p=4096):
    return (x + p - 1) // p * p


def main():
    if len(sys.argv) < 3:
        print("用法: %s <boot-ofox.img> <原厂 boot_a.img> [分区上限]" % sys.argv[0], file=sys.stderr)
        return 2

    out, stock = sys.argv[1], sys.argv[2]
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else 167772160

    o = open(out, "rb").read()
    s = open(stock, "rb").read()

    ok = True

    def chk(cond, msg):
        nonlocal ok
        print(("  [OK]   " if cond else "  [FAIL] ") + msg)
        if not cond:
            ok = False

    chk(o[:8] == b"ANDROID!", "magic 是 ANDROID!")
    chk(struct.unpack_from("<I", o, 40)[0] == 3, "header_version == 3")

    ks_o = struct.unpack_from("<I", o, 8)[0]
    rs_o = struct.unpack_from("<I", o, 12)[0]
    ks_s = struct.unpack_from("<I", s, 8)[0]
    rs_s = struct.unpack_from("<I", s, 12)[0]

    chk(ks_o == ks_s, "kernel_size 与原厂一致 (%d)" % ks_o)
    chk(o[:12] == s[:12] and o[16:4096] == s[16:4096],
        "头部除 @12 外逐字节等同原厂")
    chk(o[4096:4096 + ks_o] == s[4096:4096 + ks_s],
        "kernel 区逐字节等同原厂")

    hsz = struct.unpack_from("<I", o, 20)[0]
    ro = align(hsz) + align(ks_o)
    try:
        head = gzip.GzipFile(fileobj=io.BytesIO(o[ro:ro + rs_o])).read(6)
    except Exception as e:
        head = b""
        print("  [FAIL] ramdisk 解压异常: %s" % e)
        ok = False
    chk(head == b"070701", "新 ramdisk 是合法 gzip newc cpio")

    chk(len(o) <= limit, "大小 %d 未超分区上限 %d" % (len(o), limit))

    print("  产物大小: %d 字节 (%.1f MB)" % (len(o), len(o) / 1048576))
    print("  新 ramdisk_size: %d (原厂 %d)" % (rs_o, rs_s))
    print("  ramdisk 偏移: %d" % ro)

    if not ok:
        print("::error::产物校验未通过")
        return 1
    print("✓ 产物校验全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
