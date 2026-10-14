# OPPO K10x 5G (PGGM10 / OP5295) 橙狐 Recovery 编译与刷入流水线

一页说明：整体流程、每步怎么做、已知限制、怎么回滚。

---

## 0. 这台机器的事实（全部实测）

| 项目 | 值 | 依据 |
|---|---|---|
| 机型 | OPPO K10x 5G | — |
| 型号 / 设备代号 | **PGGM10** / **OP5295** | `probe.txt` |
| SoC | **SM6375 (holi)**，arm64 | `ro.board.platform=holi` |
| 系统 | Android 14 / ColorOS 14.0.0.920 | `ro.build.version.release=14` |
| 内核 | 5.4.233-qgki | `uname -r` |
| 启动方式 | **A/B 双槽**（当前 `_a`） | `ro.build.ab_update=true` |
| 分区 | **动态分区**（super = 11190403072） | `/proc/partitions` |
| recovery 分区 | **没有** | `by-name` 无此项 |
| 原厂 recovery 位置 | **在 `boot` 的 ramdisk 里** | ramdisk 含 `system/bin/recovery`、`phoenix_recovery`、`etc/recovery.fstab`、`res/OplusOS/*` |
| boot 分区 | 160MB（167772160 字节） | sde9 = 163840 KB |
| 解锁状态 | **已解锁** | `ro.boot.flash.locked=0`, `verifiedbootstate=orange` |
| 加密 | **FBE**，`/data` = f2fs + inlinecrypt，`/metadata` = ext4 | `ro.crypto.state=encrypted` |
| 按键进 recovery | **全都不可用** ✗ | 音量下+电源=fastboot；音量上+电源=无功能 |
| 命令进 recovery | **`reboot recovery` 可用** ✓ | misc BCB 通道可用 |

---

## 1. 整体流程

```
 ① CI 编译（GitHub Actions）
    ofox-build/.github/workflows/ofox-build.yml
      ├─ make recoveryimage            → 橙狐 ramdisk
      ├─ ofox-merge-ramdisk.py         → 合并进【原厂 ramdisk】
      └─ ofox-splice.py                → 拼回【原厂 boot 镜像】
                                          ⇒ boot-ofox.img
                    │
                    ▼ 下载 artifact
 ② 手机端刷入（root，不需要电脑）
    ofox-flash.sh --img boot-ofox.img --flash
      ├─ 写前 dd 备份 boot 分区
      ├─ dd 写入 boot
      └─ 写后回读校验 + 打印回滚命令
                    │
                    ▼
 ③ 进橙狐：  adb reboot recovery   或   su -c 'reboot recovery'
    回 Android： 重启即可（平时开机默认就是 Android）
```

## 2. ★方案：单分区双模式★

**橙狐和 Android 共用同一个 `boot` 分区。**

同一个 AOSP `init` 依据启动模式选择执行哪个 recovery：

- 平时开机（`force_normal_boot=1`）→ **Android**
- `adb reboot recovery` → misc 的 BCB 通道 → **橙狐**

本机没有 recovery 分区 —— 原厂 recovery 本来就在 `boot` 的 ramdisk 里
（ramdisk 实测含 `system/bin/recovery`、`system/bin/phoenix_recovery`、
`etc/recovery.fstab`、`init.recovery.qcom.rc`、`res/OplusOS/*`），
所以这个做法是顺着原厂设计走的，而不是硬塞。

### 2.1 怎么解决"版本打架"问题

直接的担心是：原厂 ramdisk 是 **Android 14** 构建的，
如果直接把橙狐（12.1 分支）的整套 ramdisk 换进去，
`libc` / `linker` / HAL 接口版本不一致，会在 `init` 阶段就崩，
而且崩了**连 Android 也一起进不去**。

**解决办法是"原厂为底 + 白名单覆盖"**，由一个脚本严格实施：

`tools/ofox-merge-ramdisk.py` 的策略：

1. **原厂 ramdisk 为底**，保留全部条目；
2. 删除 OPPO 自家 recovery 的东西（默认开）：
   `system/bin/recovery`、`system/bin/phoenix_recovery`、
   `res/OplusOS/**`、`system/etc/recovery.fstab`；
3. 橙狐条目按三种情况处理：
   - 原厂没有 → **直接新增**
   - 原厂有 + 命中**覆盖白名单** → **覆盖**
     （白名单：`system/bin/recovery`、`twres/`、`sbin/`、
     `etc/recovery.fstab`、`init.recovery.*.rc`、`prop.default`、`libtwrp*` …）
   - 原厂有 + **不在白名单** → **保留原厂**

第 3 条的最后一档是关键：**正常开机所需的 `init` / `linker64` / `libc`
全部保留原厂**，橙狐只拿到 recovery 相关的那部分。
实测合并后：

```
system/bin/init          ✓ 1890216 字节（原厂）
system/bin/linker64      ✓ 1463936 字节（原厂）
system/etc/init/hw/init.rc ✓ 16326 字节（原厂）
system/bin/recovery      ✓ 橙狐版本
```

### 2.2 拼回 boot 时"与原厂同构"

`tools/ofox-splice.py` 的做法：

- 头部 + kernel 区**逐字节照抄原厂**；
- 只改头部偏移 `@12` 的 `ramdisk_size`；
- **ramdisk 偏移不变**（实测 48603136，与原厂相同）。

⇒ 对 aboot 而言，产物与原厂镜像是**同构**的，风险最低。
实测校验全部通过：

```
[OK] magic 是 ANDROID!
[OK] header_version == 3
[OK] kernel_size 与原厂一致 (48595008)
[OK] 头部除 @12 外逐字节等同原厂
[OK] kernel 区逐字节等同原厂
[OK] 新 ramdisk 是合法 gzip newc cpio
[OK] 大小 66942428 未超分区上限 167772160
```

### 2.3 ★分支必须用 `fox_14.1`★

目标机是 Android 14，原厂 ramdisk 同代。**橙狐用同代分支（`fox_14.1`），
libc/linker/HAL 版本才对得上。**

> ⚠ 只当 `fox_14.1` 确实不可用时，才退回 `fox_12.1` ——
> 那样与原厂 Android 14 ramdisk 混用，**库版本冲突风险显著上升**。
> 合并脚本的白名单机制已经把主要风险挡掉了（正常启动部分保持原厂），
> 但仍属降级方案，请谨慎并在刷前留好备份。

---

## 3. CI 怎么跑

### 3.1 先准备原料（★这一步不做，CI 必失败★）

CI 需要 **4 个原料**，全部 **< 25MB** —— 这样主人用 **GitHub 网页端**就能直接拖上去，
不需要 `gh` 命令行、也不需要电脑。

| 资产名 | 字节 | 说明 |
|---|---|---|
| `Image.gz` | 22205180 | 原厂内核 `Image` 的 `gzip -9`。CI 里 `gunzip` 还原成 `Image`（解压后 48595008 字节，**与原厂逐字节一致**）|
| `stock-ramdisk.gz` | 21251696 | **原厂 ramdisk**（合并的"底"），未压缩 |
| `dtb.img` | 4607565 | 设备树，FDT magic `d00dfeed`，未压缩 |
| `boot-header.bin` | **4096** | ★关键★ 原厂 boot 镜像的**前 4096 字节头部**，用于在 CI 里重建拼装模板 |

> 为什么不需要上传 160MB 的 `boot_a.img`：
> `ofox-splice.py` 只需要原厂 boot 的 **头部 + kernel 区** 当作模板，
> 不需要原厂 ramdisk。而这三段可以完全重建出来：
>
> ```
> boot-header.bin(4096) + Image(48595008) + 4032 个零字节 = 48603136 字节
> ```
>
> 已实测：**重建结果与真原厂 `boot_a.img` 的前 48603136 字节逐字节相同**
> （header ✓、kernel 区 ✓、4032 字节间隔区全零 ✓，
> sha256 均为 `ad2765d2a06242f8…`）。
>
> 更进一步：用**重建模板**和用**真 160MB `boot_a.img`** 走完整条流水线，
> 产出的 `boot-ofox.img` **sha256 完全相同**（`9e354afb…`）——
> 也就是说 160MB 那个上传**确实可以省掉**。

**上传方法（网页端，不需要电脑）：**

1. 打开仓库 → **Releases** → **Draft a new release**
2. **Choose a tag** 填 `ofox-prebuilt` → **Create new tag**
3. 标题随便填，把上面 4 个文件**拖进附件区**（每个都 < 25MB，网页端能传）
4. **确认附件名与表格里完全一致**（网页上传有时会加前缀，可在附件上改名）
5. 建议把 `MANIFEST.txt` 也一起拖上去（见下）
6. **Publish release**

工作区里这 4 个文件已经准备好，在 `/mnt/sdcard/123云盘/ofox-release-assets/`：
`Image.gz`、`stock-ramdisk.gz`、`dtb.img`、`boot-header.bin`（外加 `MANIFEST.txt`）。

**`MANIFEST.txt`（可选但推荐）** —— CI 会下载它并逐项校验 4 个资产的字节数与
sha256，不匹配就 `::error` 退出，防止用到下载损坏的文件：

```
# 文件名	字节数	sha256	解压后名字
Image.gz	22205180	112613f28ebd8ce1b8dd1cef7df77798bfe9db98ca1f45d9fd03d684303ff11f	Image
stock-ramdisk.gz	21251696	6be40634de9ea1eba30da6337133bf5235ea3e66d8a3c8ad539a4dbac56264fc	stock-ramdisk.gz
dtb.img	4607565	91468af4e1a602a957f83e9a2feaae48e52de7e1d3619ba42bb6e3fd5438b3be	dtb.img
boot-header.bin	4096	9eed4a42eaa17fbd6fa1cc5740cd67f0eabed87da24cb915821add30f0440bb3	boot-header.bin
```

（CI 里对应的就是 `tools/check_manifest.py`，已实测 4/4 通过。）

**如果哪天你能传大文件了**：Release 里放一个完整的 `boot_a.img`（≥50MB），
CI 会**优先直接用它**，跳过重建。两条路都支持。

### 3.2 把设备树和工具放进仓库

workflow 会在仓库里找（两处任一即可）：

```
ofox-build/device/oppo/PGGM10/     ← 本目录现在的结构
device/oppo/PGGM10/                ← 或提到仓库根
```

合并用的三个脚本已经放在 `ofox-build/tools/`：
`cpio_tool.py`、`ofox-merge-ramdisk.py`、`ofox-splice.py`，
外加本流水线新增的 `extract_ofox_ramdisk.py`、`verify_boot_ofox.py`。
**CI 直接调用仓库里的这些文件，不需要另外 wget。**

### 3.2.1 ★源码同步：候选分支与自动回退（重要）★

**`manifest_source=orangefox`（GitLab 路）** —— 橙狐完整源，含 `OF_*` 专属特性，
但**依赖 GitLab 可达**。

候选分支按序自动尝试（当你保持默认值 `fox_14.1` 时）：

```
fox_14.1 → fox_13.1 → fox_12.1 → fox_11.0
```

> 若你**显式**选了其它分支，则**只尝试那一个**，不再回退。

同步方式**优先用橙狐官方脚本**：
`git clone --depth=1 https://gitlab.com/OrangeFox/sync.git`
→ `/tmp/ofox-sync/orangefox_sync.sh --branch <分支> --path <目录>`；
脚本不存在或失败时，回退到
`repo init -u https://gitlab.com/OrangeFox/manifest.git -b <分支> --depth=1 --no-repo-verify`
+ `repo sync -c -j4 --force-sync --no-clone-bundle`。

**失败时日志里会有**（这就是第一次真机跑失败时缺的东西）：

1. **预检**（全部 `::notice::` 打印，6 条 URL + HTTP 码）：
   - `https://gitlab.com/OrangeFox/manifest.git/info/refs?service=git-upload-pack`
   - `https://gitlab.com/OrangeFox/sync.git/info/refs?service=git-upload-pack`
   - `https://gitlab.com/OrangeFox/manifest/-/raw/<分支>/default.xml`（每个候选分支一条）
2. **每个分支的真实报错尾部 20 行**（不再吞掉）
3. 全失败时给出**明确结论**：
   `GitLab 不可达` / `分支不存在` / `子项目拉取失败`，
   并提示改用 `manifest_source=twrp_minimal` + `fox_branch=twrp-14.1`

---

**`manifest_source=twrp_minimal`（GitHub 路）** —— 托管在 GitHub，
**不依赖 GitLab**，GitLab 不通时的可靠退路。分支名是 `twrp-<版本>`：

| 你填的 `fox_branch` | 实际使用 |
|---|---|
| `twrp-14.1`（显式） | `twrp-14.1` |
| `fox_14.1` | `twrp-14.1` ← **已确认存在** |
| `fox_13.1` | `twrp-13.0` |
| `fox_12.1` | `twrp-12.1` |
| `fox_11.0` | `twrp-11.0` |

第一次真机跑（run 38503902702）就是在这条路上——
`manifest_source=twrp_minimal` + `fox_branch=twrp-14.1`。

> 这条路的 `repo init` 也加了 `--depth=1 --no-repo-verify`，并会先预检
> GitHub 上该分支的 HTTP 码；同步后校验 `build/envsetup.sh` 是否真的存在。

---

> ### ⚠ 跨版本库混用的风险（回退到非 14 分支时）
>
> 目标机是 **Android 14**。若最终用到 `fox_13.x` / `fox_12.x` / `fox_11.x`，
> 就是跨版本构建，`libc` / `linker` / HAL 接口版本与原厂 ramdisk 不一致。
>
> **我们已经挡住的**：通过「原厂 ramdisk 为底 + 白名单覆盖」策略，
> 正常开机所需的 `init`、`linker64`、`libc`、`init.rc` **全部保持原厂**，
> 所以**把 Android 搞挂的风险已被压到很低** —— 最坏情况是橙狐起不来，
> 但 Android 照样能进。
>
> **仍然存在的**：橙狐 **recovery 二进制自身**仍可能更挑剔 ——
> 可能因找不到期望的符号而启动失败、黑屏或重启。
> 这类问题不会损坏系统，但会让你进不去橙狐。
>
> **建议**：优先 `fox_14.1` 或 `twrp-14.1`；若只能用老分支，
> 刷前留好备份，刷后先确认能进 Android 再尝试进橙狐。

### 3.3 触发构建

GitHub → Actions → **"[PGGM10] OrangeFox Recovery 编译"** → Run workflow。

| 输入 | 默认 | 说明 |
|---|---|---|
| `fox_branch` | **`fox_14.1`** | 默认值 = 按序尝试 `14.1→13.1→12.1→11.0`；显式选其它则只试该分支（见 §3.2.1）|
| `manifest_source` | `orangefox` | 橙狐完整源（依赖 GitLab 可达）；**GitLab 不通就用 `twrp_minimal`**（GitHub 托管）|
| `device_tree_repo` | 当前仓库 | 留空即可 |
| `kernel_source` | `release` | 从 Release 资产下载原料 |
| `prebuilt_release_tag` | `ofox-prebuilt` | 上面那个 tag |
| `prebuilt_repo` | 当前仓库 | 资产所在仓库 |
| `use_ccache` | `true` | 加速后续构建 |
| `make_jobs` | `4` | 免费 runner 4 核；OOM 就降到 2 |

### 3.4 产物

artifact：`OrangeFox-PGGM10-bootofox-<分支>-<构建号>`

| 文件 | 说明 |
|---|---|
| **`boot-ofox.img`** | ★要刷的就是它★ 已合并好、可直接 dd 进 boot 分区（约 64MB）|
| `merge-report.md` | 合并报告（删了哪些、新增哪些、覆盖哪些、保留哪些冲突） |
| `recovery.img` | CI 编出的原始橙狐镜像（留档） |
| `ofox-build-info.txt` | 构建信息 + sha256 |

---

## 4. 手机端刷入

把 `ofox-flash.sh` 和 `boot-ofox.img` 放到手机（例如 `/sdcard/Download/`）：

```sh
# 1) dry-run（默认就是，不写任何东西）
su -c 'sh /sdcard/Download/ofox-flash.sh --img /sdcard/Download/boot-ofox.img'

# 2) 确认后真刷
su -c 'sh /sdcard/Download/ofox-flash.sh --img /sdcard/Download/boot-ofox.img --flash'
```

脚本会：

1. 检查 `uid=0`，定位当前槽的 boot 分区（`ro.boot.slot_suffix`）；
2. 检查镜像大小、`ANDROID!` magic、`header_version` 是否 v3；
3. **写前强制 dd 备份** boot → `<prep>/boot_<槽>-<时间戳>.img`（并存 `.sha256`）；
4. 写入；
5. **写后回读校验**（前 1MB 的 sha256 + 分区头部 magic）；
6. 打印产物信息、**回滚命令**、进橙狐的方法。

---

## 5. 进橙狐 / 回 Android

### 进橙狐

```sh
su -c 'reboot recovery'      # 手机本地，推荐
adb reboot recovery          # 电脑 adb
```

> ⚠ **按键组合在这台机上无效**（已实测）：
> 音量下+电源 = fastboot；音量上+电源 = 无功能。
> 只能用上面两条命令。

### 回 Android

```sh
su -c 'reboot'
```

平时开机默认就是 Android，只有走 BCB 通道才进橙狐。

---

## 6. 回滚

**情况一：能进系统或能进橙狐** → 把备份写回去：

```sh
su -c 'dd if=/sdcard/Download/ofox-prep/boot_a-<时间戳>.img of=/dev/block/by-name/boot_a bs=1M'
su -c 'sync'
```

**情况二：都进不去** → 用电脑 fastboot（音量下+电源进 fastboot）：

```sh
fastboot flash boot boot_a.img
```

**情况三：还没刷，只想验证备份**：

```sh
sha256sum /sdcard/Download/ofox-prep/boot_a.img
# 应等于 89746785a9dc941adc6113460ac53606e2eb5282b14446d65a9fddad8b7a986c
```

---

## 7. 已知限制

### 7.1 ★`/data` 大概率解不开★

本机加密是 **FBE + 元数据加密 + Qualcomm ICE(inlinecrypt) + wrapped key**：

```
ro.crypto.state=encrypted
ro.crypto.type=file
/data = f2fs (inlinecrypt)
fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0
keydirectory=/metadata/vold/metadata_encryption
```

要解开需要**同时**满足：

1. 正确的 keymaster / gatekeeper HAL（Qualcomm 闭源，得从原厂取 blob）；
2. 内核 ICE 驱动 + wrapped key 支持；
3. 与 ColorOS 14 版本匹配的 metadata 解密实现。

`BoardConfig.mk` 里打开了 `TW_INCLUDE_CRYPTO` / `TW_INCLUDE_CRYPTO_FBE`，
**只是让代码编进去、有尝试的机会，不代表一定能解开**。

**解不开时的表现**：`/data` 显示为 0 或挂载失败，内部存储看不到。
**这是预期现象，不是 recovery 坏了。**

好消息：**不影响刷机**。刷 boot / 备份 / 格式化 data 都能用，
只是看不到你原来的文件。

### 7.2 按键组合不可用

见 §5。只能 `reboot recovery` 或 `adb reboot recovery`。

### 7.3 系统 OTA 会覆盖

ColorOS 推送升级时可能把 `boot` 刷回原厂，橙狐就没了 —— 重刷一次即可。

---

## 8. 风险提示

> **★刷之前务必确认原厂备份的 sha256★**

`ofox-prep/summary.txt` 里记录的实测值：

```
89746785a9dc941adc6113460ac53606e2eb5282b14446d65a9fddad8b7a986c  boot_a.img
58f052f09dca83fb1d35bfe574ec7f1a30c36f5697f7444f2ed89e77d4074cd5  vendor_boot_a.img
873f56e3e058b5d3413f81e340e9c8fbb0e89ca3417a8aa654f9684978d8cf5a  dtbo_a.img
8e6781ff23b856536d47468e2dca52731f8801748eeb2d1d95078e19b988cd00  vbmeta_a.img
bc460ccb79e4a8ea68b63de009388040750bbeebfe7be6056e0785957f912c86  vbmeta_b.img
8da2a417164d16dc15e3d41de1e769b8cf652c65254f784055d3c82a25c56a06  misc.img
```

其它注意点：

- **别动 `vbmeta`**：已解锁状态下 bootloader 会跳过校验，保持原厂即可；
- **别用 `fox_12.1` 除非万不得已**（见 §2.3）；
- 全程有备份 + 回读校验 + 回滚命令，但**刷机永远有风险**，请自行判断。

---

## 9. 目录结构

```
ofox-build/
├── README.md                          ← 本文件
├── tools/                             ← CI 调用的合并工具（真文件），
│   ├── cpio_tool.py                   ←   newc cpio 读写
│   ├── ofox-merge-ramdisk.py          ←   橙狐部件合并进原厂 ramdisk
│   ├── ofox-splice.py                 ←   新 ramdisk 拼回原厂 boot
│   ├── extract_ofox_ramdisk.py        ←   从 recovery.img 解出 ramdisk
│   ├── rebuild_boot_template.py       ←   由 boot-header.bin + Image 重建模板（新增）
│   ├── check_manifest.py              ←   按 MANIFEST.txt 校验资产 sha256（新增）
│   └── verify_boot_ofox.py            ←   产物严格校验
├── device/oppo/PGGM10/                ← 设备树（放进源码树 device/oppo/PGGM10）
│   ├── BoardConfig.mk                 ← 核心配置（架构/内核头/分区/AVB/加密/UI）
│   ├── fox_PGGM10.mk                  ← 橙狐产品定义（lunch fox_PGGM10-eng）
│   ├── AndroidProducts.mk             ← 产品注册
│   ├── Android.mk                     ← 入口
│   ├── device.mk                      ← 产品级包与服务
│   ├── vendorsetup.sh                 ← ★OF_* / FOX_* 开关都在这★
│   ├── system.prop                    ← recovery 内的属性
│   ├── recovery.fstab                 ← TWRP 格式 fstab（由原厂转换）
│   ├── proprietary-files.txt          ← 可选：要抽的厂商 blob
│   ├── extract-files.sh               ← 可选：抽 blob 的脚本
│   ├── prebuilt/README.md             ← prebuilt 怎么来（含精确偏移）
│   └── recovery/root/system/etc/
│       ├── recovery.fstab             ← 实际打包进 recovery 的 fstab
│       └── twrp.flags                 ← 哪些分区可备份/可刷
├── scripts/                           ← CI 用的解析脚本
│   ├── extract_boot_kernel.py
│   ├── extract_vendor_boot_dtb.py
│   └── split_recovery_img.py
└── .github/workflows/
    └── ofox-build.yml                 ← CI 工作流

ofox-flash.sh                          ← ★手机端刷入脚本（工作区根目录）★
```

---

## 10. 常见问题

**Q: CI 报缺 `stock-ramdisk.gz` / `boot_a.img`？**
A: 单分区双模式**必须**有这两个原料（原厂 ramdisk 作底、原厂 boot 作模板），
   不能用「内核 + dtb」代替。按 §3.1 一并上传到 Release。

**Q: 同步橙狐源码失败（真机 run 38503902702 就是这个）？**
A: 看日志里预检的 6 条 URL 的 HTTP 码：
   - 若 `gitlab.com` 全是 `000`/超时 → **runner 到 GitLab 不通**。
     改用 `manifest_source=twrp_minimal` + `fox_branch=twrp-14.1`
     （GitHub 托管、已确认分支存在）。
   - 若 manifest 预检 200 但某分支 404 → 该分支不存在，
     workflow 已会自动试下一个候选分支。
   - 若 manifest 200 但 `repo sync` 报错 → 是子项目拉取问题，
     日志里有该分支的报错尾部 20 行。
   注意：GitHub 上那些"橙狐镜像"都残缺不可用
   （`AirysDark/OrangeFox-manifests` 只列 7 个项目、
   `LeChenOS/OrangeFox_Twrp_Manifest-` 是空仓库），**不要走 GitHub 镜像**。

**Q: CI 报 `vendor/fox/config/common.mk` 找不到？**
A: 用 `twrp_minimal` 源时正常。`fox_PGGM10.mk` 已用 `-include` + `wildcard`
   回退到 `vendor/twrp/config/common.mk`。

**Q: 产物校验 `kernel 区逐字节等同原厂` FAIL？**
A: 说明 `--stock` 传错了模板（不是本机的 `boot_a.img`）。
   确认 Release 里 `boot_a.img` 的 sha256 是
   `89746785a9dc941adc6113460ac53606e2eb5282b14446d65a9fddad8b7a986c`。

**Q: 刷完进橙狐黑屏/重启？**
A: 先把备份 dd 回去（§6），然后：
   1. 确认用的是 `fox_14.1` 编出来的；
   2. 看 `merge-report.md`，确认 `init`/`linker64` 是原厂的；
   3. 确认产物大小 < 160MB；
   4. `adb shell dmesg` 或 recovery 的 `/tmp/recovery.log`。

**Q: 橙狐里看不到内部存储？**
A: 预期行为，见 §7.1（FBE 解不开）。不影响刷机功能。

**Q: 怎么彻底移除橙狐？**
A: 把原厂备份 dd 回 boot 分区即可（§6）。
