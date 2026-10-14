#!/usr/bin/env python3
"""
按 MANIFEST.txt 校验下载到的 Release 资产。

用法: check_manifest.py <MANIFEST.txt> <资产目录>

MANIFEST 格式（制表符分隔，注释行以 # 开头）：
    文件名\t字节数\tsha256\t解压后名字

对每个存在的资产校验字节数与 sha256；不匹配则 exit 1。
文件缺失时给出 warning（由调用方决定是否致命）。
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


def main():
    if len(sys.argv) != 3:
        print("用法: %s <MANIFEST.txt> <资产目录>" % sys.argv[0], file=sys.stderr)
        return 2

    manifest, base = sys.argv[1], sys.argv[2]
    if not os.path.isfile(manifest):
        print("::warning::没有 MANIFEST.txt，跳过校验")
        return 0

    ok = True
    checked = 0
    for line in open(manifest, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        name, size_s, want_sha, _unpacked = parts[0], parts[1], parts[2], parts[3]
        path = os.path.join(base, name)
        if not os.path.isfile(path):
            print("::warning::资产缺失: %s" % name)
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
        print("  %-18s 字节 %d（期望 %d）%s  sha256 %s"
              % (name, got_size, want_size, "OK" if size_ok else "不符",
                 "OK" if sha_ok else "不符"))
        if not size_ok:
            print("::error::%s 字节数不符" % name)
            ok = False
        if not sha_ok:
            print("::error::%s sha256 不符" % name)
            print("::error::  期望 %s" % want_sha)
            print("::error::  实际 %s" % got_sha)
            ok = False

    print("已校验 %d 个资产" % checked)
    if not ok:
        print("::error::MANIFEST 校验未通过")
        return 1
    print("✓ MANIFEST 校验全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
