# 图片提取与解析

群消息里的图片是 takeaway 的关键载体（订阅截图、工具界面、产品对比图、官方回复证据）。本节定义如何从微信本地拿到明文图，给 Claude 多模态读取后判断价值。

---

## 0. 前置：wx-cli 必须 ≥ 0.2.0

`wx attachments` 和 `wx extract` 是 0.2.0 引入的命令。npm 上最新可能还是 0.1.10，需要从 GitHub main 分支编译：

```bash
cargo install --git https://github.com/jackwener/wx-cli.git --branch main --force
# 二进制装到 ~/.cargo/bin/wx，version 应 ≥ 0.2.0
~/.cargo/bin/wx --version
```

> 首次编译 ~16 分钟（拉所有依赖）。第二次重装只编译变化部分，~3-5 分钟。
> `/usr/local/bin/wx` 通常是老版本（npm 装的 0.1.10），优先用 `~/.cargo/bin/wx`。

---

## 1. 两个独立的坑（一起处理才能拿全图）

### 坑 A: daemon 缓存了过期的 `message_resource.db`

`wx-cli daemon` 启动时**一次性**解密 `message_resource.db` 到 `~/.wx-cli/cache/`，**之后微信新写入的图记录走 WAL 增量，daemon 不会自动重新解密**。

**典型现象**：当天后期发的图（比如晚上 20:38 之后），`wx attachments` 能列出，但 `wx extract` 报：

```
错误: 找不到本地 .dat（md5=... chat=...）— 微信可能尚未下载该附件
```

误导性的报错——实际上 `.dat` 在磁盘上，只是 daemon 还没刷新 db 记录。

**修复**：每次跑日报前先强制重启 daemon：

```bash
~/.cargo/bin/wx daemon stop && rm -f ~/.wx-cli/daemon.{pid,sock}
~/.cargo/bin/wx sessions --limit 1 >/dev/null     # 触发重启 + 重新解密
```

daemon log 里看到 `[cache] 全量解密 message/message_resource.db (Nms)` 就 OK。

### 坑 B: macOS `_M.dat` 后缀盲点

macOS 微信 4.x 把图片以 `_M.dat` 后缀存储（medium 尺寸），但 wx-cli 0.2.0 的 extract 实现只查 `.dat` / `_h.dat` / `_t.dat` 三种后缀，**没适配 `_M`**。即便 daemon 缓存刷新了，这些图也会报：

```
错误: 找不到本地 .dat（md5=... chat=...）
```

但报错里会带 `md5=...`，可以拿来 find `_M.dat` 文件兜底。

实际目录里文件命名分布（macOS 微信 4.1.7 实测）：

```
12053 个  _t_M.dat    缩略图 medium
 6120 个  _M.dat      标准 medium  ← 主流（白天/历史图）
 2513 个  _h_M.dat    HD medium
   53 个  _t.dat      旧版缩略图
   33 个  .dat        部分新发的 V2 加密图（wx extract 能直接解）
   21 个  _h.dat      旧版 HD
```

**重要发现**：

- `_M.dat` 文件**头本身就是明文 PNG / JPG magic**（`89 50 4e 47` / `ff d8 ff`），**没加密**。直接 `cp` 改后缀即可。
- 没 `_M` 后缀的 `.dat` 是新版 V2 加密图，wx-cli 0.2.0 的 extract **能正确解码**（输出 png / jpg / hevc 等）。

所以同一日的图可能分两种状态，要 **双轨脚本**同时支持。

---

## 2. 双轨脚本 `scripts/extract-images.sh`

```bash
# 0) 先重启 daemon 拿最新 message_resource.db（见 §1 坑 A）
~/.cargo/bin/wx daemon stop && rm -f ~/.wx-cli/daemon.{pid,sock}
~/.cargo/bin/wx sessions --limit 1 >/dev/null

# 1) 拿群图列表
~/.cargo/bin/wx attachments "<群名>" --since YYYY-MM-DD --until YYYY-MM-DD --kind image -n 200 --json \
  > /tmp/imgs.json

# 2) 双轨脚本批量解
scripts/extract-images.sh /tmp/imgs.json wechat/{folder}/images/YYYY-MM-DD/
```

**脚本逻辑**：

```
对每张图：
  A 路（优先）：wx extract 直接解 → 成功就用结果（新发的 V2 加密图走这条）
  B 路（兜底）：wx extract 失败但报错里有 md5= → find _M.dat 文件 cp，按 magic bytes 改后缀

A 路输出标记 ✓ A，B 路输出标记 ✓ B。
```

**实测**：5.14 群 21 张图，7 张走 A 路（晚上的新图），14 张走 B 路（白天的 `_M.dat`），**21/21 全成功**。

---

## 3. Claude 多模态读图判价值

解出的 PNG/JPG 直接用 `Read` 工具读（Claude 多模态原生支持）：

```
Read /path/to/image.png
```

**判图标准**（按"对会员有用"维度，跟 [output-format.md §0](output-format.md) 的产品定位一致）：

| 价值 | 类型 | 处理 |
|---|---|---|
| **高** | 实操证据（订阅截图、工具界面、价格对比、官方回复） | 嵌入对应 takeaway 后面 |
| **高** | 信息图（流程图、架构图、技术示意） | 嵌入 |
| **中** | 上下文截图（聊天记录引用、群内分享的产品页） | 看是否补强 takeaway，不强不嵌 |
| **低** | 纯娱乐（段子、表情包、生活照） | **跳过**，不嵌 |
| **低** | 模糊/截断/打码（看不清内容的） | 跳过 |

**特殊提示**：图里如果有"非聊天文字消息能提供"的信息（如腾讯官方在评论区回复的小技巧），必须把这个**新发现**加进 takeaway 正文。仅有图本身没有上下文是浪费。

---

## 4. 嵌入飞书 docx（见 publish.md §3）

提取出来的 png/jpg 直接用 `lark-cli docs +media-insert` 上传飞书，拿到 file_token。然后用 `<image token="..." width="..." height="..." align="center"/>` 在 markdown 里 inline 引用。

**3 个必坑**：

1. **media-insert 拒绝绝对路径**：必须 `cd` 到图片所在目录用 `./xxx.jpg` 相对路径，否则报 `unsafe file path`
2. **token 在每次 update 时会被飞书重新分配**：fetch 拿到新 token 后才能在下一次 update 里复用
3. **caption 嵌套 `<text>` 标签**：里面 `<text color="blue">**@xxx**</text>` 可能被外层 `<text color="gray">` 覆盖。如果效果不对，把 caption 拆成两个独立标签段

---

## 5. 性能与限制

| 项 | 现状 |
|---|---|
| 单张图解码 | 瞬时（cp + 后缀判断） |
| 14 张图批量 | ~3 秒（Claude 多模态读图自身较慢，不在此处） |
| 视频 / 文件 | wx 0.2.0 的 `kind` 当前只支持 `image`，视频和文件未来扩展 |
| Linux | wx 0.2.0 的 V2 image key 提取在 Linux 上空白，遇到 V2 .dat 报 unsupported（但 macOS 的 `_M.dat` 是明文，旁路脚本不受影响） |
| Windows | wx 0.2.0 用 `Weixin.exe` 内存扫 key，本 skill 未在 Windows 实测 |

---

## 6. 工作流总结

```
wx daemon stop && rm pid/sock → wx sessions --limit 1   # 强制刷新 db 缓存（必做）
        ↓
~/.cargo/bin/wx attachments "<群>" --since X --until Y --kind image --json > imgs.json
        ↓
scripts/extract-images.sh imgs.json images/YYYY-MM-DD/   # 双轨：A wx extract / B _M.dat cp
        ↓ N/N 张明文 png/jpg/hevc
Claude Read 多模态 → 标价值（高/中/低/0）
        ↓ 只挑 takeaway 直接证据
cd images/YYYY-MM-DD                                      # media-insert 拒绝绝对路径
lark-cli docs +media-insert --doc XXX --file ./xxx.png --caption "..."
        ↓ 拿 file_token
lark-cli docs +fetch → 找新分配的 image block token
        ↓
markdown 里 `<image token="..." width="..." height="..."/>` 嵌入对应 takeaway 后面
        ↓
lark-cli docs +update --mode overwrite ✓
```
