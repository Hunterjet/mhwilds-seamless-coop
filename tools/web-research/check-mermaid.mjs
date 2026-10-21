// Validates every ```mermaid block in the given Markdown files with the real Mermaid parser (headless Edge).
// Usage: node check-mermaid.mjs <file.md> [more.md ...]   — exits 1 if any block fails to parse.
import { chromium } from 'playwright';
import fs from 'node:fs/promises';

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('usage: node check-mermaid.mjs <file.md> [more.md ...]');
  process.exit(2);
}

const blocks = [];
for (const file of files) {
  const text = await fs.readFile(file, 'utf8');
  const re = /```mermaid\r?\n([\s\S]*?)```/g;
  let m;
  while ((m = re.exec(text))) {
    blocks.push({ file, line: text.slice(0, m.index).split('\n').length, code: m[1] });
  }
}

const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage();
await page.setContent('<!doctype html><html><body></body></html>');
await page.addScriptTag({
  type: 'module',
  content: `import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
            mermaid.initialize({ startOnLoad: false });
            window.mermaidLib = mermaid;`,
});
await page.waitForFunction(() => !!window.mermaidLib, null, { timeout: 60_000 });
const version = await page.evaluate(() => window.mermaidLib.version ?? 'unknown');
console.log(`mermaid ${version}: checking ${blocks.length} block(s)`);

let failures = 0;
for (const b of blocks) {
  const err = await page.evaluate(async (code) => {
    try {
      await window.mermaidLib.parse(code);
      return null;
    } catch (e) {
      return String(e?.message ?? e);
    }
  }, b.code);
  if (err) {
    failures++;
    console.log(`FAIL ${b.file}:${b.line}\n  ${err.split('\n').slice(0, 4).join('\n  ')}`);
  } else {
    console.log(`ok   ${b.file}:${b.line}`);
  }
}
await browser.close();
process.exit(failures ? 1 : 0);
