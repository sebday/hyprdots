.pragma library

var SEVERITIES = ["info", "low", "medium", "high", "critical"]
var STALE_SEC = 3 * 3600

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
    findings: Array.isArray(json.findings) ? json.findings : []
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
