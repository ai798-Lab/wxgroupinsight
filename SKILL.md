---
name: wxgroupinsight
description: 把微信指定群聊的当日/区间消息和图片提炼成给 ZOPC 会员精读的飞书 docx 日报。底层依赖本地 wx-cli 0.2.0+（含 attachments / extract 图片提取）、Claude 多模态读图、lark-cli 写飞书。触发词：「总结 XX 群」「XX 群聊精华」「帮我看看 XX 群最近聊了什么」「继续 XX 群」（增量）。
version: 0.2.0
metadata:
  requires:
    anyBins:
      - wx
      - lark-cli
---

# 微信群聊精华

把零散的微信群聊提炼成给会员精读的飞书日报，**减少爬楼焦虑**。只沉淀**值得带走**的内容：技巧、经验、坑、breaking news、心得、方法论、高质量分享。不写画像、流水账、争论叙事。

底层依赖：

- [wx-cli](https://github.com/jackwener/wx-cli) ≥ **0.2.0**（含 `attachments` + `extract` 图片支持）
- [lark-cli](https://github.com/larksuite/lark-cli) 写飞书 docx
- Claude 多模态读图

> **Sandbox 提醒**
>
> `wx` 命令访问 `~/.wx-cli/` 和 `~/Library/Containers/com.tencent.xinWeChat/`，都在 Claude Code 默认 sandbox 之外。**每次 `wx` 调用都用 `dangerouslyDisableSandbox: true`**，不要先试一次 sandboxed 再回退。用户可以 `/sandbox` 持久化放行这两个路径。

## 用户提问工具

本 skill 多处需要向用户提问。按优先级选工具：

1. 优先用 runtime 提供的 `AskUserQuestion` / `request_user_input` 类工具，能 batch 就 batch（一次问多个）。
2. 没有就发编号纯文本，让用户回复编号。

## 前置检查

按顺序跑，第一个失败就停下来，告诉用户下一步执行什么命令。**不要替用户跑 sudo**。

1. **wx-cli ≥ 0.2.0** — `~/.cargo/bin/wx --version`。如果只装了 npm 版（通常是 0.1.10），跑：
   ```bash
   cargo install --git https://github.com/jackwener/wx-cli.git --branch main --force
   # 首次编译 ~16 分钟（拉所有依赖）
   ```
   `/usr/local/bin/wx` 是 npm 装的旧版（0.1.10，没 attachments / extract），优先用 `~/.cargo/bin/wx`。
2. **lark-cli 已登录** — `lark-cli auth list`。没登录就让用户跑 `lark-cli auth login` 扫码。
3. **`~/.wx-cli` 归属当前用户** — 历史上 `sudo wx init` 会把这目录 chown 给 root，导致后续所有非 sudo 调用失败：
   ```bash
   ls -la ~/.wx-cli/ 2>/dev/null | head -5
   ```
   不是 `$(whoami)` 时让用户跑：
   ```bash
   sudo chown -R $(whoami) ~/.wx-cli
   sudo rm -f ~/.wx-cli/daemon.pid ~/.wx-cli/daemon.sock
   ```
4. **wx-cli 已初始化** — `wx sessions` 能返回数据。失败提示用户 `wx init`（微信需登录态，macOS 首次还要 `sudo codesign --force --deep --sign - /Applications/微信.app`）。注意 macOS 微信 4.x 升级后签名会失效，每次升级要重做。
5. **微信 4.x 正在运行且已登录** — daemon 才能找到数据文件。
6. **macOS 数据目录探测**：wx-cli 0.1.x 自动探测会失败，需要手写 `~/.wx-cli/config.json`：
   ```json
   {
     "db_dir": "~/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/<wxid>_<suffix>/db_storage",
     "keys_file": "all_keys.json",
     "decrypted_dir": "decrypted",
     "wechat_process": "WeChat"
   }
   ```
   wx 0.2.0 是否自动 OK 待验证。如果 init 报 `未能自动检测到微信数据目录`，仍按上面方式手填。

## 偏好配置（EXTEND.md）

按优先级查找，第一个命中即用：

| 优先级 | 路径 | 范围 |
|---|---|---|
| 1 | `.wxgroupinsight/EXTEND.md` (项目根) | 项目 |
| 2 | `${XDG_CONFIG_HOME:-$HOME/.config}/wxgroupinsight/EXTEND.md` | XDG |
| 3 | `$HOME/.wxgroupinsight/EXTEND.md` | 用户 |

**没找到就走首次配置流程（BLOCKING）**，不要静默用默认值。

### 配置字段

`key: value` 或 `key=value`，`#` 注释，键大小写不敏感。

| 字段 | 类型 | 默认 | 用途 |
|---|---|---|---|
| `self_wxid` | string | 必填 | 自己的 wxid，用来识别自己发的消息 |
| `self_display` | string | 必填 | 简报里自己的显示名（如「辛一」） |
| `self_match` | list | — | 群里可能识别成自己的别名（个人微信名、群昵称等），用来在 sender 匹配时归一化为 self_display |
| `default_groups` | list | — | 用户没指定群名时默认要总结的群。第一项为主默认。**首次配置时 BLOCKING 询问** |
| `default_time_range` | string | `24h` | 用户没指定时间且无增量锚点时的默认范围。形如 `24h` / `7d` / `2026-05-14` |
| `data_root` | path | `{project_root}/wechat` | 简报存放根目录 |
| `publish` | `none` / `docx` | `none` | 简报生成后是否写飞书 docx |
| `feishu_tenant` | string | — | 飞书企业域名前缀（如 `vcn5y6q5vxhe`） |
| `feishu_wiki_token` | string | — | wiki 链接里的 node_token（`/wiki/<token>` 那段） |
| `feishu_doc_token` | string | — | wiki node 解析后的真实 docx token（`obj_token`），写入飞书时用这个 |

模板见 [EXTEND.md.example](EXTEND.md.example)。发布相关细节见 [references/publish.md](references/publish.md)。

### 首次配置（BLOCKING）

如果 EXTEND.md 不存在，按 3 步走完：

**第一步 — 自动探测 `self_wxid` 和 `self_display`**：

```bash
wx whoami --json 2>/dev/null        # 优先
wx sessions --json --limit 20       # 回退：扫自己发过的消息
```

**第二步 — 让用户选「平时要总结哪些群」（不能跳）**：

skill 不假设用户要总结哪个群。先列候选，让用户挑：

```bash
wx sessions --json --limit 50 | jq '[.[] | select(.username | endswith("@chatroom")) | {name: .display_name, id: .username, last: .last_message_time}] | sort_by(.last) | reverse'
```

把 top 8-15 个群（按最近活跃度）用 `AskUserQuestion` 列出，**支持多选**。用户也可以选「都不在列表里 / 我自己输入」走文本回退。

存到 `default_groups`（list）。第一项作为主默认，后续 `继续 / 总结昨天的` 这种不带群名的触发用它。

**第三步 — 一次 `AskUserQuestion` 批量收尾**：

- `self_wxid`（预填探测值）
- `self_display`（预填探测值）
- `default_time_range`（默认 `24h`）
- `data_root`（默认 `{project_root}/wechat`，可填绝对路径）
- 保存到哪：项目 / XDG / 用户

写入选定路径，回执：

```
偏好已存到 [path]。
默认会总结：<default_groups>
随时编辑修改默认值或加群。
```

继续主流程。

## 主流程

### Step 1: 解析请求

提取：

- **群名**（允许部分匹配）。**没明确给群名时**：
  - 触发词带"全部 / 所有默认群" → 遍历 `default_groups` 全跑一遍
  - 其他情况 → 用 `default_groups[0]` 作主默认
  - `default_groups` 为空（罕见，配置被手动改坏） → BLOCKING 问用户
- **时间范围**：
  - "最近 1 天" / "今天" → 1 天
  - "最近 3 天" / "最近 7 天" / "这周" → 对应天数
  - "5 月 10 号" → 单日
  - "5 月 10 号到 5 月 14 号" → 区间
  - "继续" / "接着上次" / 没指定时间 → **增量模式**：读 `history.json` 的 `last_message_time` 作为起点
  - 没指定且无 history.json → 用 EXTEND.md 的 `default_time_range`

转换为绝对的 `--since YYYY-MM-DD --until YYYY-MM-DD`（用本机日期）。

### Step 2: 定位群 + 解析文件夹路径

```bash
wx contacts --query "<群名>" --json
```

过滤 `username` 以 `@chatroom` 结尾的条目。多个匹配 → `AskUserQuestion` 让用户选；零匹配 → 回退到 `wx sessions --json` 搜，再问用户。

文件夹路径：

```
{data_root}/{group_id}-{清洗后的群名}/
```

**群名清洗**：`/ \ : * ? " < > | NUL` 和控制字符替换为 `_`，去掉尾部点和空白。emoji 和中文保留。

**群名变更检测**：列出 `{data_root}/` 下所有以 `{group_id}-` 开头的文件夹，找到后缀不同的就 rename 成新名字。

### Step 3: 拉消息

小批量（单日，通常 < 200 条）直接 pipe JSON 到 agent：

```bash
wx history "<群名或群 id>" --since YYYY-MM-DD --until YYYY-MM-DD -n 5000 --json
```

大批量（周报 / 月报，> 200 条）先存到 `$TMPDIR` 避免裸数据吃 context：

```bash
wx history "<群>" --since DATE --until DATE -n 5000 --json > "$TMPDIR/wx-messages.json"
jq 'length' "$TMPDIR/wx-messages.json"
```

然后用 `jq` 切片 + `Read offset/limit` 取需要的部分。

注意：

- `--since` 含当日，`--until` 也含当日。
- `-n 5000` 是上限，活跃群可以提到 20000。
- 时区敏感，建议用 `timestamp` 字段二次过滤一遍。
- **拆分**：范围 > 7 天 OR 消息 > 500 条时，**按 3 天分段做小简报 + 一份总览**，强压成单份会大幅丢话题。

**增量模式**：拉完后丢掉 `timestamp <= history.json 中 last_message_time` 的消息。剩 0 条就告诉用户 "上次摘要后没有新消息，已跳过" 然后退出。

### Step 3.5: 解析消息字段（wx 0.2.0）

`wx history --json` 返回消息对象数组。0.2.0 起 `sender` 是**完整群昵称**（如 `088-张翠山-南京-产品`），不是个人昵称。容忍字段缺失：

- `local_id` — 消息 id，用作骨架的锚点
- `sender` — **群昵称**（0.2.0 起；0.1.x 是个人昵称）
- `content` — 文本载荷：
  - 普通文本 → 直接用
  - `[图片] local_id=NNNN` → 走 Step 3.7 图片提取
  - `[表情]` / `[视频]` / `[文件]` → 除非被讨论否则跳过
  - `[链接] <title>` → 标题就是信息，引用并归功分享者
  - `[引用] ... ↳ ...` → 引用块，第一行是当前发言，↳ 后是被引用原文（可能跨多行）
  - `[系统] ... revokemsg` → 撤回，排除出简报和统计
- `time` / `timestamp` — 展示用 `MM-DD HH:MM`

### Step 3.6: self 替换

`sender` 命中 `EXTEND.md` 里 `self_match` 列表中任意一个 → 显示为 `self_display`（如「辛一」）。配置例：

```
self_display: 辛一
self_match: ["Sin", "辛一 - 北京 - 独立开发", "SOULSIN14"]
```

不再做歧义昵称扫描（0.2.0 的群昵称已经足够稳定）。

### Step 3.7: 提取图片（关键，wx 0.2.0+）

图片是 takeaway 的视觉证据。**先强制重启 daemon**，让 `message_resource.db` 重新解密，避免漏当天后期发的图：

```bash
# 0) 强制 daemon 重启，刷新 message_resource.db 缓存
~/.cargo/bin/wx daemon stop && rm -f ~/.wx-cli/daemon.{pid,sock}
~/.cargo/bin/wx sessions --limit 1 >/dev/null    # 触发 daemon 启动 + db 解密

# 1) 拿图列表（attachment_id + 群昵称 + 时间）
~/.cargo/bin/wx attachments "<群名>" --since YYYY-MM-DD --until YYYY-MM-DD --kind image -n 200 --json \
  > /tmp/imgs.json

# 2) 双轨脚本批量解（A 路 wx extract 直接 / B 路 _M.dat 旁路）
scripts/extract-images.sh /tmp/imgs.json {folder}/images/YYYY-MM-DD/
```

**为什么必须重启 daemon**：daemon 启动时一次性解密 `message_resource.db` 到 `~/.wx-cli/cache/`，之后微信新写入的图片记录走 WAL 增量，daemon 不会自动重新解密。当天后期的图（特别是 attachments 列出但 extract 报"找不到本地 .dat"的）十有八九是这个原因。stop + start 后强制重新全量解密一次，问题立刻消失。

详细机制和脚本双轨设计见 [references/image-extraction.md](references/image-extraction.md)。

### Step 3.8: 多模态读图判价值

对解出的每张图用 `Read` 工具（Claude 原生多模态）。按 [references/image-extraction.md §3](references/image-extraction.md) 标价值：

- **高**：实操证据 / 信息图 / 官方回复截图 → 嵌入对应 takeaway
- **中**：上下文截图 → 看是否补强 takeaway
- **低**：段子 / 表情 / 模糊截图 → 跳过

**一日通常 ≤ 5 张图入选**。如果图里有"纯文字消息漏掉的新发现"（例如 5.13 那张张翠山截图揭示了腾讯官方在评论区透露的「选择到这里」批量勾选小技巧），**必须把这个发现写进 takeaway 正文**，不能只放图。

### Step 4-6: 三轮生成

骨架 → 正文 → 审计。方法论在这里；输出风格规范在 [references/output-format.md](references/output-format.md)，进入 Round 2 前加载。

#### Round 1 — 骨架（only takeaway）

按时间顺序通读消息。**只挑值得带走的精华**，按品类分组：

```
== 候选 takeaway（按品类）==
🛠 技巧:
  - ChatGPT Plus → Pro 升级套路（@王传健_小乙 10:51, @Darcy 10:51）
  - cmux + Warp 工具链（@辛一 10:04, @张翠山 14:25）
💡 心得方法:
  - AI 电商生图 RAG（@清风徐来 13:19, @辛一 13:28）
  - Minimax 跑邮件（@王传健_小乙 12:04）
🌊 个人经验（坑）:
  - ...
📰 Breaking News:
  - 微信原生群聊总结上线 + 官方「选择到这里」（@清风徐来 11:11, @张翠山 11:26）
  - 5.22 北京路演细节（@和平-啥都会 17:08）
📚 待整合:
  - 全群消息自动总结开源方案（@哆哆 11:52）
```

**不要列**：群友画像、Top 发言、争论叙事、段子、撤回、流水账。

#### Round 2 — 正文 + 图片嵌入

按 [output-format.md](references/output-format.md) 的格式写每个 takeaway：

```
### 标题
byline（蓝色 mention + 灰色时间）
<callout> 一句话 insight </callout>
正文展开（引用、代码、表格）
<image token="..." /> 或 <grid cols="2"> 多图 </grid>
caption（灰色 + mention 蓝色）
&nbsp;
```

**图片嵌入规则**：

- 单图：takeaway 末尾接 `<image url="..." width="..." height="..." />` + caption
- 多图：用 `<grid cols="2">` 2 列布局
- 图片来源：Step 3.7 解出的 png/jpg，**先用 url 字段提交首次 update**（详见下方 Step 9.2），飞书会下载并分配 token；后续 update 时改用 token 引用

#### Round 3 — 审计

通读检查：

- 文本风格：有没有 `——`？专业名词大小写规范了吗？byline 时间齐了吗？
- 内容定位：有没有画像 / Top / 争论叙事 / 段子混进来？
- 图片：高价值图全嵌入了吗？低价值图清除了吗？图独家信息写进正文了吗？

### Step 7: 写简报文件

- 单日 → `{folder}/YYYY-MM-DD.md`
- 区间 → `{folder}/YYYY-MM-DD_YYYY-MM-DD.md`
- 同名存在则覆盖。

### Step 8: 更新 history（两份文件）

只为增量模式服务，**不再维护用户画像**。

#### `history.json` — 单条记录

每次运行覆写：

```json
{
  "group_id": "12345@chatroom",
  "group_name": "AI 交流群",
  "folder": "12345@chatroom-AI 交流群",
  "last_digest": {
    "file": "2026-05-14.md",
    "date_range": "2026-05-14",
    "generated_at": "2026-05-14T22:30:00+08:00",
    "message_count": 387,
    "last_message_time": "05-14 23:45"
  }
}
```

#### `history-digests.jsonl` — append-only

每次运行追加一行，按时间升序，仅供归档查询。

### Step 9: 发布到飞书 docx

`publish` = `none` 时跳过。否则按 [references/publish.md](references/publish.md)：

> **日期顺序约定：最新一天永远在文档最顶部，老日期在下面。** 会员打开第一眼就是今天的。

**9.1 推送正文（文本部分）**

- 先 `lark-cli docs +fetch --doc <token> -q '.data.markdown'` 拿现状，`grep "^# 20"` 找出**当前文档最顶部那个 H1 日期**
- 用 `insert_before --selection-by-title "# <当前最顶部日期>"` 把新简报插在最前
- 重做某天：`replace_range --selection-by-title "# YYYY-MM-DD"`
- 首次或全文重排：`overwrite`（谨慎）

**9.2 上传图片拿 file_token**

```bash
cd wechat/{folder}/images/YYYY-MM-DD     # 必须 cd，media-insert 拒绝绝对路径
lark-cli docs +media-insert --doc <doc_token> --file ./<filename> --caption "..."
# 输出 file_token，图被追加到文档末尾
```

**9.3 fetch 拿当前 image block 的 token**

```bash
lark-cli docs +fetch --doc <doc_token> -q '.data.markdown' > /tmp/doc.md
# 找到飞书重新分配的 <image token="..." width="..." height="..."/>
```

**9.4 把图搬到对应 takeaway 后面**

重写简报 .md（image block 引用 fetch 拿到的最新 token，用 `<grid>` 排版），用 `replace_range` 替换当日整段。

**失败处理**：每步失败简报 `.md` 必须保留；下次重试只跑剩余步骤。

### 完成清单

- [ ] `{folder}/YYYY-MM-DD.md` 已写（含 image token 引用 + grid 布局）
- [ ] `{folder}/images/YYYY-MM-DD/` 解出的 png/jpg 齐全
- [ ] `{folder}/history.json` 已覆写
- [ ] `{folder}/history-digests.jsonl` 已 append
- [ ] 飞书 docx 已更新（含 inline 图片）
- [ ] 图独家信息已写进 takeaway 正文（不是只放图）

## 存储结构

```
{data_root}/                                  # 默认 {project_root}/wechat/
└── {group_id}-{group_name}/                  # 如 44423648925@chatroom-ZOPC Builders 正式群/
    ├── history.json
    ├── history-digests.jsonl
    ├── 2026-05-13.md
    ├── 2026-05-14.md
    └── images/
        ├── 2026-05-13/
        │   ├── 787_<sender>.jpg
        │   ├── 937_<sender>.png
        │   └── ...
        └── 2026-05-14/
```

## wx-cli 速查（0.2.0+）

| 命令 | 用途 |
|---|---|
| `~/.cargo/bin/wx --version` | 确认 ≥ 0.2.0 |
| `wx sessions --json` | 列最近会话 |
| `wx contacts --query "<名>" --json` | 模糊匹配联系人 / 群 |
| `wx history "<群>" --since DATE --until DATE -n N --json` | 拉群消息（sender 是群昵称） |
| `wx attachments "<群>" --since DATE --until DATE --kind image --json` | 列群图片，拿 attachment_id |
| `wx extract <aid> -o file.jpg` | 解码单张图（macOS 通常失败，用 scripts/extract-images.sh 旁路） |
| `wx daemon status` / `stop` | daemon 生命周期 |

所有 `wx` 命令加 `--json` 输出机器可读 JSON（默认是 YAML）。

## 故障速查

| 现象 | 原因 | 让用户跑 |
|---|---|---|
| `Operation not permitted` / `~/.wx-cli` access denied | sandbox 拦了 | 加 `dangerouslyDisableSandbox: true`；持久化 `/sandbox` |
| `无法写入 ~/.wx-cli` / Permission denied | 目录归 root | `sudo chown -R $(whoami) ~/.wx-cli && sudo rm -f ~/.wx-cli/daemon.{pid,sock} && wx daemon start` |
| `wx history` 卡死 / 超时 / 空 | daemon 卡住 | `wx daemon stop && rm -f ~/.wx-cli/daemon.{pid,sock} && wx daemon start` 再试 |
| `no keys` / `init required` | 微信重启后密钥过期 | 微信登录态下 `wx init --force` |
| `wx contacts` 零行但群明明存在 | 折叠群 / daemon 没索引 | `wx sessions --json` 搜；不行重启 daemon |
| 时间窗对不上 | 日期格式或时区 | 强制 `YYYY-MM-DD`；用 `timestamp` 字段本地复核 |
| 应有数据却空 | `-n` 上限太低 | 提高（如 20000）重拉 |

**异常时的恢复顺序**：

1. 微信是否运行？
2. `~/.wx-cli` 是否归 `$(whoami)`？
3. daemon 是否健康？(`wx daemon status`)
4. 重启 daemon
5. 终极：`wx init --force`（微信登录态）

**不要在 skill 里自动重试**，每次失败都给用户清晰的诊断 + 下一步命令。

## 限制

- **图片由 wx 0.2.0 + 旁路脚本支持**。macOS 上 `_M.dat` 文件实际是明文 PNG/JPG（仅后缀误导），详见 [references/image-extraction.md](references/image-extraction.md)。一日通常 ≤ 5 张图入选，纯娱乐图（段子、表情）必须删。
- **本机时区**。日期解析按 agent 本地时区。跨时区群成员的时间戳与他们的钟可能对不上，简报不要靠时间推断"睡眠"或"位置"。
- **`/usr/local/bin/wx` 是 npm 装的旧版（0.1.10，无 attachments / extract）**。优先 `~/.cargo/bin/wx`（cargo install 装的 0.2.0+）。
