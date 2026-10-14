#!/usr/bin/env python3
"""
按 MANIFEST.txt 校验下载到的 Release 资产。

用法: check_manifest.py <MANIFEST.txt> <目录1> [目录2 ...]

MANIFEST 格式（制表符分隔，注释行以 # 开头）：
    文件名\t字节数\tsha256\t解压后名字

为什么支持多个目录：
    CI 里资产落在不同位置 —— boot-header.bin / stock-ramdisk.gz 在 materials/，
    而 dtb.img 直接落到设备树的 prebuilt/。只扫一个目录会误报「资产缺失」。

另外：Image.gz 解压成 Image 后原文件会被删掉，所以额外支持按
「解压后名字」在 <目录>/prebuilt/<解压后名字> 下查找。
"""
import hashlib
import os
import sys


def sha256_file(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def find_asset(name, unpacked, dirs):
    """在多个目录里找资产。

    返回 (路径, 匹配方式)。匹配方式：
      'archive' —— 找到的是【压缩包本体】（例如 Image.gz），可按 MANIFEST 校验
      'unpacked'—— 只找到【解压后的文件】（例如 Image），
                   此时 MANIFEST 里的大小/sha256 是压缩包的，不能直接比，
                   只能确认「它存在」。
    """
    for d in dirs:
        p = os.path.join(d, name)
        if os.path.isfile(p):
            return p, "archive"
    if unpacked and unpacked != name:
        for d in dirs:
            for sub in ("", "prebuilt"):
                p = os.path.join(d, sub, unpacked) if sub else os.path.join(d, unpacked)
                if os.path.isfile(p):
                    return p, "unpacked"
    return None, None


def main():
    if len(sys.argv) < 3:
        print("用法: %s <MANIFEST.txt> <目录1> [目录2 ...]" % sys.argv[0], file=sys.stderr)
        return 2

    manifest = sys.argv[1]
    dirs = sys.argv[2:]

    if not os.path.isfile(manifest):
        print("::warning::没有 MANIFEST.txt，跳过校验")
        return 0

    print("  搜索目录: %s" % ", ".join(dirs))

    ok = True
    checked = 0
    missing = 0
    for line in open(manifest, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        name, size_s, want_sha, unpacked = parts[0], parts[1], parts[2], parts[3]

        path, how = find_asset(name, unpacked, dirs)
        if path is None:
            print("::warning::在 %s 下都没找到资产 %s（也没找到解压后的 %s）"
                  % (", ".join(dirs), name, unpacked))
            missing += 1
            continue

        if how == "unpacked":
            # 只找到了解压后的文件：压缩包已被消费掉，无法再按 MANIFEST 比对
            print("  %-18s 已解压为 %s（%d 字节）—— 跳过压缩包 sha 校验"
                  % (name, os.path.basename(path), os.path.getsize(path)))
            checked += 1
            continue

        got_size = os.path.getsize(path)
        try:
            want_size = int(size_s)
        except ValueError:
            want_size = -1
        got_sha = sha256_file(path)
        checked += 1

        size_ok = (got_size == want_size)
        sha_ok = (got_sha == want_sha)
        print("  %-18s 字节 %d（期望 %d）%s  sha256 %s  [%s]"
              % (name, got_size, want_size, "OK" if size_ok else "不符",
                 "OK" if sha_ok else "不符", how))
        if not size_ok:
            print("::error::%s 字节数不符" % name)
            ok = False
        if not sha_ok:
            print("::error::%s sha256 不符" % name)
            print("::error::  期望 %s" % want_sha)
            print("::error::  实际 %s" % got_sha)
            ok = False

    print("已校验 %d 个资产，缺失 %d 个" % (checked, missing))
    if not ok:
        print("::error::MANIFEST 校验未通过")
        return 1
    if missing:
        print("::warning::有 %d 个资产没校验到（可能是可选项，或路径没覆盖到）" % missing)
    print("✓ MANIFEST 校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
