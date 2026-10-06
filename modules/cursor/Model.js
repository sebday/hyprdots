.pragma library


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

var DEFAULT_HEATMAP_COLORS = ["#45475a", "#89b4fa", "#74c7ec", "#89dceb", "#cba6f7"]

function emptyDetail() {
  return {
    membership: "",
    billingCycleStart: "",
    billingCycleEnd: "",
    autoMessage: "",
    apiMessage: "",
    onDemand: false,
    onDemandUsed: 0,
    cursorPercent: 0,
    otherPercent: 0,
    tokensTotal: 0,
    tokensToday: 0,
    modelSplit: [],
    cycleDaysUsed: 0,
    cycleDaysTotal: 0,
    cycleProgress: 0,
    cursorColor: DEFAULT_HEATMAP_COLORS[2],
    otherColor: DEFAULT_HEATMAP_COLORS[4]
  }
}

function emptyData(error) {
  return {
    ok: false,
    error: String(error || ""),
    text: "",
    cursorPercent: 0,
    otherPercent: 0,
    cycleDaysUsed: 0,
    cycleDaysTotal: 0,
    cycleProgress: 0,
    detail: emptyDetail()
  }
}

function parsePayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return emptyData("No data")

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return emptyData("Invalid response")
  }

  if (json.class === "error") {
    return {
      ok: false,
      error: String(json.message || json.text || "Unavailable"),
      text: String(json.text || ""),
      cursorPercent: 0,
      otherPercent: 0,
      cycleDaysUsed: 0,
      cycleDaysTotal: 0,
      cycleProgress: 0,
      detail: emptyDetail()
    }
  }

  var detail = json.detail && typeof json.detail === "object" ? json.detail : emptyDetail()
  if (!Array.isArray(detail.modelSplit)) detail.modelSplit = []

  return {
    ok: true,
    error: "",
    text: String(json.text || ""),
    cursorPercent: parseInt(json.cursorPercent !== undefined ? json.cursorPercent : detail.cursorPercent, 10) || 0,
    otherPercent: parseInt(json.otherPercent !== undefined ? json.otherPercent : detail.otherPercent, 10) || 0,
    cycleDaysUsed: parseInt(json.cycleDaysUsed !== undefined ? json.cycleDaysUsed : detail.cycleDaysUsed, 10) || 0,
    cycleDaysTotal: parseInt(json.cycleDaysTotal !== undefined ? json.cycleDaysTotal : detail.cycleDaysTotal, 10) || 0,
    cycleProgress: Number(json.cycleProgress !== undefined ? json.cycleProgress : detail.cycleProgress) || 0,
    detail: detail
  }
}

function formatTokens(n) {
  var v = Number(n) || 0
  if (v >= 1e9) return (v / 1e9).toFixed(2) + "B"
  if (v >= 1e6) return (v / 1e6).toFixed(2) + "M"
  if (v >= 1e3) return (v / 1e3).toFixed(1) + "K"
  return String(Math.round(v))
}

function formatTokensNearestM(n) {
  return Math.round((Number(n) || 0) / 1e6) + "M"
}

function modelLabel(name) {
  return String(name || "")
    .replace(/^cursor-/, "")
    .replace(/-/g, " ")
}

function heatmapColors(accent) {
  var accentColor = String(accent || DEFAULT_HEATMAP_COLORS[1])
  return [
    DEFAULT_HEATMAP_COLORS[0],
    accentColor,
    DEFAULT_HEATMAP_COLORS[2],
    DEFAULT_HEATMAP_COLORS[3],
    DEFAULT_HEATMAP_COLORS[4]
  ]
}

function breakdownBarColor(palette, index) {
  // cyan → sky → mauve (theme-adjacent, no grey or accent)
  var colors = [
    DEFAULT_HEATMAP_COLORS[2],
    DEFAULT_HEATMAP_COLORS[3],
    DEFAULT_HEATMAP_COLORS[4]
  ]
  var row = parseInt(index, 10) || 0
  return colors[((row % colors.length) + colors.length) % colors.length]
}

function usageStageColor(percent, green, blue, orange, red) {
  var used = Number(percent) || 0
  if (used >= 75) return red
  if (used >= 50) return orange
  if (used >= 25) return blue
  return green
}

function cycleColor(detail, palette) {
  var colors = palette && palette.length ? palette : DEFAULT_HEATMAP_COLORS
  if (detail && detail.cursorColor) return String(detail.cursorColor)
  return colors[3] || colors[2]
}

function iconActive(data) {
  if (!data || !data.ok) return false
  return (data.cursorPercent || 0) > 0 || (data.otherPercent || 0) > 0
}

function barTooltip(data, loading) {
  if (!data || !data.ok) {
    if (loading) return "Cursor usage"
    return plain(data && data.error ? data.error : "Cursor usage")
  }
  var cursor = parseInt(data.cursorPercent, 10)
  if (isNaN(cursor)) cursor = 0
  return plain(cursor + "% Cursor")
}

function barValue(data) {
  if (!data || !data.ok) return ""
  var cursor = parseInt(data.cursorPercent, 10)
  var other = parseInt(data.otherPercent, 10)
  if (isNaN(cursor)) cursor = 0
  if (isNaN(other)) other = 0
  return plain(cursor + "% / " + other + "%", 16)
}

function showTokens(detail) {
  if (!detail || typeof detail !== "object") return false
  return !!(detail.tokensTotal || detail.tokensToday)
}

function hasModelDetails(detail) {
  if (!detail || typeof detail !== "object") return false
  return (Array.isArray(detail.modelSplit) && detail.modelSplit.length > 0) || detail.onDemand === true
}

function cycleDaysLeft(data) {
  var total = parseInt(data && data.cycleDaysTotal, 10) || 0
  var used = parseInt(data && data.cycleDaysUsed, 10) || 0
  return Math.max(0, total - used)
}

function cycleDaysLeftText(data, loading) {
  if (loading) return "…"
  var left = cycleDaysLeft(data)
  return left === 1 ? "1 day" : left + " days"
}
