# 简报输出格式

定义本 skill 的简报样式。`Round 2 写正文`前加载本文件，写作时严格对照执行。

---

## 0. 产品定位（最重要）

> **给 ZOPC 会员一个精读的地方。减少爬楼的麻烦和看群消息的焦虑。**

只沉淀**值得带走的精华**——技巧、经验、坑、breaking news、心得、方法论、高质量的文章分享。

**不写**（再有趣也不写）：

- 群友画像、Top 发言数据
- 争论叙事、流派站队
- 闲聊段子、撤回 / 系统消息
- 情绪吐槽、单纯抬杠
- 运营视角的"信号 / 趋势观察"（这是给运营者看的，不是给会员看的）
- 任何"今天 X 和 Y 讨论了什么"的流水账

---

## 1. 文档结构

```
# YYYY-MM-DD

> ***N 条消息 · M 人发言***

---

## 🛠 技巧
### takeaway 1 标题
### takeaway 2 标题

## 💡 心得方法
### takeaway 标题

## 🌊 个人经验
### takeaway 标题

## 📰 Breaking News
### takeaway 标题

## 📚 待整合工作流
### takeaway 标题
```

H1 = 日期，下面挂分类 H2，每个 takeaway 用 H3。

---

## 2. 摘要行（H1 下方）

格式（**加粗 + 斜体**，独立段落，**不用引用块 `>`**）：

```markdown
***N 条消息 · M 人发言***
```

不要写时间范围、贡献者数、"今天最热"、"X 个能带走" 等装饰文字。**只两个数字**。

---

## 3. 分类 H2

固定品类，按优先级排序：

| 品类 | emoji | callout 背景色 |
|---|---|---|
| **技巧** | 🛠 | `light-blue` |
| **心得方法** | 💡 | `light-purple` |
| **个人经验**（坑、教训） | 🌊 | `light-yellow` |
| **Breaking News** | 📰 | `light-orange` |
| **待整合工作流** | 📚 | `pale-gray` |

如果一个品类下没有任何 takeaway，**整个 H2 省略**，不要写"今日无技巧"之类的占位。

---

## 4. 每个 takeaway 的结构

```markdown
### takeaway 主标题（H3）

<text color="gray">**@贡献者** · HH:MM</text>

<callout emoji="🎯" background-color="<品类色>">

一句话的核心 insight 高亮。**这一句**是会员能"带走"的部分。

</callout>

[详细展开正文：代码、表格、引用、补充说明]
```

### 4.1 标题（H3）

- 是主信息，**不**带 emoji 装饰
- 用名词短语，不用句号
- 例：「Claude Code 权限配置 JSON」「中国身份订阅 OpenAI 的唯一靠谱方案」

### 4.2 贡献者 byline

- 格式：`<text color="blue">**@<微信本名>**</text> <text color="gray">· HH:MM</text>`
- `@用户名` **蓝色加粗**（mention 感），时间 **灰色**，两段分开包
- 个人微信昵称（wx-cli 返回的 sender），不是群昵称的「ZOPC编号-XX-地点-职业」
- **每个贡献者都必须有时间**（HH:MM），没有时间不要发布
- 多个贡献者用顿号串：
  ```
  <text color="blue">**@张翠山**</text> <text color="gray">· 15:05</text>、<text color="blue">**@欣浩**</text> <text color="gray">· 09:26</text>
  ```
- 自己（self）显示为 `**@辛一**`，不是 `**@Sin**`
- 正文里 inline 提到群友时也按这个 mention 样式：`<text color="blue">**@张翠山**</text>`

### 4.3 Callout = insight 高亮

callout 装的是**一句最有用的话**（核心要点）。**不是**用来当标题装饰，**不是**用来塞贡献者署名。

- emoji 统一用 `🎯`，背景色按品类
- 子块限制：callout 不支持代码块、表格、图片（要放外面）
- 高亮内容要**直接可用**，例如：
  - 技巧 → 一句话点透怎么用
  - 坑 → 一句话点透对策 / 关键限制
  - Breaking News → 一句金句引用或核心事实

### 4.4 正文展开

- 代码块、表格、补充论证、限制说明都放在 callout **外面**
- 同一品类 H2 下多个 H3 之间用 `&nbsp;` 占位段落强制空行
- 不要在每个 takeaway 末尾加 footer 或装饰

---

## 5. 文本风格（红线）

### 5.1 禁止符号 / 句式

- **禁止 `——`（破折号）**。AI 味太浓。改用句号、逗号、冒号、括号、单独成句
- 禁止 "总之" "综上所述" "可以说" "值得一提的是" 等转折填充
- 禁止 "今天最热" "全天延烧" "暴论" "鄙视链" 等情绪化叙事词
- **禁止"挑 N 件"/"X 个 takeaway"/"今日精选 N 条" 这种列举式开场**。直接进内容。摘要行只给数字（`N 条消息 · M 人发言`），不要 meta 描述简报本身有几条
- 禁止 emoji 满天飞（除分类标题、callout 头、状态标识外，正文不出现）

### 5.2 专业名词大小写规范化

即便原消息小写，简报里**一律按业界规范**写：

| 原文（消息） | 简报 |
|---|---|
| warp | **Warp** |
| obsidian | **Obsidian** |
| codex | **Codex** |
| claude | **Claude** |
| open / openai | **OpenAI** |
| api | **API** |
| cli | **CLI** |
| ide | **IDE** |
| ip | **IP** |
| ai | **AI** |
| json | **JSON** |
| mcp | **MCP** |
| gpt | **GPT** |
| google play | **Google Play** |
| visa | **Visa** |
| bitget | **Bitget** |
| typeless | **Typeless** |
| mac / macos | **Mac** / **macOS** |
| fun_asr | **FunASR** |
| github | **GitHub** |

中文产品名保留原样：豆包、讯飞听见、微信、招行、千问、百度网盘、飞书。

### 5.3 引用

- 直接引用用 `「」` 而非 `""`
- 引用时**保留原话风格**（错字、口语化、表情符号都按原样），那是说话人的特征
- callout 里的核心 insight **不要加引号**（除非真的是别人原话）

### 5.4 留白

- 同级 H3 之间用 `&nbsp;` 占位段落
- 分类 H2 之间用 `---` 水平分隔线
- 段落之间用空行

---

## 5.5 图片嵌入

群消息里的图片是 takeaway 的关键视觉证据（产品截图、价格表、官方回复、工具界面、流程图）。**做法是 inline 到对应 H3 后面**，不放文末附录。

### 哪些图入选

只挑**对会员有用**的图嵌入。判断标准见 [image-extraction.md §3](image-extraction.md)：

| 价值 | 类型 | 是否嵌入 |
|---|---|---|
| 高 | 实操证据 / 信息图 / 官方回复截图 | ✅ |
| 中 | 上下文截图（如果补强 takeaway） | 看情况 |
| 低 | 段子 / 表情包 / 模糊截图 | ❌ |

通常**一日 14 张图里有价值的 2-5 张**。

### 单图嵌入（image + caption）

H3 takeaway 末尾紧跟 image block + 一行灰色 caption：

```markdown
### Claude Code 权限配置 JSON

<text color="blue">**@张翠山**</text> <text color="gray">· 15:05</text>

<callout emoji="🎯" background-color="light-blue">
... insight ...
</callout>

... 正文 ...

<image token="<file_token>" width="1060" height="2376" align="center"/>

<text color="gray">**@张翠山** 15:05 · Claude Code 权限设置截图</text>
```

### 多图嵌入（grid 分栏）

同一个 takeaway 有 2 张相关图时，用 `<grid cols="2">` 排成两列：

```markdown
<grid cols="2">
<column>

<image token="<token1>" width="3024" height="1774" align="center"/>

<text color="gray">**@辛一** 14:18 · cmux 多 workspace 总控</text>

</column>
<column>

<image token="<token2>" width="1920" height="1008" align="center"/>

<text color="gray">**@张翠山** 14:28 · Warp + Claude Code 多任务</text>

</column>
</grid>
```

**关键格式细节**：

- `<column>` 内每个 block（image / 段落）**前后必须各空一行**（飞书 markdown 块分隔规则）
- `<image>` 的 `width` / `height` 取真实像素（从 `wx attachments` 拿的图片原尺寸或 ImageMagick `identify` 拿）
- caption 用 `<text color="gray">...</text>` 整段灰色
- caption 里的 mention `**@xxx**` 不要再用 `<text color="blue">` 包（会嵌套，飞书可能渲染异常）

### 新发现 / 图独家信息要写进正文

图片里如果有"纯文字消息漏掉的信息"（比如腾讯官方在评论区透露的小技巧、产品页的隐藏价格、错误码截图的具体含义），**必须把这条新发现写进 takeaway 正文**，不能只放图。会员先扫文字，没看图前应该已经能拿到核心信息。

### 图片来源

简报里的图来自 `wechat/{group_folder}/images/YYYY-MM-DD/` 目录（旁路脚本提取），从 `wx attachments` 那拿群昵称和时间。技术细节见 [image-extraction.md](image-extraction.md)。

---

## 6. 完整示例（单 takeaway）

```markdown
### Claude Code 权限配置 JSON

<text color="gray">**@张翠山** · 15:05</text>

<callout emoji="🎯" background-color="light-blue">

allow 只放 mcp / 读类工具，deny 显式封掉 `rm -rf`、`curl | sh`、`git push --force` 三类核弹动作。比 `--dangerously-skip-permissions` 安全 10 倍。

</callout>

\`\`\`json
"permissions": {
  "allow": ["mcp__*", "Web*", "Read", "Glob", "Grep", "LS", "Task*"],
  "deny": ["Bash(rm -rf:*)", "Bash(curl * | sh)", "Bash(curl * | bash)", "Bash(git push * --force:*)"],
  "defaultMode": "bypassPermissions"
}
\`\`\`

仅 CLI 端有效。IDE 插件里反复试都不起作用（**@Demo** 实测）。要做权限隔离，用 CLI，不用插件。

&nbsp;
```

---

## 7. 写作流程提醒

Round 2 写正文前：

1. 先读本文件一遍，把规则装进脑子
2. 列骨架时已经按品类分组（技巧 / 心得 / 坑 / breaking news / 待整合）
3. 写每个 takeaway 时先写 **callout 一句话**（最难也最值钱），再写正文展开
4. **同时看当日所有图片**（多模态 Read），决定哪些图嵌入哪个 takeaway
5. 写完通读检查：
   - 有没有 `——`？删
   - 专业名词大小写对了吗？
   - byline 是不是都加了时间？
   - 有没有写群友画像 / Top 发言 / 流水账叙事？删
   - 图片是不是嵌在对应 takeaway 后面（不是文末附录）？
   - 图片新发现是不是写进正文了（不是只放图）？
