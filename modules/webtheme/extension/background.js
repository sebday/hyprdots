const HOST = "com.evo.webtheme";

let port = null;
let reconnectTimer = null;
let nextId = 1;
const pending = new Map();
const cssCache = new Map();

function patternHost(pattern) {
  const match = String(pattern || "").match(/^[^:]+:\/\/([^/]+)/);
  return match ? match[1] : "";
}

function hostMatches(pattern, hostname) {
  const hostPat = patternHost(pattern);
  if (!hostPat) return false;
  if (hostPat === "*") return true;
  if (hostPat.startsWith("*.")) {
    const suffix = hostPat.slice(1);
    const bare = hostPat.slice(2);
    return hostname === bare || hostname.endsWith(suffix);
  }
  return hostname === hostPat;
}

function siteForHost(catalog, hostname) {
  const sites = catalog && Array.isArray(catalog.sites) ? catalog.sites : [];
  for (let i = 0; i < sites.length; i++) {
    const site = sites[i];
    if (!site || site.enabled === false) continue;
    const matches = Array.isArray(site.matches) ? site.matches : [];
    for (let j = 0; j < matches.length; j++) {
      if (hostMatches(matches[j], hostname)) return site;
    }
  }
  return null;
}

let nativeChain = Promise.resolve();

function sendNative(msg) {
  const run = () =>
    new Promise((resolve, reject) => {
      if (!port) connect();
      if (!port) {
        reject(new Error("native host not connected"));
        return;
      }
      const id = String(nextId++);
      pending.set(id, { resolve, reject });
      try {
        port.postMessage(Object.assign({ id }, msg));
      } catch (err) {
        pending.delete(id);
        reject(err);
        return;
      }
      setTimeout(() => {
        if (!pending.has(id)) return;
        pending.delete(id);
        reject(new Error("native host timeout"));
      }, 12000);
    });
  const queued = nativeChain.then(run, run);
  nativeChain = queued.then(
    () => undefined,
    () => undefined
  );
  return queued;
}

function applyBadge() {
  chrome.action.setBadgeText({ text: "" });
}

function extText(path, bust) {
  return fetch(chrome.runtime.getURL(path) + "?v=" + bust, { cache: "reload" }).then((response) => {
    if (!response.ok) throw new Error(path + " " + response.status);
    return response.text();
  });
}

const OVERLAY_KEY = "enabledOverlay";

async function loadOverlay() {
  try {
    const data = await chrome.storage.local.get(OVERLAY_KEY);
    const overlay = data[OVERLAY_KEY];
    if (overlay && typeof overlay === "object") return overlay;
  } catch {
    /* ignore */
  }
  return { siteEnabled: {} };
}

async function saveOverlay(overlay) {
  try {
    await chrome.storage.local.set({ [OVERLAY_KEY]: overlay });
  } catch {
    /* ignore */
  }
}

function applyOverlay(catalog, overlay) {
  if (!catalog || !overlay) return catalog;
  if (typeof overlay.enabled === "boolean") catalog.enabled = overlay.enabled;
  const map = overlay.siteEnabled && typeof overlay.siteEnabled === "object" ? overlay.siteEnabled : {};
  const sites = Array.isArray(catalog.sites) ? catalog.sites : [];
  for (let i = 0; i < sites.length; i++) {
    const site = sites[i];
    if (!site || !site.id || !Object.prototype.hasOwnProperty.call(map, site.id)) continue;
    site.enabled = map[site.id] !== false;
  }
  return catalog;
}

function applyEnabledFlag(catalog, flagText) {
  if (!catalog || typeof flagText !== "string") return catalog;
  const trimmed = flagText.trim();
  if (trimmed === "false") catalog.enabled = false;
  else if (trimmed === "true") catalog.enabled = true;
  return catalog;
}

async function patchOverlayFromMessage(msg) {
  const overlay = await loadOverlay();
  if (msg.type === "enabled") {
    overlay.enabled = msg.enabled !== false;
  } else if (msg.type === "set-enabled" && msg.siteId) {
    overlay.siteEnabled = overlay.siteEnabled || {};
    overlay.siteEnabled[msg.siteId] = msg.enabled !== false;
  }
  await saveOverlay(overlay);
}

async function hydrateOverlayFromNative() {
  try {
    const reply = await sendNative({ type: "list" });
    if (!reply || reply.ok === false) return;
    const siteEnabled = {};
    const sites = Array.isArray(reply.sites) ? reply.sites : [];
    for (let i = 0; i < sites.length; i++) {
      const site = sites[i];
      if (site && site.id) siteEnabled[site.id] = site.enabled !== false;
    }
    await saveOverlay({ enabled: reply.enabled !== false, siteEnabled });
  } catch {
    /* native host may not be up yet */
  }
}

async function readCatalog() {
  const bust = String(Date.now());
  const catalog = JSON.parse(await extText("catalog.json", bust));
  applyOverlay(catalog, await loadOverlay());
  const enabledText = await extText("enabled", bust).catch(() => "");
  applyEnabledFlag(catalog, enabledText);
  applyBadge();
  await resolveThemeJobs(catalog);
  return catalog;
}

async function cssReplyForHost(host) {
  const catalog = await readCatalog();
  const bust = String(Date.now());
  const colors = await extText("colors.css", bust).catch(() => "");
  const css = await cssForTab(catalog, colors, { url: "https://" + host + "/" }, bust);
  const site = siteForHost(catalog, host);
  const revision = await extText("revision", bust).catch(() => bust);
  return {
    ok: true,
    css: css || "",
    key: revision + "\n" + (site ? site.id + "\n" + site.css : ""),
  };
}

async function cssForTab(catalog, colors, tab, bust) {
  if (!catalog || catalog.enabled === false || !tab || !tab.url) return "";
  let hostname;
  try {
    if (!/^https?:/i.test(tab.url)) return "";
    hostname = new URL(tab.url).hostname;
  } catch {
    return "";
  }
  const site = siteForHost(catalog, hostname);
  if (!site || !site.css) return "";
  let siteCss = cssCache.get(site.css);
  if (!siteCss) {
    siteCss = await extText(site.css, bust).catch(() => "");
    cssCache.set(site.css, siteCss);
  }
  return [colors, siteCss].filter(Boolean).join("\n");
}

function pingTab(tabId, payload) {
  chrome.tabs.sendMessage(tabId, payload, () => {
    void chrome.runtime.lastError;
  });
}

function paintTab(tabId, css, key) {
  pingTab(tabId, { type: "evo-webtheme-reload", css, key });
  if (!chrome.scripting || typeof chrome.scripting.executeScript !== "function") return;
  chrome.scripting
    .executeScript({
      target: { tabId },
      func: (nextCss) => {
        const id = "evo-webtheme-style";
        let el = document.getElementById(id);
        if (!nextCss) {
          if (el) el.remove();
          return;
        }
        if (!el) {
          el = document.createElement("style");
          el.id = id;
        }
        el.textContent = nextCss;
        (document.head || document.documentElement).appendChild(el);
      },
      args: [css],
    })
    .catch(() => {});
}

async function broadcastReload() {
  const bust = String(Date.now());
  cssCache.clear();
  let catalog;
  try {
    catalog = await readCatalog();
  } catch (err) {
    console.warn("evo webtheme: catalog", err);
    return;
  }
  const colors = await extText("colors.css", bust).catch(() => "");
  const revision = await extText("revision", bust).catch(() => bust);

  chrome.tabs.query({}, async (tabs) => {
    for (const tab of tabs) {
      if (tab.id === undefined) continue;
      if (!tab.url || !/^https?:/i.test(tab.url)) {
        pingTab(tab.id, { type: "evo-webtheme-reload" });
        continue;
      }
      const css = await cssForTab(catalog, colors, tab, bust);
      let site = null;
      try {
        site = siteForHost(catalog, new URL(tab.url).hostname);
      } catch {
        site = null;
      }
      paintTab(tab.id, css, revision + "\n" + (site ? site.id + "\n" + site.css : ""));
    }
  });
}

function refreshBadge() {
  readCatalog().catch(() => chrome.action.setBadgeText({ text: "" }));
}

function hostFromUrl(url) {
  try {
    return new URL(url).hostname;
  } catch {
    return "";
  }
}

function themeJobId(host) {
  return "webtheme-theme-" + host;
}

async function loadThemeJobs() {
  try {
    const data = await chrome.storage.session.get("themeJobs");
    if (Array.isArray(data.themeJobs)) return data.themeJobs;
  } catch {
    /* storage.session may be unavailable until the permission is granted */
  }
  return [];
}

async function saveThemeJobs(jobs) {
  try {
    await chrome.storage.session.set({ themeJobs: jobs });
  } catch {
    /* ignore */
  }
}

function notifyChrome(id, title, message) {
  if (!chrome.notifications || typeof chrome.notifications.create !== "function") return;
  chrome.notifications.create(
    id,
    {
      type: "basic",
      iconUrl: chrome.runtime.getURL("icon.png"),
      title,
      message,
      priority: 1,
    },
    () => {
      void chrome.runtime.lastError;
    }
  );
}

async function startThemeJob(msg, reply) {
  const url = (reply && reply.url) || msg.url || "";
  const host = (reply && reply.host) || hostFromUrl(url);
  if (!host) return;
  const jobs = (await loadThemeJobs()).filter((job) => job.host !== host);
  jobs.push({ host, url, title: msg.title || host, startedAt: Date.now() });
  await saveThemeJobs(jobs);
  notifyChrome(
    themeJobId(host),
    "Theming " + host,
    "The default agent is writing a personal package in the background."
  );
}

async function resolveThemeJobs(catalog) {
  const jobs = await loadThemeJobs();
  if (!jobs.length) return;
  const kept = [];
  const now = Date.now();
  for (const job of jobs) {
    if (siteForHost(catalog, job.host)) {
      notifyChrome(themeJobId(job.host), "Themed " + job.host, "The personal package is on.");
      continue;
    }
    if (now - (job.startedAt || 0) > 45 * 60 * 1000) continue;
    kept.push(job);
  }
  await saveThemeJobs(kept);
}

function connect() {
  if (port) return;
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  try {
    port = chrome.runtime.connectNative(HOST);
  } catch (err) {
    console.warn("evo webtheme: native host missing", err);
    port = null;
    return;
  }
  port.onMessage.addListener((msg) => {
    if (!msg) return;
    if (msg.id && pending.has(String(msg.id))) {
      const waiter = pending.get(String(msg.id));
      pending.delete(String(msg.id));
      waiter.resolve(msg);
      return;
    }
    if (msg.type === "reload") {
      hydrateOverlayFromNative().finally(() => broadcastReload());
    }
  });
  port.onDisconnect.addListener(() => {
    const err = chrome.runtime.lastError && chrome.runtime.lastError.message;
    port = null;
    for (const waiter of pending.values()) waiter.reject(new Error(err || "native host disconnected"));
    pending.clear();
    reconnectTimer = setTimeout(connect, 2000);
  });
}

chrome.runtime.onConnect.addListener((port) => {
  port.onDisconnect.addListener(() => {});
});

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (!msg || typeof msg !== "object") {
    sendResponse({ ok: false, error: "invalid message" });
    return false;
  }
  if (msg.type === "list") {
    readCatalog()
      .then((catalog) => sendResponse(Object.assign({ ok: true, type: "list" }, catalog)))
      .catch((err) => sendResponse({ ok: false, error: String(err && err.message ? err.message : err) }));
    return true;
  }
  if (msg.type === "css-for-host") {
    cssReplyForHost(String(msg.host || ""))
      .then((reply) => sendResponse(reply))
      .catch((err) => sendResponse({ ok: false, error: String(err && err.message ? err.message : err) }));
    return true;
  }
  if (msg.type === "theme-jobs") {
    readCatalog()
      .then(() => loadThemeJobs())
      .then((jobs) => sendResponse({ ok: true, jobs }))
      .catch((err) => sendResponse({ ok: false, error: String(err && err.message ? err.message : err) }));
    return true;
  }
  sendNative(msg)
    .then((reply) => {
      const tracked = reply && reply.ok !== false && (msg.type === "set-enabled" || msg.type === "enabled");
      const after = tracked
        ? patchOverlayFromMessage(msg).then(() => broadcastReload())
        : Promise.resolve();
      const job = msg.type === "theme-site" && reply && reply.ok !== false ? startThemeJob(msg, reply) : Promise.resolve();
      return Promise.all([after, job]).then(() => sendResponse(reply));
    })
    .catch((err) => sendResponse({ ok: false, error: String(err && err.message ? err.message : err) }));
  return true;
});

chrome.runtime.onStartup.addListener(() => refreshBadge());
chrome.runtime.onInstalled.addListener(() => refreshBadge());
refreshBadge();
setTimeout(connect, 0);
