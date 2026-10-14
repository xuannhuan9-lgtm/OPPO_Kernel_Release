#!/usr/bin/env python3
"""newc cpio 读写（支持多归档拼接输入、目录/普通文件/符号链接）"""
import io

def read_cpio(data):
    """读入可能是多段拼接的 cpio，返回 {路径: (mode, 内容bytes, 类型)}；类型: f/d/l"""
    out = {}
    o = 0
    while True:
        i = data.find(b'070701', o)
        if i == -1:
            break
        o = i
        def h(k): return int(data[o + k:o + k + 8], 16)
        try:
            mode, filesize, namesize = h(14), h(54), h(94)
        except ValueError:
            o += 1
            continue
        if namesize == 0 or namesize > 4096:
            o += 1
            continue
        name = data[o + 110:o + 110 + namesize - 1].decode('utf8', 'replace')
        body_at = (o + 110 + namesize + 3) // 4 * 4   # 文件名也要 4 字节对齐
        body = data[body_at:body_at + filesize]
        ft = mode & 0o170000
        typ = 'l' if ft == 0o120000 else ('d' if ft == 0o040000 else 'f')
        name = name.lstrip('./') if name.startswith('./') else name.lstrip('/')
        if name and name != '.':
            out[name] = (mode, body, typ)
        o = body_at + filesize
        o = (o + 3) // 4 * 4
    return out

def write_cpio(tree, trailer=True):
    """tree: {路径: (mode, 内容, 类型)} → newc cpio bytes（目录在前，利于 init）"""
    items = sorted(tree.items(), key=lambda kv: (kv[0].count('/'), kv[0]))
    buf = io.BytesIO()
    for name, (mode, body, typ) in items:
        if typ == 'd':
            mode = (mode & 0o7777) | 0o040000
        elif typ == 'l':
            mode = (mode & 0o7777) | 0o120000
        else:
            mode = (mode & 0o7777) | 0o100000
        nb = name.encode() + b'\0'
        hdr = b'070701'
        hdr += b'%08X' % 0            # ino
        hdr += b'%08X' % mode
        hdr += b'%08X' % 0            # uid
        hdr += b'%08X' % 0            # gid
        hdr += b'%08X' % 1            # nlink
        hdr += b'%08X' % 0            # mtime
        hdr += b'%08X' % len(body)    # filesize
        hdr += b'%08X' % 0            # devmajor
        hdr += b'%08X' % 0            # devminor
        hdr += b'%08X' % 0            # rdevmajor
        hdr += b'%08X' % 0            # rdevminor
        hdr += b'%08X' % len(nb)      # namesize
        hdr += b'%08X' % 0            # check
        buf.write(hdr); buf.write(nb)
        buf.write(b'\0' * ((-(110 + len(nb))) % 4))
        buf.write(body)
        buf.write(b'\0' * ((-len(body)) % 4))
    if trailer:
        nb = b'TRAILER!!!\0'
        hdr = b'070701' + b'%08X' % 0 * 8 + b'%08X' % 0 + b'%08X' % 0 + b'%08X' % 0 + b'%08X' % 0 + b'%08X' % len(nb) + b'%08X' % 0
        buf.write(hdr); buf.write(nb); buf.write(b'\0' * ((-(110 + len(nb))) % 4))
    return buf.getvalue()
