
function plain(value, maxLen) {
  var s = String(value == null ? "" : value)
  var max = maxLen || 240
  var out = ""
  for (var i = 0; i < s.length && out.length < max; i++) {
    var code = s.charCodeAt(i)
    if (code < 32 || (code >= 127 && code < 160)) continue
    var c = s.charAt(i)
    if (c === "<" || c === ">" || c === "&") continue
    out += c
  }
  return out
}
function parseCatalog(raw) {
  try {
    var parsed = JSON.parse(String(raw || "{}"))
    if (Array.isArray(parsed))
      return { enabled: true, sites: parsed }
    if (parsed && typeof parsed === "object") {
      return {
        enabled: parsed.enabled !== false,
        sites: Array.isArray(parsed.sites) ? parsed.sites : []
      }
    }
  } catch (e) {}
  return { enabled: true, sites: [] }
}

function parseList(raw) {
  return parseCatalog(raw).sites
}

function parseEnabled(raw) {
  return parseCatalog(raw).enabled !== false
}

function parseSite(raw) {
  try {
    var parsed = JSON.parse(String(raw || "{}"))
    return parsed && typeof parsed === "object" ? parsed : null
  } catch (e) {
    return null
  }
}

function parseSetup(raw) {
  try {
    return JSON.parse(String(raw || "{}"))
  } catch (e) {
    return {}
  }
}

function matchesLabel(site) {
  var matches = site && Array.isArray(site.matches) ? site.matches : []
  return matches.map(function(item) {
    return String(item).replace(/^https?:\/\//, "").replace(/\/\*$/, "")
  }).join(", ")
}

function isMine(site) {
  return !!(site && site.source === "user")
}

function bundledSites(sites) {
  return filterSource(sites, false)
}

function mineSites(sites) {
  return filterSource(sites, true)
}

function filterSource(sites, mine) {
  if (!Array.isArray(sites)) return []
  var out = []
  for (var i = 0; i < sites.length; i++) {
    if (isMine(sites[i]) === mine) out.push(sites[i])
  }
  return out
}

function rowDescription(site) {
  var label = matchesLabel(site)
  if (site && site.source === "override")
    return label ? label + " · custom" : "custom"
  return label
}

function slugHint(matchesText) {
  return String(matchesText || "").trim()
}

function enabledCount(sites) {
  if (!Array.isArray(sites)) return 0
  var count = 0
  for (var i = 0; i < sites.length; i++) {
    if (sites[i] && sites[i].enabled !== false) count++
  }
  return count
}
