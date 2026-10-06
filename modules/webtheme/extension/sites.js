const meta = document.getElementById("meta");
const countEl = document.getElementById("count");
const hero = document.querySelector(".hero");
const errorEl = document.getElementById("error");
const bundledEl = document.getElementById("bundled");
const bundledEmpty = document.getElementById("bundled-empty");
const personalEl = document.getElementById("personal");
const personalEmpty = document.getElementById("personal-empty");
const statEnabled = document.getElementById("stat-enabled");
const statBundled = document.getElementById("stat-bundled");
const statMine = document.getElementById("stat-mine");
const statTotal = document.getElementById("stat-total");

WebthemeUI.injectColors();
WebthemeUI.keepAlive();

function showError(text) {
  errorEl.hidden = !text;
  errorEl.textContent = text || "";
}

function isPersonal(site) {
  return site && site.source === "user";
}

function render(reply) {
  const sites = Array.isArray(reply.sites) ? reply.sites : [];
  const on = reply.enabled !== false;
  const enabledCount = sites.filter((site) => site.enabled !== false).length;
  const bundled = sites.filter((site) => !isPersonal(site));
  const personal = sites.filter(isPersonal);
  meta.textContent = on ? "sites themed" : "Paused";
  countEl.textContent = on ? String(enabledCount) : "0";
  hero.classList.toggle("is-paused", !on);
  statEnabled.textContent = String(enabledCount);
  statBundled.textContent = String(bundled.length);
  statMine.textContent = String(personal.length);
  statTotal.textContent = String(sites.length);
  const rowOpts = { onError: showError, onChanged: load };

  bundledEl.replaceChildren(...bundled.map((site) => WebthemeUI.row(site, null, rowOpts)));
  personalEl.replaceChildren(...personal.map((site) => WebthemeUI.row(site, null, rowOpts)));
  bundledEmpty.hidden = bundled.length > 0;
  personalEmpty.hidden = personal.length > 0;
}

async function load() {
  try {
    const catalog = await WebthemeUI.catalogPayload();
    render(catalog);
  } catch (err) {
    meta.textContent = "Failed to load";
    showError(String(err && err.message ? err.message : err));
  }
}

load();
