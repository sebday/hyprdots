const globalToggle = document.getElementById("global");
const globalDesc = document.getElementById("global-desc");
const meta = document.getElementById("meta");
const countEl = document.getElementById("count");
const hero = document.querySelector(".hero");
const errorEl = document.getElementById("error");
const noticeEl = document.getElementById("notice");
const currentCard = document.getElementById("current");
const currentHost = document.getElementById("current-host");
const currentStatus = document.getElementById("current-status");
const themeBtn = document.getElementById("theme-site");
const siteEnable = document.getElementById("site-enable");
const siteToggle = document.getElementById("site-toggle");
const siteDesc = document.getElementById("site-desc");
const statEnabled = document.getElementById("stat-enabled");
const statBundled = document.getElementById("stat-bundled");
const statMine = document.getElementById("stat-mine");
const statTotal = document.getElementById("stat-total");

let tabUrl = "";
let tabTitle = "";
let tabHost = "";
let desktopTheme = "Desktop theme";
let currentSite = null;

WebthemeUI.injectColors();
WebthemeUI.keepAlive();

function openAllSites(event) {
  if (event) event.preventDefault();
  chrome.tabs.create({ url: chrome.runtime.getURL("sites.html") });
}

function showError(text) {
  errorEl.hidden = !text;
  errorEl.textContent = text || "";
}

function showNotice(text) {
  noticeEl.hidden = !text;
  noticeEl.textContent = text || "";
}

function jobForHost(jobs, hostname) {
  return (jobs || []).find((job) => job && job.host === hostname) || null;
}

function render(reply, jobs) {
  const sites = Array.isArray(reply.sites) ? reply.sites : [];
  const on = reply.enabled !== false;
  const enabledCount = sites.filter((site) => site.enabled !== false).length;
  const bundledCount = sites.filter((site) => site && site.source !== "user").length;
  const mineCount = sites.filter((site) => site && site.source === "user").length;
  globalToggle.checked = on;
  globalDesc.textContent = on ? "Pause all site CSS" : "Theming is paused";
  meta.textContent = on ? "sites themed" : "Paused";
  countEl.textContent = on ? String(enabledCount) : "0";
  hero.classList.toggle("is-paused", !on);
  statEnabled.textContent = String(enabledCount);
  statBundled.textContent = String(bundledCount);
  statMine.textContent = String(mineCount);
  statTotal.textContent = String(sites.length);

  const current = tabHost ? WebthemeUI.siteForHost(sites, tabHost) : null;
  const pending = !current && tabHost ? jobForHost(jobs, tabHost) : null;

  const otherJobs = (jobs || []).filter((job) => {
    if (!job || !job.host || job.host === tabHost) return false;
    return !WebthemeUI.siteForHost(sites, job.host);
  });
  if (pending) {
    showNotice("Theming " + pending.host + " in the background. Click to dismiss.");
  } else if (otherJobs.length) {
    showNotice("Theming " + otherJobs.map((job) => job.host).join(", ") + " in the background. Click to dismiss.");
  } else {
    showNotice("");
  }

  if (!tabHost) {
    currentCard.hidden = true;
    siteEnable.hidden = true;
    currentSite = null;
    return;
  }

  currentHost.textContent = tabHost;
  currentSite = current;
  if (current) {
    siteEnable.hidden = false;
    currentCard.hidden = true;
    siteToggle.checked = current.enabled !== false;
    if (!on) siteDesc.textContent = tabHost + " · paused";
    else if (current.enabled !== false) siteDesc.textContent = tabHost + " · " + desktopTheme;
    else siteDesc.textContent = tabHost + " · off";
  } else if (pending) {
    currentCard.hidden = false;
    siteEnable.hidden = true;
    currentStatus.textContent = "The default agent is theming this site";
    themeBtn.hidden = true;
    currentSite = null;
  } else {
    currentCard.hidden = false;
    siteEnable.hidden = true;
    currentStatus.textContent = "No package for this host";
    themeBtn.hidden = false;
    currentSite = null;
  }
}

async function load() {
  try {
    desktopTheme = await WebthemeUI.themeName();
    const catalog = await WebthemeUI.catalogPayload();
    const jobs = await WebthemeUI.pruneThemeJobs(catalog.sites);
    render(catalog, jobs);
  } catch (err) {
    meta.textContent = "Failed to load";
    showError(String(err && err.message ? err.message : err));
  }
}

noticeEl.addEventListener("click", async () => {
  try {
    await chrome.storage.session.set({ themeJobs: [] });
  } catch {
    /* ignore */
  }
  showNotice("");
  await load();
});
noticeEl.title = "Dismiss";
noticeEl.style.cursor = "pointer";

globalToggle.addEventListener("change", async () => {
  showError("");
  const reply = await WebthemeUI.call({ type: "enabled", enabled: globalToggle.checked });
  if (!reply || reply.ok === false) {
    globalToggle.checked = !globalToggle.checked;
    showError((reply && reply.error) || "Could not update theming");
    return;
  }
  await load();
});

siteToggle.addEventListener("change", async () => {
  if (!currentSite) return;
  showError("");
  siteToggle.disabled = true;
  const reply = await WebthemeUI.call({
    type: "set-enabled",
    siteId: currentSite.id,
    enabled: siteToggle.checked,
  });
  siteToggle.disabled = false;
  if (!reply || reply.ok === false) {
    siteToggle.checked = !siteToggle.checked;
    showError((reply && reply.error) || "Could not update site");
    return;
  }
  await load();
});

themeBtn.addEventListener("click", async () => {
  showError("");
  themeBtn.disabled = true;
  const reply = await WebthemeUI.call({ type: "theme-site", url: tabUrl, title: tabTitle });
  themeBtn.disabled = false;
  if (!reply || reply.ok === false) {
    showError((reply && reply.error) || "Could not launch the agent");
    return;
  }
  await load();
});

document.getElementById("all-sites").addEventListener("click", openAllSites);
meta.addEventListener("click", openAllSites);
meta.title = "Open all sites";
meta.style.cursor = "pointer";

async function init() {
  try {
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
    const tab = tabs && tabs[0];
    tabUrl = tab && tab.url ? tab.url : "";
    tabTitle = tab && tab.title ? tab.title : "";
    tabHost = tabUrl && /^https?:/i.test(tabUrl) ? new URL(tabUrl).hostname : "";
  } catch {
    tabHost = "";
  }
  await load();
}

init();
