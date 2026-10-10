const WebthemeUI = {
  injectColors() {
    fetch(chrome.runtime.getURL("colors.css") + "?v=" + Date.now(), { cache: "reload" })
      .then((response) => (response.ok ? response.text() : ""))
      .then((css) => {
        if (!css) return;
        const style = document.createElement("style");
        style.textContent = css;
        document.head.appendChild(style);
      })
      .catch(() => {});
  },

  async themeName() {
    try {
      const data = await fetch(chrome.runtime.getURL("theme.json") + "?v=" + Date.now(), {
        cache: "reload",
      }).then((response) => (response.ok ? response.json() : null));
      return data && data.name ? data.name : "Desktop theme";
    } catch {
      return "Desktop theme";
    }
  },

  applyOverlay(catalog, overlay) {
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
  },

  applyEnabledFlag(catalog, flagText) {
    if (!catalog || typeof flagText !== "string") return catalog;
    const trimmed = flagText.trim();
    if (trimmed === "false") catalog.enabled = false;
    else if (trimmed === "true") catalog.enabled = true;
    return catalog;
  },

  async pruneThemeJobs(sites) {
    let jobs = [];
    try {
      const data = await chrome.storage.session.get("themeJobs");
      jobs = Array.isArray(data.themeJobs) ? data.themeJobs : [];
    } catch {
      return [];
    }
    const kept = jobs.filter((job) => job && job.host && !this.siteForHost(sites, job.host));
    if (kept.length !== jobs.length) {
      try {
        await chrome.storage.session.set({ themeJobs: kept });
      } catch {
        /* ignore */
      }
    }
    return kept;
  },

  async overlayFromStorage() {
    try {
      const data = await chrome.storage.local.get("enabledOverlay");
      const overlay = data.enabledOverlay;
      if (overlay && typeof overlay === "object") return overlay;
    } catch {
      /* ignore */
    }
    return { siteEnabled: {} };
  },

  async enabledFlagFromFiles() {
    try {
      const text = await fetch(chrome.runtime.getURL("enabled") + "?v=" + Date.now(), {
        cache: "reload",
      }).then((response) => (response.ok ? response.text() : ""));
      return text || "";
    } catch {
      return "";
    }
  },

  async catalogFromFiles() {
    const catalog = await fetch(chrome.runtime.getURL("catalog.json") + "?v=" + Date.now(), {
      cache: "reload",
    }).then((response) => {
      if (!response.ok) throw new Error("catalog " + response.status);
      return response.json();
    });
    this.applyOverlay(catalog, await this.overlayFromStorage());
    this.applyEnabledFlag(catalog, await this.enabledFlagFromFiles());
    return {
      ok: true,
      enabled: catalog.enabled !== false,
      sites: Array.isArray(catalog.sites) ? catalog.sites : [],
    };
  },

  async catalogPayload() {
    return this.catalogFromFiles();
  },

  hostOf(match) {
    const found = String(match || "").match(/^[^:]+:\/\/([^/]+)/);
    return found ? found[1] : "";
  },

  hostMatches(pattern, hostname) {
    const hostPat = this.hostOf(pattern);
    if (!hostPat) return false;
    if (hostPat === "*") return true;
    if (hostPat.startsWith("*.")) {
      const suffix = hostPat.slice(1);
      const bare = hostPat.slice(2);
      return hostname === bare || hostname.endsWith(suffix);
    }
    return hostname === hostPat;
  },

  siteForHost(sites, hostname) {
    for (const site of sites || []) {
      for (const pattern of site.matches || []) {
        if (this.hostMatches(pattern, hostname)) return site;
      }
    }
    return null;
  },

  hostsLabel(site) {
    return (site.matches || [])
      .map((item) => String(item).replace(/^https?:\/\//, "").replace(/\/\*$/, ""))
      .join(", ");
  },

  keepAlive() {
    try {
      if (this._alive && this._alive.name) return;
      this._alive = chrome.runtime.connect({ name: "ui" });
      this._alive.onDisconnect.addListener(() => {
        this._alive = null;
        setTimeout(() => this.keepAlive(), 1000);
      });
    } catch {
      /* service worker may be missing; native fallback still works */
    }
  },

  enabledSiteForHost(sites, hostname) {
    for (const site of sites || []) {
      if (!site || site.enabled === false) continue;
      for (const pattern of site.matches || []) {
        if (this.hostMatches(pattern, hostname)) return site;
      }
    }
    return null;
  },

  async rememberOverlay(msg) {
    const overlay = await this.overlayFromStorage();
    if (msg.type === "enabled") {
      overlay.enabled = msg.enabled !== false;
    } else if (msg.type === "set-enabled" && msg.siteId) {
      overlay.siteEnabled = overlay.siteEnabled || {};
      overlay.siteEnabled[msg.siteId] = msg.enabled !== false;
    }
    try {
      await chrome.storage.local.set({ enabledOverlay: overlay });
    } catch {
      /* ignore */
    }
  },

  async paintOpenTabs() {
    if (!chrome.tabs || !chrome.tabs.query) return;
    const catalog = await this.catalogFromFiles();
    const on = catalog.enabled !== false;
    const colors = await fetch(chrome.runtime.getURL("colors.css") + "?v=" + Date.now(), { cache: "reload" })
      .then((response) => (response.ok ? response.text() : ""))
      .catch(() => "");
    const tabs = await chrome.tabs.query({});
    for (const tab of tabs) {
      if (tab.id === undefined || !tab.url || !/^https?:/i.test(tab.url)) continue;
      let host = "";
      try {
        host = new URL(tab.url).hostname;
      } catch {
        continue;
      }
      const site = on ? this.enabledSiteForHost(catalog.sites, host) : null;
      let css = "";
      if (site && site.css) {
        const siteCss = await fetch(chrome.runtime.getURL(site.css) + "?v=" + Date.now(), { cache: "reload" })
          .then((response) => (response.ok ? response.text() : ""))
          .catch(() => "");
        css = [colors, siteCss].filter(Boolean).join("\n");
      }
      const key = String(Date.now()) + "\n" + (site ? site.id + "\n" + site.css : "");
      chrome.tabs.sendMessage(tab.id, { type: "evo-webtheme-reload", css, key }, () => {
        void chrome.runtime.lastError;
      });
      if (!chrome.scripting || typeof chrome.scripting.executeScript !== "function") continue;
      chrome.scripting
        .executeScript({
          target: { tabId: tab.id },
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
  },

  callNative(msg) {
    return new Promise((resolve, reject) => {
      let port;
      try {
        port = chrome.runtime.connectNative("com.evo.webtheme");
      } catch (err) {
        reject(err);
        return;
      }
      const id = "ui-" + Date.now() + "-" + Math.random().toString(16).slice(2);
      let settled = false;
      const finish = (handler, value) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        try {
          port.disconnect();
        } catch {
          /* ignore */
        }
        handler(value);
      };
      const timer = setTimeout(() => finish(reject, new Error("native host timeout")), 12000);
      port.onMessage.addListener((reply) => {
        if (!reply || reply.type === "reload") return;
        if (reply.id && String(reply.id) !== id) return;
        finish(resolve, reply);
      });
      port.onDisconnect.addListener(() => {
        if (settled) {
          void chrome.runtime.lastError;
          return;
        }
        const err = chrome.runtime.lastError && chrome.runtime.lastError.message;
        finish(reject, new Error(err || "native host disconnected"));
      });
      try {
        port.postMessage(Object.assign({ id }, msg));
      } catch (err) {
        finish(reject, err);
      }
    });
  },

  async call(msg) {
    try {
      const reply = await this.callNative(msg);
      if (reply && reply.ok !== false) {
        await this.rememberOverlay(msg);
        this.paintOpenTabs().catch(() => {});
        if (msg.type === "theme-site") {
          let host = "site";
          try {
            host = msg.url ? new URL(msg.url).hostname : "site";
          } catch {
            host = "site";
          }
          try {
            const data = await chrome.storage.session.get("themeJobs");
            const jobs = (Array.isArray(data.themeJobs) ? data.themeJobs : []).filter((job) => job.host !== host);
            jobs.push({ host, url: msg.url, title: msg.title || host, startedAt: Date.now() });
            await chrome.storage.session.set({ themeJobs: jobs });
          } catch {
            /* ignore */
          }
          if (chrome.notifications && chrome.notifications.create) {
            chrome.notifications.create("webtheme-theme-" + host, {
              type: "basic",
              iconUrl: chrome.runtime.getURL("icon.png"),
              title: "Theming " + host,
              message: "The default agent is writing a personal package in the background.",
              priority: 1,
            });
          }
        }
      }
      return reply;
    } catch (err) {
      return { ok: false, error: String(err && err.message ? err.message : err) };
    }
  },

  row(site, currentId, opts) {
    const el = document.createElement("label");
    el.className = "toggle-row" + (site.id === currentId ? " current" : "");
    el.innerHTML =
      "<div class='toggle-copy'><strong></strong><span></span></div>" +
      "<input type='checkbox' class='switch-input' />" +
      "<span class='switch' aria-hidden='true'></span>";
    el.querySelector("strong").textContent = site.name || site.id;
    el.querySelector("span").textContent = this.hostsLabel(site);
    const box = el.querySelector("input");
    box.checked = site.enabled !== false;
    box.addEventListener("change", async () => {
      if (opts && opts.onError) opts.onError("");
      const reply = await this.call({
        type: "set-enabled",
        siteId: site.id,
        enabled: box.checked,
      });
      if (!reply || reply.ok === false) {
        box.checked = !box.checked;
        if (opts && opts.onError) opts.onError((reply && reply.error) || "Could not update site");
        return;
      }
      if (opts && opts.onChanged) await opts.onChanged();
    });
    return el;
  },
};
