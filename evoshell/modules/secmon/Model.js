.pragma library

var SEVERITIES = ["info", "low", "medium", "high", "critical"]
var STALE_SEC = 3 * 3600

function targetLabel(name) {
  var n = String(name == null ? "" : name)
  return n === "cloudflare" ? "cf" : plain(n, 24)
}

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

function rank(sev) {
  var i = SEVERITIES.indexOf(String(sev || ""))
  return i < 0 ? 0 : i
}

function emptyData() {
  return {
    ok: false,
    error: "",
    generatedAt: "",
    reportUrl: "https://secmon.day.marketing",
    counts: { critical: 0, high: 0, medium: 0, low: 0, info: 0 },
    attacks24h: 0,
    targets: [],
    apps: null,
    findings: []
  }
}

function parsePayload(raw) {
  try {
    var json = JSON.parse(String(raw || "").trim())
  } catch (e) {
    return { ok: false, error: "Invalid response from secmon" }
  }
  if (!json || typeof json !== "object") return { ok: false, error: "Invalid response from secmon" }
  if (json.ok !== true) return { ok: false, error: plain(json.error || "secmon unavailable") }
  var counts = json.counts || {}
  return {
    ok: true,
    error: "",
    generatedAt: String(json.generatedAt || ""),
    reportUrl: String(json.reportUrl || "https://secmon.day.marketing"),
    counts: {
      critical: Number(counts.critical) || 0,
      high: Number(counts.high) || 0,
      medium: Number(counts.medium) || 0,
      low: Number(counts.low) || 0,
      info: Number(counts.info) || 0
    },
    attacks24h: Number(json.attacks24h) || 0,
    targets: Array.isArray(json.targets) ? json.targets : [],
    apps: parseApps(json.apps),
    findings: Array.isArray(json.findings) ? json.findings : []
  }
}

function parseApps(apps) {
  if (!apps || typeof apps !== "object" || !Array.isArray(apps.hosts) || !apps.hosts.length) return null
  var hosts = []
  for (var i = 0; i < apps.hosts.length; i++) {
    var h = apps.hosts[i]
    if (!h || !h.name) continue
    hosts.push({
      name: plain(h.name, 40),
      open: Number(h.open) || 0,
      worst: String(h.worst || "info")
    })
  }
  if (!hosts.length) return null
  return {
    open: Number(apps.open) || 0,
    worst: String(apps.worst || "info"),
    hosts: hosts
  }
}

// A failed poll keeps the last good snapshot and only records the error.
function merge(current, parsed) {
  if (parsed.ok) return parsed
  var base = current && current.generatedAt ? current : emptyData()
  var out = {}
  for (var k in base) out[k] = base[k]
  out.ok = false
  out.error = parsed.error
  return out
}

function ageSec(iso) {
  var t = Date.parse(String(iso || ""))
  if (isNaN(t)) return -1
  return Math.max(0, Math.round((Date.now() - t) / 1000))
}

function formatAgo(iso) {
  var sec = ageSec(iso)
  if (sec < 0) return ""
  if (sec < 45) return "just now"
  if (sec < 3600) return Math.max(1, Math.round(sec / 60)) + "m ago"
  if (sec < 86400) return Math.max(1, Math.round(sec / 3600)) + "h ago"
  return Math.round(sec / 86400) + "d ago"
}

function worst(data) {
  var c = data && data.counts ? data.counts : {}
  if (c.critical) return "critical"
  if (c.high) return "high"
  if (c.medium) return "medium"
  if (c.low) return "low"
  return "info"
}

function issueCount(data) {
  var c = data && data.counts ? data.counts : {}
  return (c.critical || 0) + (c.high || 0) + (c.medium || 0) + (c.low || 0)
}

function openCount(data) {
  var c = data && data.counts ? data.counts : {}
  return (c.critical || 0) + (c.high || 0) + (c.medium || 0)
}

function openFindings(data) {
  var rows = data && Array.isArray(data.findings) ? data.findings : []
  var out = []
  for (var i = 0; i < rows.length; i++) if (rank(rows[i] && rows[i].severity) >= rank("medium")) out.push(rows[i])
  return out
}

function copyFields(src) {
  var out = {}
  for (var k in src) out[k] = src[k]
  return out
}

// Drop one occurrence from the snapshot so the row leaves before the next poll.
function withoutFinding(data, fingerprint, firstSeen) {
  if (!data || !data.generatedAt) return data
  var fp = String(fingerprint || "")
  var seen = String(firstSeen || "")
  var rows = Array.isArray(data.findings) ? data.findings : []
  var findings = []
  var removed = null
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!removed && row && row.fingerprint === fp && row.firstSeen === seen) removed = row
    else findings.push(row)
  }
  if (!removed) return data
  var sev = String(removed.severity || "")
  var counts = copyFields(data.counts || {})
  if (counts[sev]) counts[sev] = Math.max(0, Number(counts[sev]) - 1)
  var targets = []
  var list = Array.isArray(data.targets) ? data.targets : []
  for (var t = 0; t < list.length; t++) {
    var target = list[t]
    if (!target || target.name !== removed.target) {
      targets.push(target)
      continue
    }
    var copy = copyFields(target)
    if (sev !== "info") copy.open = Math.max(0, (Number(copy.open) || 0) - 1)
    if (fp.indexOf(":change:") !== -1) copy.changes = Math.max(0, (Number(copy.changes) || 0) - 1)
    targets.push(copy)
  }
  var apps = data.apps
  var parts = fp.split(":")
  if (apps && parts[0] === "cloudflare" && String(parts[1] || "").indexOf("app-") === 0 && parts[2]) {
    var short = String(parts[2]).replace(/\.day\.technology$/, "")
    var hosts = []
    var matched = false
    var appRows = Array.isArray(apps.hosts) ? apps.hosts : []
    for (var h = 0; h < appRows.length; h++) {
      var host = appRows[h]
      if (!matched && host && host.name === short) {
        var hostCopy = copyFields(host)
        hostCopy.open = Math.max(0, (Number(hostCopy.open) || 0) - 1)
        hosts.push(hostCopy)
        matched = true
      } else {
        hosts.push(host)
      }
    }
    apps = {
      open: Math.max(0, (Number(apps.open) || 0) - (matched ? 1 : 0)),
      worst: apps.worst,
      hosts: hosts
    }
  }
  return {
    ok: data.ok,
    error: "",
    generatedAt: data.generatedAt,
    reportUrl: data.reportUrl,
    counts: counts,
    attacks24h: data.attacks24h,
    targets: targets,
    apps: apps,
    findings: findings
  }
}

function findingsFooter(data, shown) {
  var c = data && data.counts ? data.counts : {}
  var parts = []
  var more = Math.max(0, openCount(data) - shown)
  if (more > 0) parts.push("+" + more + " more")
  if (c.low) parts.push(c.low + " low")
  return parts.length ? parts.join(" · ") + " in the report" : ""
}

function isStale(data) {
  if (!data || !data.generatedAt) return true
  return ageSec(data.generatedAt) > STALE_SEC
}

function alarming(data) {
  return rank(worst(data)) >= rank("high")
}

function targetUnhealthy(t) {
  return !!t && (Number(t.failures) > 0 || !t.lastSuccess)
}

function unhealthyTargets(data) {
  var rows = data && Array.isArray(data.targets) ? data.targets : []
  var out = []
  for (var i = 0; i < rows.length; i++) if (targetUnhealthy(rows[i])) out.push(rows[i].name)
  return out
}

function changedTargets(data) {
  var rows = data && Array.isArray(data.targets) ? data.targets : []
  var out = []
  for (var i = 0; i < rows.length; i++) if (rows[i] && Number(rows[i].changes) > 0) out.push(String(rows[i].name))
  return out
}

function appsBox(data) {
  var apps = data && data.apps
  if (!apps || !Array.isArray(apps.hosts) || !apps.hosts.length) return null
  var last = ""
  var targets = data.targets || []
  for (var i = 0; i < targets.length; i++) {
    if (targets[i] && targets[i].name === "cloudflare" && targets[i].lastSuccess) last = String(targets[i].lastSuccess)
  }
  var parts = []
  for (var j = 0; j < apps.hosts.length; j++) {
    var h = apps.hosts[j]
    parts.push(h.name + " " + (Number(h.open) || 0))
  }
  return {
    name: "apps",
    open: Number(apps.open) || 0,
    worst: apps.worst || "info",
    failures: 0,
    lastSuccess: last,
    error: null,
    report: "cloudflare",
    hint: parts.join(" · ")
  }
}

function changeCount(data) {
  var rows = data && Array.isArray(data.targets) ? data.targets : []
  var n = 0
  for (var i = 0; i < rows.length; i++) n += Number(rows[i] && rows[i].changes) || 0
  return n
}

function countsLine(data) {
  var c = data && data.counts ? data.counts : {}
  var parts = []
  var order = ["critical", "high", "medium", "low"]
  for (var i = 0; i < order.length; i++) {
    if (c[order[i]]) parts.push(c[order[i]] + " " + order[i])
  }
  return parts.length ? parts.join(" · ") : "No open issues"
}

function heroMeta(data, loading) {
  if (loading && !(data && data.generatedAt)) return "Loading…"
  if (!data || !data.generatedAt) return data && data.error ? data.error : "No data"
  var parts = []
  if (openCount(data) === 0) parts.push("all clear")
  if (data.attacks24h > 0) parts.push(formatCount(data.attacks24h) + " attack events 24h")
  return parts.join(" · ")
}

function barTooltip(data, loading) {
  if (loading && !(data && data.generatedAt)) return "Security"
  if (!data || !data.generatedAt) return data && data.error ? data.error : "Security"
  var line = countsLine(data)
  var down = unhealthyTargets(data)
  if (down.length) line += " · can't collect from " + down.join(", ")
  if (data.error) line += " · " + data.error
  return line
}

function findingMeta(f) {
  var parts = [plain(f && f.target, 40)]
  if (f && f.count) parts.push(formatCount(f.count) + " events")
  var when = formatAgo(f && f.firstSeen)
  if (when) parts.push("since " + when)
  return parts.join(" · ")
}

function targetAnchor(reportUrl, target) {
  var base = String(reportUrl || "https://secmon.day.marketing").replace(/\/+$/, "")
  var t = String(target || "").replace(/[^A-Za-z0-9_-]/g, "")
  return t ? base + "/#t-" + t : base
}

function formatCount(n) {
  var digits = String(Math.max(0, Math.round(Number(n) || 0)))
  var out = ""
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 === 0) out += ","
    out += digits.charAt(i)
  }
  return out
}
