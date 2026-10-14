#!/usr/bin/env python3
"""把橙狐(TWRP/OrangeFox)的 recovery 部件合并进原厂 ramdisk —— 单分区双模式的关键一步。

用法:
  python3 ofox-merge-ramdisk.py --stock 原厂ramdisk.gz --ofox 橙狐ramdisk.gz --out 输出.gz
  可选: --report 报告.md   --drop-oppo-recovery 0/1(默认1)

策略（原厂为底，保证正常开机的 init/linker/libc 不被换掉）:
  1) 原厂为底：保留全部条目
  2) 删除 OPPO 自家 recovery 的东西（默认开启）：system/bin/recovery、system/bin/phoenix_recovery、res/OplusOS/**
  3) 橙狐条目：
       - 原厂没有 → 直接新增
       - 原厂有 + 命中"覆盖白名单" → 覆盖
       - 原厂有 + 不在白名单 → 保留原厂（记入冲突清单，便于事后收紧/放宽）
"""
import argparse, gzip, io, re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cpio_tool import read_cpio, write_cpio

# 允许被橙狐覆盖的路径（其余冲突一律保留原厂）
OVERRIDE = [re.compile(p) for p in [
    r'^system/bin/recovery$', r'^system/bin/twrp$', r'^system/bin/busybox$',
    r'^system/bin/magiskboot$', r'^system/bin/magisk$', r'^system/bin/ksud$',
    r'^init\.recovery\..*\.rc$', r'^init\.rc$', r'^etc/recovery\.fstab$',
    r'^system/etc/recovery\.fstab$', r'^twres/', r'^sbin/',
    r'^system/lib(64)?/libtwrp', r'^system/lib(64)?/libors', r'^system/lib(64)?/libc\+\+',
    r'^system/bin/recovery\.', r'^etc/twrp\.flags$', r'^prop\.default$',
]]
# 要删掉的原厂 recovery 条目（默认）
DROP_OPPO = [re.compile(p) for p in [
    r'^system/bin/recovery$', r'^system/bin/phoenix_recovery$', r'^system/bin/recovery_updater$',
    r'^res/OplusOS/', r'^system/etc/recovery\.fstab$',
]]

def load(path):
    raw = open(path, 'rb').read()
    if raw[:2] == b'\x1f\x8b':
        return gzip.GzipFile(fileobj=io.BytesIO(raw)).read()
    return raw

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--stock', required=True)
    ap.add_argument('--ofox', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--report')
    ap.add_argument('--drop-oppo-recovery', type=int, default=1)
    a = ap.parse_args()

    st = read_cpio(load(a.stock))
    ox = read_cpio(load(a.ofox))
    print('原厂 ramdisk: %d 项' % len(st))
    print('橙狐 ramdisk: %d 项' % len(ox))
    if not ox:
        print('!! 橙狐 ramdisk 解析为空，拒绝继续'); return 1

    # 健壮性：init 只加载 init.recovery.<androidboot.hardware>.rc（本机 hardware=qcom）
    # 若橙狐提供的 rc 名字不是 qcom，自动补一份 qcom 名字，避免 recovery 起不来
    rcs = [k for k in ox if re.match(r'^init\.recovery\..*\.rc$', k)]
    if rcs and 'init.recovery.qcom.rc' not in ox:
        src = sorted(rcs)[0]
        ox['init.recovery.qcom.rc'] = ox[src]
        print('注意: 橙狐 rc 名为 %s → 自动另存为 init.recovery.qcom.rc' % src)

    dropped, added, over, kept = [], [], [], []
    if a.drop_oppo_recovery:
        for k in list(st):
            if any(p.match(k) for p in DROP_OPPO):
                dropped.append(k); del st[k]

    for k, v in ox.items():
        if k not in st:
            st[k] = v; added.append(k)
        elif any(p.match(k) for p in OVERRIDE):
            st[k] = v; over.append(k)
        else:
            kept.append(k)

    out = gzip.compress(write_cpio(st), 9)
    open(a.out, 'wb').write(out)
    print('\n结果: 输出 %d 项 → %s (%.1f MB)' % (len(st), a.out, len(out) / 1048576))
    print('  删除原厂 recovery 条目: %d' % len(dropped))
    print('  新增橙狐条目:           %d' % len(added))
    print('  覆盖(白名单):           %d  %s' % (len(over), over[:8]))
    print('  冲突但保留原厂:         %d  %s' % (len(kept), kept[:8]))
    # 关键项自检
    print('\n合并后关键项:')
    for k in ('system/bin/recovery', 'init.recovery.qcom.rc', 'etc/recovery.fstab',
              'system/etc/init/hw/init.rc', 'system/bin/init', 'system/bin/linker64'):
        print('  %-30s %s' % (k, '✓ %d 字节' % len(st[k][1]) if k in st else '✗ 缺失'))
    if a.report:
        with open(a.report, 'w', encoding='utf-8') as f:
            f.write('# ramdisk 合并报告\n\n')
            f.write('- 原厂条目删除（%d）：%s\n\n' % (len(dropped), ', '.join(dropped)))
            f.write('- 橙狐新增（%d）：%s\n\n' % (len(added), ', '.join(added)))
            f.write('- 覆盖原厂（%d）：%s\n\n' % (len(over), ', '.join(over)))
            f.write('- 冲突保留原厂（%d）：%s\n' % (len(kept), ', '.join(kept)))
        print('  报告已写入', a.report)
    return 0

if __name__ == '__main__':
    sys.exit(main())
