# prebuilt/ 放什么、怎么来

CI 编译橙狐前，这个目录里必须有下面两个文件。**它们不进 git**（内核 46MB+），
由工作流在构建前用脚本自动生成（见 `.github/workflows/ofox-build.yml` 的
"准备 prebuilt" 步骤）。

---

## 1. `prebuilt/Image` —— 内核

**来源（二选一）：**

### A. 原厂内核（推荐先跑通这条路）
从 `ofox-prep/boot_a.img` 里抽 kernel 段。本机实测 boot 头（自解析）：

| 字段 | 值 |
|---|---|
| magic | `ANDROID!` |
| kernel_size | 48595008 (46.4 MB) |
| ramdisk_size | 21251696 (20.3 MB) |
| os_version | 0x18000189 → Android 12.0.0 / patch 393 |
| header_size | 1580 |
| header_version | **3** |
| page_size | 4096 |
| cmdline | （空，cmdline 全在 vendor_boot） |

抽取命令（在电脑/CI 上）：

```sh
# kernel 起始偏移 = align(header_size,4096) = 4096
# kernel 长度     = 48595008
dd if=boot_a.img of=Image bs=1 skip=4096 count=48595008
```

校验：`file Image` 应显示 `Linux kernel ARM64 boot executable Image`（**不是**
gzip 压缩的，header v3 + GKI 是未压缩 `Image`）。
大小应为 `48595008` 字节。

### B. 自己编的内核
用户仓库：`xuannhuan9-lgtm/OPPO_Kernel_Release`
上游：`oppo-source/android_kernel_oppo_sm6375`，分支
`oppo/sm6375_u_14.0.0_k10x_5g`（5.4.233）。

编完产物 `arch/arm64/boot/Image` 直接放这里。
> ⚠ 自编内核要保证 recovery 能起：`CONFIG_IKCONFIG`、fb/display 驱动、
> f2fs、ext4 必须内建（不能是 =m，recovery 里没机会加载模块）。

---

## 2. `prebuilt/dtb.img` —— 设备树 ★现成的★

**直接用 `ofox-prep/dtb.img`**（4607565 字节，FDT 格式）。
它就是从本机 `vendor_boot_a.img` 的 dtb 段抽出来的原厂 DTB，兼容性 100%。

CI 里怎么拿到它：
```sh
# 本机 vendor_boot 头（v3）实测：
#   page_size           = 4096
#   vendor_ramdisk_size = 718853
#   header_size         = 2112
#   dtb_size            = 4607565
#   dtb_addr            = 0x1f00000
# dtb 偏移 = align(2112,4096) + align(718853,4096) = 4096 + 720896 = 724992
dd if=vendor_boot_a.img of=dtb.img bs=1 skip=724992 count=4607565
# 校验：file dtb.img -> "Device Tree Blob version 17"
```

因为工作区里 `ofox-prep/dtb.img` 已经是现成的，CI 也可以直接从仓库里取
（把它 commit 进仓库，4.6MB 不大）。

---

## 3. `prebuilt/dtbo.img`（★已不参与构建★）

> ⚠ **2026-10 更新**：`BoardConfig.mk` 已**移除** `BOARD_PREBUILT_DTBOIMAGE`，
> 并把 `BOARD_KERNEL_SEPARATED_DTBO` 改为 **`false`**。
> 原因：本机 dtbo 是原厂的、我们不编译也不刷它（`dtbo_a` 保持原样，
> 刷机只动 `boot` 分区）。所以这个文件**现在完全用不到**，
> 放在这里只是为了记录出处，**不需要放进 prebuilt/**。

来源（仅存档，不用）：`ofox-prep/dtbo_a.img`（分区 24MB）。

## 4. 关于 dtb / dtbo 的最终结论（重要）

实测本机 **boot 里没有 dtb**：

```
boot_a.img = header(4096) + kernel(48595008) + ramdisk(21251696)
vendor_boot_a.img 里才有 dtb（dtb_size = 4607565）
```

因此 `BoardConfig.mk` 里：
- `BOARD_INCLUDE_DTB_IN_BOOTIMG := false` —— boot 不含 dtb
- **不设** `BOARD_PREBUILT_DTBIMAGE_DIR` / `TARGET_PREBUILT_DTB` / `BOARD_PREBUILT_DTBOIMAGE`
  （设了会直接 `$(error)`：*BOARD_PREBUILT_DTBIMAGE_DIR with
  'BOARD_INCLUDE_DTB_IN_BOOTIMG != true' is not supported*）
- `BOARD_KERNEL_SEPARATED_DTBO := false`

最终镜像由 `ofox-splice.py` 把橙狐 ramdisk 拼进**原厂 boot 模板**，
kernel / header **逐字节保留**，dtb 继续留在 `vendor_boot` 里不动。

所以 `prebuilt/` 里**只需要两个文件**：`Image` + `dtb.img`；
其中 `dtb.img` 只是给 `BoardConfig.mk` 里的 `BOARD_PREBUILT_DTBIMAGE_DIR`
历史配置留档……

> ★更正★：`dtb.img` 现在**也不再被 BoardConfig 引用**了。
> 保留它是因为 CI 的原料清单里有它、且将来若改回 DTB-in-bootimg 会用到。
> 真正构建 `recovery.img` 只依赖 `prebuilt/Image`。

---

## 目录最终样子

```
device/oppo/PGGM10/prebuilt/
├── README.md      ← 本文件
├── Image          ← 46.4 MB 内核（CI 生成，不入库）
├── dtb.img        ← 4.6 MB  设备树（入库或 CI 生成）
└── dtbo.img       ← 可选
```
