# 飞书多维表格日更样式设计

为 "每天一条记录" 这个使用场景设计。目标：

- **能扫**：今日视图一眼看完关键 5 字段，不淹没在长文本里。
- **能感受**：图卡墙以分享长图当封面，比读字数更直观。
- **能筛**：分类标签、状态字段支持多维度筛选。
- **能回看**：按群归档视图把同一群的历史串起来。

> **本表已配置完成**（2026-05-14）。下方 §1 / §2 是最终 schema，§4 是历史一键配置命令（保留作参考，本表已跑过）。
>
> 表格定位：
> - URL：`https://vcn5y6q5vxhe.feishu.cn/wiki/SamPwh17Bikm6YklqJqcH2Aon7b?table=tbluTuHYImEtR89d&view=vewTR4hyDa`
> - wiki_token：`SamPwh17Bikm6YklqJqcH2Aon7b`
> - **base_token（解析后）**：`DEsBbgXBZaMbYxsLm9wcyGJknCx`
> - table_id：`tbluTuHYImEtR89d`

## 1. 字段 schema

11 个核心字段 + 1 个系统字段。字段名是中文（飞书表里中文字段名读起来更顺，也方便后续筛选）。

| 序号 | 字段名 | 飞书类型 | 备注 |
|---|---|---|---|
| 1 | 日期 | 日期（5） | YYYY-MM-DD；与「群 id」组成幂等键 |
| 2 | 群名 | 单行文本（1） | 显示用 |
| 3 | 群 id | 单行文本（1） | `xxx@chatroom`，幂等查重用 |
| 4 | 消息数 | 数字（2） | 用于排序 / 趋势图 |
| 5 | 看点摘要 | 多行文本（1） | **≤ 80 字**，简报标题感的一句话，今日视图主要靠它扫读 |
| 6 | Top 发言 | 单行文本（1） | `蛙总 92 / 老王 58 / 阿喵 41`，` / ` 分隔，最多 3 人 |
| 7 | 分类标签 | 多选（4） | 从简报里抽 `🛠 工具/技术`、`💸 钱与消费` 等，便于话题筛选 |
| 8 | 简报正文 | 多行文本（1） | .md 原文，给"我想看全文"的人 |
| 9 | 分享长图 | 附件（17） | YYYY-MM-DD.png，图卡墙的封面 |
| 10 | 状态 | 单选（3） | `✅ 已发布` / `⏳ 草稿` / `❌ 失败` |
| 11 | 群类型 | 单选（3） | 可选，手动维护：`AI 技术` / `投资` / `朋友` / `工作` |
| 系统 | 创建时间 | 自动 | 不需要建，飞书默认 |

### 1.1 多选 / 单选的选项预设

**分类标签**（多选，建议 8 个固定 + 后续可加）：

| 选项 | 颜色 (1-15) |
|---|---|
| 🛠 工具/技术 | 1（蓝） |
| 📦 产品发布 | 5（紫） |
| 📰 新闻/市场 | 2（青） |
| 💬 观点辩论 | 9（橙） |
| 😄 笑料/段子 | 4（黄） |
| 📚 学习分享 | 3（绿） |
| 💸 钱与消费 | 6（粉） |
| 🍜 生活日常 | 11（褐） |

**状态**（单选）：

| 选项 | 颜色 |
|---|---|
| ✅ 已发布 | 3（绿） |
| ⏳ 草稿 | 4（黄） |
| ❌ 失败 | 9（橙） |

**群类型**（单选，按你的实际群类型增删）：

| 选项 | 颜色 |
|---|---|
| AI 技术 | 1（蓝） |
| 投资 | 6（粉） |
| 朋友 | 3（绿） |
| 工作 | 2（青） |
| 其它 | 7（灰） |

## 2. 视图设计

4 个视图，按用途分。

### 2.1 本周看点（默认视图）

- 类型：网格视图
- **可见字段顺序**：日期 → 群名 → 看点摘要 → Top 发言 → 消息数 → 分类标签 → 状态
- 隐藏：简报正文、分享长图、群 id、群类型（不需要在扫读时看到）
- **筛选**：`日期 >= TODAY() - 7`
- **排序**：日期 DESC
- 行高：中（让 80 字的看点摘要能完整显示）

这是日常打开表格第一眼看到的视图。一周内的所有群、所有简报扫一眼就完。

### 2.2 图卡墙（卡片视图）

- 类型：卡片视图
- **卡片封面**：分享长图（取第一张附件）
- **卡片字段**（顺序）：群名 + 日期 → 看点摘要 → Top 发言
- **筛选**：状态 = `✅ 已发布`
- **排序**：日期 DESC

这是给"我想看图"的人。长图本身就是排版好的，所以图卡墙变成一面"每天一张海报"的视觉墙。

### 2.3 按群归档（网格 + 分组）

- 类型：网格视图
- **分组字段**：群名（升序）
- **排序**（组内）：日期 DESC
- **可见字段**：日期 → 看点摘要 → 分类标签 → 消息数 → 分享长图（缩略图）
- 不筛选，看全量

用于回看某一群的全部历史，看话题演变。

### 2.4 全部（admin 视图）

- 类型：网格视图
- 所有字段可见
- 不筛选、按日期 DESC

调试和清理数据用。

## 3. 写入时的格式规范

由 SKILL.md `Step 9.1` 在调 `lark-base +record-upsert` 之前组织字段值。

| 字段 | 写入值 | 来源 |
|---|---|---|
| 日期 | 毫秒级 timestamp（飞书日期字段要求） | `Date.parse('YYYY-MM-DD')` |
| 群名 | 字符串 | Step 2 拿到的群名 |
| 群 id | 字符串 | Step 2 拿到的 `xxx@chatroom` |
| 消息数 | 数字 | 简报排行榜第一行的 `共 N 条消息` |
| 看点摘要 | **≤ 80 字纯文本** | 从开场综述中**抽一句标题感的话**，不是简单截断。规则见 §3.1 |
| Top 发言 | `A 92 / B 58 / C 41` | 排行榜前三条 |
| 分类标签 | `["🛠 工具/技术", "💸 钱与消费"]` | 抓简报里所有 `## {emoji} ` 标题，按预设选项 match |
| 简报正文 | .md 原文（不超过 50KB 字段限制即可） | 直接读文件 |
| 分享长图 | 附件，走 `+record-upload-attachment` | YYYY-MM-DD.png |
| 状态 | `✅ 已发布` | 默认；失败的话由 Claude 自己改写 |
| 群类型 | 不写入 | 由用户手动维护 |

### 3.1 看点摘要的生成规则

不要直接截开场综述前 80 字 —— 那是给报纸读者看的，扫读时太钝。规则：

1. 抽取开场综述里**最具张力的一条线**（通常是一场辩论、一个意外、一个反转）。
2. 改写成**标题感的短句**，去掉时间副词、连接词、铺垫。
3. 保留专有名词（人名、产品名、数字）。
4. **不**带句号结尾，**不**带引号。
5. ≤ 80 字，超了就再砍。

**好例子**：

```
蛙总连续第三周空 SPY 被翻旧账，临近收盘 40 分钟沉默
```

```
Claude 4.7 实测：复杂任务更稳，日常代码补全 4.6 体感更快
```

**坏例子**（直接截原文）：

```
今天最热的是 Claude Opus 4.7 实测，蛙总下午装上后第一反应是「比 4.6 慢一倍」，随后整群进入复测模式
```

太长、没有信息密度。

### 3.2 幂等：同一天重跑

`Step 9.1` 写入前先按 `(日期, 群 id)` 查重：

```bash
lark-cli base +record-search --base-token <token> --table-id tbluTuHYImEtR89d \
  --filter '{"conjunction":"and","conditions":[
    {"field_name":"群 id","operator":"is","value":["<group_id>"]},
    {"field_name":"日期","operator":"is","value":["ExactDate","<毫秒时间戳>"]}
  ]}'
```

- 命中 → `+record-upsert`（覆盖更新，状态改为 `✅ 已发布`）
- 没命中 → `+record-batch-create` 新增一条

## 4. 一键配置命令（等 lark-cli 装好后跑）

> **前置**：`lark auth login` 已完成，且操作账号对该 wiki 节点有「可编辑」权限。

### 4.1 拿到真实的 base_token

```bash
# wiki 节点解析
lark-cli wiki spaces get_node --token SamPwh17Bikm6YklqJqcH2Aon7b
# 在输出里找 obj_token，赋给 BASE_TOKEN 变量
export BASE_TOKEN=<obj_token>
export TABLE_ID=tbluTuHYImEtR89d
```

### 4.2 查现有字段（确认是空表还是要清理）

```bash
lark-cli base +field-list --base-token $BASE_TOKEN --table-id $TABLE_ID
```

如果已有字段不在我们的 schema 里，先用 `+field-delete` 删掉（不可逆，先确认）。

### 4.3 建字段

按下面顺序逐个建。每条命令的 JSON 结构参考 lark-base skill 的 `lark-base-shortcut-field-properties.md`。

```bash
# 1. 日期
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"日期","type":5,"property":{"date_formatter":"yyyy-MM-dd","auto_fill":false}}'

# 2. 群名
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"群名","type":1}'

# 3. 群 id
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"群 id","type":1}'

# 4. 消息数
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"消息数","type":2,"property":{"formatter":"0"}}'

# 5. 看点摘要
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"看点摘要","type":1}'

# 6. Top 发言
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"Top 发言","type":1}'

# 7. 分类标签（多选，type=4）
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"分类标签","type":4,"property":{"options":[
    {"name":"🛠 工具/技术","color":1},
    {"name":"📦 产品发布","color":5},
    {"name":"📰 新闻/市场","color":2},
    {"name":"💬 观点辩论","color":9},
    {"name":"😄 笑料/段子","color":4},
    {"name":"📚 学习分享","color":3},
    {"name":"💸 钱与消费","color":6},
    {"name":"🍜 生活日常","color":11}
  ]}}'

# 8. 简报正文
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"简报正文","type":1}'

# 9. 分享长图（附件，type=17）
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"分享长图","type":17}'

# 10. 状态（单选，type=3）
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"状态","type":3,"property":{"options":[
    {"name":"✅ 已发布","color":3},
    {"name":"⏳ 草稿","color":4},
    {"name":"❌ 失败","color":9}
  ]}}'

# 11. 群类型
lark-cli base +field-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --json '{"field_name":"群类型","type":3,"property":{"options":[
    {"name":"AI 技术","color":1},
    {"name":"投资","color":6},
    {"name":"朋友","color":3},
    {"name":"工作","color":2},
    {"name":"其它","color":7}
  ]}}'
```

### 4.4 建视图

```bash
# 本周看点（默认）— 改名 + 配置
lark-cli base +view-rename --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id vewTR4hyDa --view-name "本周看点"
# 然后配置可见字段、筛选、排序（见 4.5）

# 图卡墙
lark-cli base +view-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-name "图卡墙" --view-type "gallery"

# 按群归档
lark-cli base +view-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-name "按群归档" --view-type "grid"

# 全部
lark-cli base +view-create --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-name "全部" --view-type "grid"
```

### 4.5 视图配置

每个视图建好后按下面分别配：

```bash
# 本周看点 — 筛选 + 排序 + 可见字段
lark-cli base +view-set-filter --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id <本周看点 view_id> \
  --json '{"conjunction":"and","conditions":[
    {"field_name":"日期","operator":"isGreater","value":["7","DaysAgo"]}
  ]}'

lark-cli base +view-set-sort --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id <本周看点 view_id> \
  --json '{"sort_info":[{"field_name":"日期","desc":true}]}'

lark-cli base +view-set-visible-fields --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id <本周看点 view_id> \
  --json '{"field_names":["日期","群名","看点摘要","Top 发言","消息数","分类标签","状态"]}'

# 图卡墙 — 卡片配置（封面用分享长图）
lark-cli base +view-set-card --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id <图卡墙 view_id> \
  --json '{"cover_field_name":"分享长图","cover_fit_mode":"fit_height"}'

lark-cli base +view-set-filter --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id <图卡墙 view_id> \
  --json '{"conjunction":"and","conditions":[
    {"field_name":"状态","operator":"is","value":["✅ 已发布"]}
  ]}'

lark-cli base +view-set-sort --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id <图卡墙 view_id> \
  --json '{"sort_info":[{"field_name":"日期","desc":true}]}'

# 按群归档 — 分组
lark-cli base +view-set-group --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id <按群归档 view_id> \
  --json '{"group_info":[{"field_name":"群名","desc":false}]}'

lark-cli base +view-set-sort --base-token $BASE_TOKEN --table-id $TABLE_ID \
  --view-id <按群归档 view_id> \
  --json '{"sort_info":[{"field_name":"日期","desc":true}]}'
```

**注意**：

- 筛选语法 `"isGreater" / "DaysAgo"` 是飞书 base view filter 的占位符，具体参数名以 `lark-cli base +view-set-filter` 的 reference 为准（执行前先读它）。
- `+view-set-card` 是 gallery view 特有，确认 `view-type` 是 `gallery`。
- 字段 ID vs 字段名：飞书 API 允许混用，但建议先 `+field-list` 拿真实 `field_id`，避免 rename 后失效。

## 4.6 实际字段 / 视图 ID（已建好，运行时直接用）

字段 ID 映射：

| 字段名 | field_id | 类型 |
|---|---|---|
| 索引（primary） | `fldWgpuvW9` | text |
| 日期 | `fldLM9QM4Q` | datetime |
| 群名 | `fldWK4JRGC` | text |
| 群 id | `fldoi66aAD` | text |
| 消息数 | `fld808svOa` | number |
| 看点摘要 | `fldzyjByD9` | text |
| Top 发言 | `fldgYW4G5t` | text |
| 分类标签 | `fldqw35NTn` | select (multi) |
| 简报正文 | `fldu8479k0` | text |
| 分享长图 | `fld7ocfVXk` | attachment |
| 状态 | `fldYFz8Wxv` | select |
| 群类型 | `fld6q7f8ij` | select |

视图 ID 映射：

| 视图名 | view_id | 类型 | 配置 |
|---|---|---|---|
| 本周看点 | `vewTR4hyDa` | grid | sort: 日期 DESC；可见 8 字段 |
| 图卡墙 | `vewONBdyow` | gallery | cover=分享长图；sort: 日期 DESC；filter: 状态=已发布；可见 5 字段 |
| 按群归档 | `vewZxUcyRX` | grid | group: 群名 ASC；sort: 日期 DESC；可见 7 字段 |
| 全部 | `vew7Fcg12Q` | grid | sort: 日期 DESC；全部字段 |

## 4.7 lark-cli 1.0.23 实际语法注意

reference 文档与实际有偏差：

- `+view-set-sort` 的 `--json` **不**能传纯数组，必须 object：`{"sort_config":[{"field":"X","desc":true}]}`
- 颜色用 `hue + lightness`（不是 `color`）：`{"hue":"Blue","lightness":"Lighter"}`，合法 hue: Red/Orange/Yellow/Lime/Green/Turquoise/Wathet/Blue/Carmine/Purple/Gray
- 字段类型用字符串（`text`/`number`/`select`/`datetime`/`attachment`），不是数字
- 顶层是 `name`（不是 `field_name`）
- select 的 `options` 创建时不要传 `id`（后端生成）

## 5. 跟 SKILL.md 的接口

SKILL.md `Step 9.1` 写入时使用本设计的字段。简化代码（伪）：

```javascript
// 从生成的简报 .md 抽取
const summary = extractSummary(mdBody);        // 看点摘要（≤80 字）
const tags = extractCategoryEmojis(mdBody);    // ["🛠 工具/技术", ...]
const topThree = parseTopThree(mdBody);        // "蛙总 92 / 老王 58 / 阿喵 41"

// 调用 lark-base skill
larkBase.upsert({
  base_token: BASE_TOKEN,
  table_id: TABLE_ID,
  match_fields: { 日期: dateMs, '群 id': groupId },
  fields: {
    日期: dateMs,
    群名: groupName,
    '群 id': groupId,
    消息数: messageCount,
    看点摘要: summary,
    'Top 发言': topThree,
    分类标签: tags,
    简报正文: mdBody,
    状态: '✅ 已发布',
  },
});

// 附件单独走
larkBase.uploadAttachment({
  base_token: BASE_TOKEN,
  table_id: TABLE_ID,
  record_id: recordId,
  field_name: '分享长图',
  file_path: 'wechat/{folder}/YYYY-MM-DD.png',
});
```

## 6. 后续可加

不在第一版做，但记下来：

- **趋势图**：用 dashboard 模块，按"日期 × 消息数"画折线，可视化群活跃度。
- **群活跃热力图**：按周聚合，看看哪个群在哪天最热。
- **关键词云**：从所有简报正文里抽 top-N 关键词，做月度看板。
- **自动归档冷群**：长期 0 消息的群在状态里标 `❌ 失败`，便于清理。

这些都是有了一周数据后再做的事。
