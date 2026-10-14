#!/usr/bin/env python3
"""把新 ramdisk 拼回原厂 boot 镜像：头部与布局完全沿用原厂，只换 ramdisk。

用法: python3 ofox-splice.py --stock boot_a.img --ramdisk new-ramdisk.gz --out boot-ofox.img [--pad-to 原大小]
"""
import argparse, gzip, io, struct, sys, hashlib

def find_ramdisk(b, start=4096):
    """从 start 起找一个 gzip 流，其解压内容以 070701 开头（= cpio ramdisk）"""
    pos = start
    while True:
        i = b.find(b'\x1f\x8b\x08', pos)
        if i == -1 or i > start + 64 * 1024 * 1024:
            return None
        try:
            d = gzip.GzipFile(fileobj=io.BytesIO(b[i:i + 64 * 1024 * 1024])).read(16)
            if d[:6] == b'070701':
                return i
        except Exception:
            pass
        pos = i + 1

def ramdisk_offset_from_header(b):
    """按 boot header v3 计算 ramdisk 偏移（模板里没有 ramdisk 时用这个）。

    ramdisk 偏移 = align(header_size,4096) + align(kernel_size,4096)
    注意：这是【计算值】。对原厂完整镜像，实测它 == 扫描出来的实际偏移
    （48603136），两种方法结果一致。
    """
    hsz = struct.unpack_from('<I', b, 20)[0]
    ksz = struct.unpack_from('<I', b, 8)[0]
    if not (1024 <= hsz <= 65536):
        return None
    def align(x, p=4096):
        return (x + p - 1) // p * p
    return align(hsz) + align(ksz)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--stock', required=True)
    ap.add_argument('--ramdisk', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--pad-to', type=int, default=0)
    a = ap.parse_args()

    b = open(a.stock, 'rb').read()
    assert b[:8] == b'ANDROID!', '不是 Android boot 镜像'
    ks = struct.unpack_from('<I', b, 8)[0]
    old_rs = struct.unpack_from('<I', b, 12)[0]
    ro = find_ramdisk(b)
    if ro is None:
        # 模板是「boot-header.bin + Image」重建出来的，里面没有 ramdisk，
        # 扫不到 gzip 流是正常的 —— 这时按头部字段计算偏移。
        ro = ramdisk_offset_from_header(b)
        if ro is None:
            print('!! 既没扫到原厂 ramdisk，头部字段也不合法'); return 1
        print('提示: 模板里没有原厂 ramdisk，改用头部计算偏移 = %d' % ro)
    else:
        print('提示: 在模板里扫到原厂 ramdisk，偏移 = %d' % ro)
    print('原厂: 大小 %d, kernel_size@8=%d, ramdisk_size@12=%d, ramdisk 实际偏移=%d' % (len(b), ks, old_rs, ro))
    print('      kernel [4096, %d)  ramdisk [%d, %d)' % (4096 + ks, ro, ro + old_rs))

    new = open(a.ramdisk, 'rb').read()
    if new[:2] != b'\x1f\x8b':
        new = gzip.compress(new, 9)
    # 自检新 ramdisk
    try:
        d = gzip.GzipFile(fileobj=io.BytesIO(new)).read(16)
        assert d[:6] == b'070701', '新 ramdisk 不是 gzip cpio'
    except Exception as e:
        print('!! 新 ramdisk 校验失败:', e); return 1

    out = bytearray(b[:ro])          # 头部 + kernel + 原厂预留间隔，逐字节照抄
    out += new
    struct.pack_into('<I', out, 12, len(new))   # 只改 ramdisk_size
    if a.pad_to and len(out) < a.pad_to:
        out += b'\x00' * (a.pad_to - len(out))
    open(a.out, 'wb').write(out)

    print('\n输出: %s  大小 %d (%.1f MB)' % (a.out, len(out), len(out) / 1048576))
    print('  kernel 区逐字节一致: %s' % (bytes(out[4096:4096 + ks]) == b[4096:4096 + ks]))
    print('  新 ramdisk_size@12 = %d' % struct.unpack_from('<I', out, 12)[0])
    print('  输出镜像 ramdisk 偏移 = %d (与模板一致: %s)' % (ro, find_ramdisk(bytes(out)) == ro))
    print('  sha256 = %s' % hashlib.sha256(bytes(out)).hexdigest()[:32])
    return 0

if __name__ == '__main__':
    sys.exit(main())
