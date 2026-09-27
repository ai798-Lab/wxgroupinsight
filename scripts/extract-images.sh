#!/usr/bin/env bash
# 把 wx attachments 列出的图片批量拉到本地（明文 PNG/JPG/GIF/...）
#
# 用法:
#   scripts/extract-images.sh <attachments-json> <output-dir> [wx_base_dir]
#
# 三轨：
#   A. 优先用 wx extract 直接解码（wx-cli 0.2.0+ 标准 .dat 路径 ok）
#   A'. wx extract 产出 wxgf/HEVC 封装时（微信 4.x 新格式），剥 16B 头取裸 HEVC 流，ffmpeg 解一帧成 PNG
#   B. 失败时回退：从报错抓 md5，find _M.dat 文件并 cp（macOS 微信 4.x 的 _M 后缀，wx-cli 当前不识别）
#
# 起因 1：wx 0.2.0 macOS 下 wx extract 只查 .dat / _h.dat / _t.dat，但 macOS 微信存图常用 _M.dat / _h_M.dat / _t_M.dat
# 后缀（medium 尺寸）。这些 _M 后缀文件实际是明文 PNG/JPG/GIF/WebP，cp 出来改后缀就能用。
# 起因 2（2026-05）：微信 4.x 把大图存成 wxgf 容器（magic 77 78 67 66），wx extract 能解密但产出仍是 wxgf/HEVC，
# file/sips 都识别不了。实测 wxgf 头之后即裸 HEVC bitstream（首个 00 00 00 01 起始码起），ffmpeg 可直接解一帧。
# 依赖 ffmpeg（brew install ffmpeg）。

set -e

JSON="${1:?usage: $0 <attachments-json> <output-dir> [wx_base]}"
OUT="${2:?usage: $0 <attachments-json> <output-dir> [wx_base]}"
WX_BASE="${3:-$HOME/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/a520zyn_0b28}"
WX_BIN="${WX_BIN:-$HOME/.cargo/bin/wx}"

mkdir -p "$OUT"

# 按 magic bytes 推断扩展名
detect_ext() {
  local f="$1"
  local h
  h=$(xxd -p -l 12 "$f" 2>/dev/null | tr -d '\n')
  case "$h" in
    89504e47*)    echo "png" ;;
    ffd8ff*)      echo "jpg" ;;
    47494638*)    echo "gif" ;;
    52494646*)    echo "webp" ;;
    424d*)        echo "bmp" ;;
    *)            echo "bin" ;;
  esac
}

jq -c '.[]' "$JSON" | while read -r row; do
  aid=$(echo "$row" | jq -r '.attachment_id')
  lid=$(echo "$row" | jq -r '.local_id')
  sender=$(echo "$row" | jq -r '.sender' | tr '/' '_')

  out_base="$OUT/${lid}_${sender}"
  out_tmp="${out_base}.tmp"

  # === A 路：直接 wx extract ===
  log=$("$WX_BIN" extract "$aid" -o "$out_tmp" --overwrite 2>&1 || true)

  if [ -f "$out_tmp" ] && [ -s "$out_tmp" ]; then
    magic=$(xxd -p -l 4 "$out_tmp" 2>/dev/null | tr -d '\n')
    # === A' 路：wxgf 容器（magic 77786766）→ 剥头取裸 HEVC → ffmpeg 解一帧 ===
    if [ "$magic" = "77786766" ]; then
      off=$(xxd -p "$out_tmp" | tr -d '\n' | grep -bo '00000001' | head -1 | cut -d: -f1)
      if [ -n "$off" ] && command -v ffmpeg >/dev/null 2>&1; then
        byte=$(( off / 2 ))
        tail -c +$(( byte + 1 )) "$out_tmp" > "${out_tmp}.hevc"
        if ffmpeg -y -loglevel error -i "${out_tmp}.hevc" -frames:v 1 "${out_base}.png" 2>/dev/null && [ -s "${out_base}.png" ]; then
          rm -f "$out_tmp" "${out_tmp}.hevc"
          echo "✓ A' ${lid} (${sender}) → png (wxgf/HEVC)"
          continue
        fi
        rm -f "${out_tmp}.hevc"
      fi
      rm -f "$out_tmp"
      echo "✗ ${lid} (${sender}) — wxgf 解码失败（缺 ffmpeg 或无 HEVC 流）"
      continue
    fi
    fmt=$(echo "$log" | grep -oE 'format: [a-z]+' | head -1 | awk '{print $2}')
    # wx 报 hevc 但已是标准图时以 magic 为准；wxgf 已在上面处理
    case "$fmt" in hevc|wxgf|"") fmt=$(detect_ext "$out_tmp") ;; esac
    [ "$fmt" = "bin" ] && fmt="dat"
    mv "$out_tmp" "${out_base}.${fmt}"
    echo "✓ A ${lid} (${sender}) → ${fmt}"
    continue
  fi

  # === B 路：从 log 抓 md5，find _M.dat 兜底 ===
  md5=$(echo "$log" | grep -oE 'md5=[0-9a-f]{32}|md5: [0-9a-f]{32}' | grep -oE '[0-9a-f]{32}' | head -1)
  if [ -z "$md5" ]; then
    echo "✗ ${lid} (${sender}) — 无 md5 (.dat 也没下载)"
    continue
  fi

  # 优先级 full > _h_M > _M > _t_M
  dat=$(find "$WX_BASE/msg/attach" -name "${md5}_M.dat" 2>/dev/null | head -1)
  [ -z "$dat" ] && dat=$(find "$WX_BASE/msg/attach" -name "${md5}_h_M.dat" 2>/dev/null | head -1)
  [ -z "$dat" ] && dat=$(find "$WX_BASE/msg/attach" -name "${md5}_t_M.dat" 2>/dev/null | head -1)

  if [ -z "$dat" ]; then
    echo "✗ ${lid} (${sender}) — md5=${md5} 但找不到 _M.dat"
    continue
  fi

  fmt=$(detect_ext "$dat")
  [ "$fmt" = "bin" ] && fmt="dat"
  cp "$dat" "${out_base}.${fmt}"
  echo "✓ B ${lid} (${sender}) → ${fmt} (旁路 _M.dat)"
done
