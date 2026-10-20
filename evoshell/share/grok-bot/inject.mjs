// Injects a stylesheet built from the evoshell theme into Grok Bot.
// Usage: node inject.mjs [--once] [--dump] [--wait=ms]
import { readFileSync, existsSync, watch } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const PORT = process.env.GROK_THEME_PORT || 9339;
const here = dirname(fileURLToPath(import.meta.url));
const stateHome = process.env.XDG_STATE_HOME || join(homedir(), '.local/state');
const themePath = join(stateHome, 'evoshell/theme.json');
const colorsPath = join(homedir(), '.themes/current/colors.toml');
const templatePath = join(here, 'theme.css');
const once = process.argv.includes('--once');
const dump = process.argv.includes('--dump');

function argValue(name) {
  const hit = process.argv.find((a) => a.startsWith(`${name}=`));
  return hit ? hit.slice(name.length + 1) : null;
}

const waitMs = Number(argValue('--wait') ?? (once || dump ? 800 : 60000));

const FALLBACK = {
  green: '#a6e3a1',
  yellow: '#f9e2af',
  peach: '#fab387',
  teal: '#94e2d5',
  mauve: '#cba6f7',
  pink: '#f5c2e7',
  sky: '#89dceb',
  maroon: '#eba0ac',
};

function readToml(path) {
  if (!existsSync(path)) return {};
  const out = {};
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const match = line.match(/^([A-Za-z0-9_]+)\s*=\s*"?(#[0-9A-Fa-f]{6})"?/);
    if (match) out[match[1]] = match[2];
  }
  return out;
}

function distinct(toml, key, sameAs) {
  const value = toml[key];
  if (!value || value.toLowerCase() === String(sameAs || '').toLowerCase()) return '';
  return value;
}

function buildCss() {
  const theme = JSON.parse(readFileSync(themePath, 'utf8'));
  const toml = readToml(colorsPath);
  const palette = {
    ...FALLBACK,
    ...theme,
    green: toml.color2 || FALLBACK.green,
    yellow: toml.color3 || FALLBACK.yellow,
    teal: toml.color6 || FALLBACK.teal,
    pink: toml.color5 || FALLBACK.pink,
    mauve: toml.icon_text || toml.color5 || FALLBACK.mauve,
    peach: distinct(toml, 'color11', toml.color3) || FALLBACK.peach,
    sky: distinct(toml, 'color14', toml.color6) || FALLBACK.sky,
    maroon: distinct(toml, 'color9', toml.color1 || theme.urgent) || FALLBACK.maroon,
    urgent: theme.urgent || toml.color1 || '#f38ba8',
  };
  const css = existsSync(templatePath) ? readFileSync(templatePath, 'utf8') : '';
  return css.replace(/\{\{(\w+)\}\}/g, (_, key) => palette[key] ?? '');
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function targets() {
  try { return await (await fetch(`http://127.0.0.1:${PORT}/json`)).json(); } catch { return null; }
}

function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let id = 0;
  const pending = new Map();
  ws.onmessage = (e) => {
    const message = JSON.parse(e.data);
    if (message.id && pending.has(message.id)) {
      pending.get(message.id)(message);
      pending.delete(message.id);
    }
  };
  const send = (method, params = {}) => new Promise((resolve) => {
    const i = ++id;
    pending.set(i, resolve);
    ws.send(JSON.stringify({ id: i, method, params }));
  });
  return new Promise((resolve, reject) => {
    ws.onopen = () => resolve({ ws, send });
    ws.onerror = reject;
  });
}

const applyJs = (css) => `(() => { const id='evoshell-theme'; let s=document.getElementById(id); if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement).appendChild(s);} s.textContent=${JSON.stringify(css)}; })()`;

const sessions = new Map();
async function attach(target) {
  const session = await connect(target.webSocketDebuggerUrl);
  sessions.set(target.id, session);
  session.ws.onclose = () => sessions.delete(target.id);
  await session.send('Page.enable');
  if (dump) {
    const expression = `(() => { const vars={}; for (const sh of document.styleSheets) { let rules; try { rules=sh.cssRules } catch { continue } for (const r of rules) { if (r.style) for (const p of r.style) if (p.startsWith('--')) { (vars[r.selectorText]??={})[p]=r.style.getPropertyValue(p).trim(); } } } return JSON.stringify({title:document.title, url:location.href, vars}); })()`;
    const result = await session.send('Runtime.evaluate', { expression, returnByValue: true });
    console.log(result.result?.result?.value);
    return;
  }
  const css = buildCss();
  const source = `document.addEventListener('DOMContentLoaded', () => ${applyJs(css)});`;
  await session.send('Page.addScriptToEvaluateOnNewDocument', { source });
  await session.send('Runtime.evaluate', { expression: applyJs(css) });
  console.log('themed', target.title || target.url);
}

async function reapplyAll() {
  const css = buildCss();
  for (const session of sessions.values()) {
    await session.send('Runtime.evaluate', { expression: applyJs(css) });
  }
}

const deadline = Date.now() + waitMs;
while (Date.now() < deadline) {
  if (await targets()) break;
  await sleep(Math.min(200, Math.max(0, deadline - Date.now())));
}

if (!(await targets())) {
  if (once || dump) process.exit(0);
}

if (!once && !dump) {
  let timer;
  const refresh = () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      reapplyAll().catch((error) => console.error('reapply', error?.message));
    }, 150);
  };
  watch(themePath, refresh);
  if (existsSync(colorsPath)) watch(colorsPath, refresh);
}

do {
  const pages = (await targets()) || [];
  if (!pages.length && !once) {
    if (sessions.size === 0 && !(await targets())) {
      console.log('app gone, exiting');
      process.exit(0);
    }
  }
  for (const page of pages) {
    if (page.type === 'page' && !sessions.has(page.id) && page.webSocketDebuggerUrl) {
      try { await attach(page); } catch (error) { console.error('attach failed', error?.message); }
    }
  }
  if (once || dump) process.exit(0);
  await sleep(2000);
} while (true);
