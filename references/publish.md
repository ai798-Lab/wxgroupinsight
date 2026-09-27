# 发布：写入飞书 docx 文档

简报生成完后，按本文档把 markdown + 图片推到飞书云文档（docx 类型）。

> **当前实际产品形态**：飞书知识库里挂一个 docx 文档（`群精华日报`），每天一节 `# YYYY-MM-DD`，新日期插在最上面，老日期在下面。会员一处精读。
>
> 多维表格、长图模板都是早期探索，**目前不走**（保留 [feishu-table-design.md](feishu-table-design.md) 作为未来可能的备选）。

---

## 1. 一次性准备

### 1.1 lark-cli 登录

```bash
lark-cli auth list                # 看是否登录过
lark-cli auth login               # 没登录就跑这个，扫码
```

### 1.2 解析 wiki 链接拿真实 doc_id

用户给的链接通常是 `/wiki/<wiki_token>` 形式：

```bash
lark-cli wiki spaces get_node --params '{"token":"<wiki_token>"}'
# 输出 obj_token，obj_type 应为 docx
```

把 `obj_token` 写入 `EXTEND.md` 的 `feishu_doc_token` 字段。后续所有 `lark-cli docs` 命令用这个。

### 1.3 项目当前用的 doc

- URL：`https://vcn5y6q5vxhe.feishu.cn/wiki/TUS5wTGxai9WU2kktZvcKPABnCg`
- wiki_token：`TUS5wTGxai9WU2kktZvcKPABnCg`
- **doc_token（解析后）**：`I0RodmYG6oR5qlx86J5cJr4Jnmf`
- 标题：群精华日报

---

## 2. 每日发布流程

### 2.1 已经 fetch 过文档 → 决定是新插一日还是覆盖某日

**日期顺序约定：最新一天永远在文档最顶部，老日期在下面。** 会员打开文档第一眼就是今天的。

```bash
DOC=I0RodmYG6oR5qlx86J5cJr4Jnmf

# fetch 现状
lark-cli docs +fetch --doc $DOC -q '.data.markdown' > /tmp/doc-current.md
grep "^# 20" /tmp/doc-current.md            # 列出所有日期，第一个就是当前最顶部那天
```

| 场景 | 模式 |
|---|---|
| 文档全空（首次） | `overwrite` 推完整简报 |
| **新一天**（最常见） | `insert_before --selection-by-title "# <文档当前最顶部那天>"`，新日期落在最前 |
| 重做某一天 | `replace_range --selection-by-title "# YYYY-MM-DD"` 替换该日整段 |
| 全文重排 | `overwrite`（谨慎，会删所有内容） |

**`insert_before` 的 selection 选哪一天**：

- fetch markdown 后，找到第一个 `# YYYY-MM-DD` 标题（**位置上最靠前的**那个 H1，不论日期值大小）
- 用它作 `--selection-by-title`，新简报会插在它**之前**（也就是文档顶部）

例：当前文档顺序是 `# 2026-05-13`（在顶部）下面是更老日期。要插入 `# 2026-05-14`：

```bash
lark-cli docs +update --doc $DOC --mode insert_before \
  --selection-by-title "# 2026-05-13" \
  --markdown "$(cat 2026-05-14.md)"
```

结果：`# 2026-05-14` 落在最顶，`# 2026-05-13` 退到第二。

### 2.2 推送正文（不含图）

写完简报 .md 后，先把**纯文字**版本推上去（图片占位用「📷 见后」标记，或先空着）：

```bash
DIGEST="wechat/{group_folder}/YYYY-MM-DD.md"
lark-cli docs +update --doc $DOC --mode <mode> [--selection-by-title "..."] \
  --markdown "$(cat "$DIGEST")"
```

### 2.3 嵌入图片（关键，多坑）

**坑 1：必须 cd 到图片目录用相对路径**

```bash
# ❌ 报错 "unsafe file path"
lark-cli docs +media-insert --doc $DOC --file ~/images/1.png

# ✅
cd wechat/{group_folder}/images/YYYY-MM-DD
lark-cli docs +media-insert --doc $DOC --file ./787_xxx.jpg --caption "..."
```

**坑 2：media-insert 只追加到文档末尾**，没有「插到 H3 后」的参数。要 inline 必须：

1. 先 media-insert 把图传上去（追加到文末），拿到 `file_token`
2. `lark-cli docs +fetch` 拿当前文档的 markdown，找到飞书重新分配的 `<image token="..." width="..." height="..." align="center"/>` block
3. 用 `docs +update --mode replace_range` 把文末的 image block 删除 + 重写整段，把 image 引用搬到目标 H3 后面
4. 或者用 `--mode overwrite` 一次性推完整 markdown（含 image token 引用）

**坑 3：token 在每次 update / replace 时会被飞书重新分配**——同一张图（同一个 `file_token`）在 docx 里的 image block 引用 token 会变。**每次重写文档前必须先 fetch 拿最新 token**。

### 2.4 grid 排版（推荐）

多张图用 `<grid cols="2">` 排成 2 列，每列内放 image + caption：

```markdown
<grid cols="2">
<column>

<image token="<token1>" width="3024" height="1774" align="center"/>

<text color="gray">**@辛一** 14:18 · cmux 多 workspace 总控</text>

</column>
<column>

<image token="<token2>" width="1920" height="1008" align="center"/>

<text color="gray">**@张翠山** 14:28 · Warp + CC 多任务</text>

</column>
</grid>
```

**注意 column 内每个 block 前后要空行**（飞书 markdown 块分隔规则）。

---

## 3. 完整一日发布脚本（伪流程）

```bash
#!/usr/bin/env bash
DOC=I0RodmYG6oR5qlx86J5cJr4Jnmf
DAY=2026-05-13
GROUP_FOLDER="<群id>@chatroom-<群名>"
DIGEST="wechat/$GROUP_FOLDER/$DAY.md"
IMGDIR="wechat/$GROUP_FOLDER/images/$DAY"

# 1) 拉数据 + 提图
~/.cargo/bin/wx history "ZOPC Builders 正式群" --since $DAY --until $DAY -n 20000 --json > /tmp/zopc-$DAY.json
~/.cargo/bin/wx attachments "ZOPC Builders 正式群" --since $DAY --until $DAY --kind image -n 100 --json > /tmp/zopc-$DAY-imgs.json
scripts/extract-images.sh /tmp/zopc-$DAY-imgs.json "$IMGDIR"

# 2) Claude 根据 history.json + 图片 写简报 .md（含 H3 标题 + callout + byline + image token 占位符）
# 3) Claude 用多模态 Read 选 N 张高价值图

# 4) 先推一遍正文（暂不含 image token 引用）
lark-cli docs +update --doc $DOC --mode insert_before \
  --selection-by-title "# <existing earliest day>" \
  --markdown "$(cat "$DIGEST")"

# 5) cd 到图片目录，逐张 media-insert
cd "$IMGDIR"
for img in selected_imgs/*; do
  lark-cli docs +media-insert --doc $DOC --file "./$img" --caption "..."
done
cd -

# 6) fetch 拿到新分配的 image token
lark-cli docs +fetch --doc $DOC -q '.data.markdown' > /tmp/doc-with-imgs.md

# 7) Claude 把 image token 填到 .md 简报里对应位置 + grid 排版

# 8) 最终用 overwrite 或 replace_range 推完整版（图 inline）
lark-cli docs +update --doc $DOC --mode replace_range \
  --selection-by-title "# $DAY" \
  --markdown "$(cat "$DIGEST")"
```

---

## 4. 故障速查

| 现象 | 原因 | 处理 |
|---|---|---|
| `unsafe file path: --file must be a relative path` | media-insert 拒绝绝对路径 | `cd` 到图片目录用 `./xxx.png` |
| 图片 update 后变 placeholder | image token 失效（fetch 拿的是旧 token） | overwrite 前重新 fetch 拿最新 token |
| 误判"图片没插进去" | **图片 inline 后飞书会重新分配 block token**，原 media-insert 返回的 file_token 在文档里查不到了 | **验证图片只按"每天图片数量 + 尺寸"核对，绝不 grep 原始 file_token**。否则会误判成失败、把正确结果覆盖掉（血泪教训） |
| 同一 file_token 引用到正文被去重丢弃，块仍留文末 | 飞书一个 media token 只允许一个 block | 正确序列：media-insert 上传 → `delete_range` 删文末块释放 token → `replace_range` 引用该 token，飞书会从云端媒体重建 inline 块 |
| `param baseToken is invalid` / `not found` 在 docs 命令上 | wiki_token 当 doc_token 用了 | 先 `wiki spaces get_node` 解析拿 `obj_token` |
| caption 里 mention 不变蓝 | `<text color="gray">` 外层覆盖了内层 `<text color="blue">` | 拆成两个独立 text 标签段：`<text color="blue">**@xxx**</text> <text color="gray">11:26 · 描述</text>` |
| H3 之间间距太挤 | 飞书 H3 默认 margin 小 | 在同级 H3 之间插一行 `&nbsp;` 占位段落 |
| `unrecognized subcommand 'attachments'` | wx-cli 版本是 0.1.11 或更早 | 升级到 0.2.0+（[image-extraction.md §0](image-extraction.md)） |

---

## 5. 历史方案备忘（**不走**，只作未来参考）

- **多维表格**（[feishu-table-design.md](feishu-table-design.md)）：早期设计的 11 字段 + 4 视图 schema，至今未启用。如果未来要做"日报 → 表格归档"两层架构再启用。
- **HTML 长图**（`scripts/render-image.mjs` + `templates/digest.html.example`）：原本要做"可分享到微信群的精排长图"，后来发现 docx 直接更直观。`npm install` 装的 puppeteer-core + qrcode + marked 还在 `node_modules/`，要做时启用。
