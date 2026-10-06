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

if (typeof globalThis !== "undefined") {
  globalThis.evoWebthemeMatch = { siteForHost, hostMatches };
}
