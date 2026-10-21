// Low-volume research helper: render pages with system Microsoft Edge via Playwright and save their text.
// - Uses a FRESH, isolated browser profile (./.pw-profile) — never the user's normal Edge profile, cookies or saved logins.
// - If a site requires login, run with HEADLESS=0 and let the human sign in manually in the visible window.
// - Polite pacing (several seconds between pages). Intended for a handful of pages, not scraping.
//
// Usage:  node fetch-pages.mjs <outDir> <url> [url...]
// Env:    HEADLESS=0  -> show the browser window
//         WAIT_MS=n   -> extra settle time per page (default 4000)
import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const [, , outDir, ...urls] = process.argv;
if (!outDir || urls.length === 0) {
  console.error('usage: node fetch-pages.mjs <outDir> <url> [url...]');
  process.exit(2);
}
const headless = process.env.HEADLESS !== '0';
const settleMs = Number(process.env.WAIT_MS ?? 4000);
const profileDir = path.join(here, '.pw-profile');

const ctx = await chromium.launchPersistentContext(profileDir, {
  channel: 'msedge',
  headless,
  viewport: { width: 1400, height: 1000 },
  locale: 'en-US',
});
const page = ctx.pages()[0] ?? (await ctx.newPage());
await fs.mkdir(outDir, { recursive: true });

const slug = (u) => u.replace(/^https?:\/\//, '').replace(/[^a-z0-9]+/gi, '_').slice(0, 160);

for (const url of urls) {
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 90_000 });
    for (let i = 0; i < 30; i++) {
      const t = await page.title();
      if (!/just a moment|attention required|verify you are human/i.test(t)) break;
      await page.waitForTimeout(2000);
    }
    await page.waitForLoadState('networkidle', { timeout: 30_000 }).catch(() => {});
    await page.waitForTimeout(settleMs);
    // Optional: expand collapsed sections by visible text (CLICK_TEXTS="Changelogs,Show").
    for (const t of (process.env.CLICK_TEXTS ?? '').split(',').map((s) => s.trim()).filter(Boolean)) {
      const loc = page.getByText(t, { exact: true });
      const n = await loc.count();
      for (let i = 0; i < n; i++) await loc.nth(i).click({ timeout: 3000 }).catch(() => {});
      if (n) await page.waitForTimeout(2500);
    }
    const title = await page.title();
    const { text, spoilers, links } = await page.evaluate(() => {
      const spoilerNodes = [...document.querySelectorAll('[class*="spoiler" i]')];
      const seen = new Set();
      const links = [...document.querySelectorAll('a[href*="/comments/"]')]
        .map((a) => ({ href: a.href.split('?')[0], text: (a.textContent || '').trim().replace(/\s+/g, ' ') }))
        .filter((l) => l.text && !seen.has(l.href) && seen.add(l.href));
      return {
        text: document.body?.innerText ?? '',
        spoilers: spoilerNodes.map((n) => n.textContent?.trim()).filter(Boolean),
        links,
      };
    });
    const linkBlock = links.length ? `\n\n--- THREAD LINKS ---\n${links.map((l) => `${l.text}\t${l.href}`).join('\n')}` : '';
    const body = `URL: ${url}\nTITLE: ${title}\nFETCHED: ${new Date().toISOString()}\n\n${text}\n\n--- SPOILER BLOCKS ---\n${spoilers.join('\n---\n')}${linkBlock}`;
    const file = path.join(outDir, `${slug(url)}.txt`);
    await fs.writeFile(file, body, 'utf8');
    console.log(`OK  ${title}  ->  ${path.basename(file)} (${text.length} chars)`);
  } catch (e) {
    console.log(`ERR ${url}: ${e.message.split('\n')[0]}`);
  }
  await page.waitForTimeout(3000 + Math.floor(Math.random() * 3000));
}
await ctx.close();
