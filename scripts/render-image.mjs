#!/usr/bin/env node
// 把 Markdown 简报 + meta 套进 HTML 模板，用本机 Chrome 截图为长图。
//
// 用法:
//   node scripts/render-image.mjs \
//     --md wechat/{group}/2026-05-14.md \
//     --out wechat/{group}/2026-05-14.png \
//     --template templates/digest.html.example \
//     --meta '{"group_name":"AI 交流群","date":"2026-05-14","message_count":387,"top":"蛙总 92 / 老王 58 / 阿喵 41","record_url":"https://example.feishu.cn/base/..."}' \
//     [--width 1080] [--chrome /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome]

import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';
import QRCode from 'qrcode';
import puppeteer from 'puppeteer-core';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, '..');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (!k.startsWith('--')) continue;
    const v = argv[i + 1];
    args[k.slice(2)] = v;
    i++;
  }
  return args;
}

const DEFAULT_CHROME_PATHS = {
  darwin: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  linux: '/usr/bin/google-chrome',
  win32: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
};

function resolveChromePath(explicit) {
  if (explicit) return explicit;
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  return DEFAULT_CHROME_PATHS[process.platform];
}

async function main() {
  const args = parseArgs(process.argv);
  const required = ['md', 'out', 'template', 'meta'];
  for (const k of required) {
    if (!args[k]) {
      console.error(`缺少参数 --${k}`);
      console.error('参考用法见文件头注释');
      process.exit(2);
    }
  }

  const mdPath = resolve(args.md);
  const outPath = resolve(args.out);
  const templatePath = resolve(args.template);
  const meta = JSON.parse(args.meta);
  const width = Number(args.width ?? 1080);
  const chromePath = resolveChromePath(args.chrome);

  const mdRaw = readFileSync(mdPath, 'utf-8');
  const template = readFileSync(templatePath, 'utf-8');

  // 把 .md 转 HTML（保留换行的 GFM 风格）
  marked.setOptions({ gfm: true, breaks: true });
  const bodyHtml = marked.parse(mdRaw);

  // 二维码：如果有 record_url 就生成 data URL，否则空
  let qrDataUrl = '';
  if (meta.record_url) {
    qrDataUrl = await QRCode.toDataURL(meta.record_url, {
      errorCorrectionLevel: 'M',
      margin: 1,
      width: 240,
      color: { dark: '#111', light: '#fff' },
    });
  }

  // 简单的 {{key}} 替换。模板里要用什么字段都加进来。
  const replacements = {
    group_name: meta.group_name ?? '',
    date: meta.date ?? '',
    message_count: String(meta.message_count ?? ''),
    top: meta.top ?? '',
    record_url: meta.record_url ?? '',
    qr_data_url: qrDataUrl,
    body_html: bodyHtml,
    generated_at: new Date().toLocaleString('zh-CN', { hour12: false }),
  };

  let html = template;
  for (const [k, v] of Object.entries(replacements)) {
    html = html.replaceAll(`{{${k}}}`, v);
  }

  // 写到临时文件，让 Chrome 用 file:// 加载（避免命令行长度限制）
  const tmpDir = mkdtempSync(join(tmpdir(), 'wxgi-'));
  const htmlPath = join(tmpDir, 'digest.html');
  writeFileSync(htmlPath, html, 'utf-8');

  let browser;
  try {
    browser = await puppeteer.launch({
      executablePath: chromePath,
      headless: 'new',
      args: ['--no-sandbox', '--disable-dev-shm-usage'],
    });
    const page = await browser.newPage();
    await page.setViewport({ width, height: 800, deviceScaleFactor: 2 });
    await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle0' });

    // 等模板里可能的字体/图片
    await page.evaluate(() => document.fonts ? document.fonts.ready : null);

    await page.screenshot({ path: outPath, fullPage: true, type: 'png' });
    console.log(`OK ${outPath}`);
  } finally {
    if (browser) await browser.close();
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
