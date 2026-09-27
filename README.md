## 安装（Agent Skill）

```bash
npx skills add ai798-Lab/wxgroupinsight
```

macOS / Windows / Linux 通用（需 Node 18+），安装后重启 Agent 即可使用。

---

# wxgroupinsight

把指定微信群的当日聊天 + 图片提炼成给会员**精读**的飞书日报，**减少爬楼焦虑**。

只沉淀**值得带走**的部分：技巧 / 经验 / 坑 / Breaking News / 心得 / 方法论 / 高质量分享。**不写**画像、流水账、争论叙事、段子表情。

## 数据流

```
WeChat 4.x 本地数据库
   ↓  wx-cli 0.2.0+ (cargo install --git main)
   ↓     wx history    —— 拉群消息（sender 已是群昵称）
   ↓     wx attachments —— 拿群图列表
   ↓  scripts/extract-images.sh
   ↓     绕过 wx-cli macOS _M.dat 后缀盲点，把 .dat 还原为明文 png/jpg
Claude
   ↓  按 takeaway 三轮生成（骨架 → 正文 → 审计）
   ↓  多模态读图，挑高价值的嵌入对应 takeaway
{folder}/YYYY-MM-DD.md + images/YYYY-MM-DD/
   ↓  lark-cli docs +update / +media-insert / +fetch
飞书 docx 日报（H1=日期、H2=品类、H3=takeaway、图片 inline grid）
```

## 快速开始

### 1. 装 wx-cli 0.2.0+

npm 上是旧版（0.1.10，没图片支持），要从 GitHub main 编译：

```bash
cargo install --git https://github.com/jackwener/wx-cli.git --branch main --force
~/.cargo/bin/wx --version    # ≥ 0.2.0
```

首次编译 ~16 分钟。

### 2. 装并登录 lark-cli

```bash
brew install larksuite/tap/lark-cli   # 或参考 lark-cli 仓库
lark-cli auth login
```

### 3. wx 初始化

```bash
# macOS：先给微信签名（升级后重做）
sudo codesign --force --deep --sign - /Applications/微信.app

# 重启微信，登录到主界面
open /Applications/微信.app

# init（首次会探测数据目录；探测失败手写 ~/.wx-cli/config.json，详见 SKILL.md 前置检查）
sudo wx init
sudo chown -R $(whoami) ~/.wx-cli
```

### 4. 配 EXTEND.md

```bash
cp EXTEND.md.example .wxgroupinsight/EXTEND.md
# 编辑：self_wxid / self_display / self_match
# 启用 publish：填 feishu_doc_token（用 lark-cli wiki spaces get_node 从 wiki_token 解析）
```

### 5. 在 Claude Code 里触发

```
总结 ZOPC Builders 正式群 今天
```

Claude 会按 [SKILL.md](SKILL.md) 流程跑完整 9 步：拉消息 + 提图 + 三轮生成 + 推送飞书 docx。

## 项目结构

```
SKILL.md                          主流程（前置检查 → Step 1-9）
EXTEND.md.example                 配置模板
.wxgroupinsight/EXTEND.md         你的实际配置（gitignore）
scripts/
  └── extract-images.sh           wx-cli macOS _M.dat 绕行脚本（dd 改后缀）
references/
  ├── output-format.md            简报样式规范（callout / grid / byline 蓝灰）
  ├── image-extraction.md         图片提取技术细节 + Claude 多模态判价值
  ├── publish.md                  飞书 docx 写入流程（含 token 复用、cd + 相对路径坑）
  ├── feishu-table-design.md      多维表格 schema（备用方案，当前不走）
  └── profiles.md                 用户画像规范（旧版方案，当前不维护）
wechat/                           简报和图片归档（gitignore）
  └── {群id}-{群名}/
      ├── YYYY-MM-DD.md
      ├── history.json
      ├── history-digests.jsonl
      └── images/YYYY-MM-DD/
templates/digest.html.example     HTML 长图模板（备用方案，当前不走）
scripts/render-image.mjs          长图渲染器（同上，备用）
```

## 简报样式

打开 [一个真实样本](https://vcn5y6q5vxhe.feishu.cn/wiki/TUS5wTGxai9WU2kktZvcKPABnCg) 看效果。结构：

```
# YYYY-MM-DD
***N 条消息 · M 人发言***

## 🛠 技巧 / 💡 心得方法 / 🌊 个人经验 / 📰 Breaking News / 📚 待整合

### takeaway 标题
@贡献者 · HH:MM（蓝色 + 灰色）
> 🎯 callout 一句话 insight（不同品类不同背景色）
正文展开
<image token="..." /> 或 <grid cols="2"> 多图 </grid>
caption
```

## 关键限制

- **wx-cli 0.2.0 在 macOS 上 `wx extract` 命令失败**（`_M.dat` 后缀盲点），用 [scripts/extract-images.sh](scripts/extract-images.sh) 旁路
- **lark-cli `docs +media-insert` 拒绝绝对路径**，必须 cd 到图片目录用 `./` 相对路径
- **image token 每次 update 会被飞书重新分配**，复用前先 fetch 拿最新 token
- **本机时区**：跨时区群成员的时间戳不准

## 故障

| 现象 | 处理 |
|---|---|
| `wx extract` 报「找不到本地 .dat」 | macOS 是 `_M.dat` 后缀，用 `scripts/extract-images.sh` |
| `unsafe file path` (media-insert) | cd 到图片目录用 `./` 相对路径 |
| 图嵌入后 update 又变成 placeholder | overwrite 前先 fetch 拿最新 token |
| `wx history` 卡住 | `wx daemon stop && rm -f ~/.wx-cli/daemon.{pid,sock}` 重启 |
| 签名过期（微信升级后） | `sudo codesign --force --deep --sign - /Applications/微信.app` |

更多见 [SKILL.md](SKILL.md) 末尾的故障速查表。
