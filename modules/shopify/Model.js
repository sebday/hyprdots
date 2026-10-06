.pragma library

var MAX_STORES = 16
var MAX_BARS = 400
var MAX_TEXT = 80

var KPI_ORDER = [
  "revenue", "orders", "cos", "cvr", "aov",
  "sessions", "spend"
]

var CHARTS = {
  revenue: { id: "revenue", label: "revenue", valueKind: "currency", chartStyle: "line" },
  orders: { id: "orders", label: "orders", valueKind: "integer", chartStyle: "bar" },
  sessions: { id: "sessions", label: "sessions", valueKind: "integer", chartStyle: "line" },
  cvr: { id: "cvr", label: "CVR", valueKind: "percent", chartStyle: "line" },
  aov: { id: "aov", label: "AoV", valueKind: "currency", chartStyle: "line" },
  cos: { id: "cos", label: "CoS", valueKind: "percent", chartStyle: "line" },
  spend: { id: "spend", label: "ad spend", valueKind: "currency", chartStyle: "line" },
  periodPrev: { id: "periodPrev", label: "prev", valueKind: "currency", chartStyle: "bar" },
  periodRevenue: { id: "periodRevenue", label: "revenue", valueKind: "currency", chartStyle: "bar" },
  forecast: { id: "forecast", label: "forecast", valueKind: "currency", chartStyle: "bar" }
}

var STORE_COLOR_NAMES = { DIY: "cyan", TGS: "blue" }
var STORE_COLOR_FALLBACK = ["cyan", "bright_green", "blue", "yellow", "magenta"]
var COLOR_KEYS = [
  "cyan", "bright_green", "blue", "yellow", "magenta",
  "muted", "foreground", "bright_foreground", "background"
]

function plain(value, maxLen) {
  var s = String(value == null ? "" : value)
  var max = maxLen || MAX_TEXT
  var out = ""
  for (var i = 0; i < s.length && out.length < max; i++) {
    var code = s.charCodeAt(i)
    if (code < 32 || (code >= 127 && code < 160)) continue
    if (code >= 0x202A && code <= 0x202E) continue
    if (code >= 0x2066 && code <= 0x2069) continue
    var c = s.charAt(i)
    if (c === "<" || c === ">" || c === "&") continue
    out += c
  }
  return out
}

function finite(v) {
  if (typeof v === "boolean" || v === null || v === undefined) return NaN
  if (typeof v === "string") {
    if (v.length === 0 || v.length > 32) return NaN
    if (!/^-?\d+(\.\d+)?$/.test(v)) return NaN
  } else if (typeof v !== "number") {
    return NaN
  }
  var n = typeof v === "number" ? v : Number(v)
  if (!isFinite(n) || Math.abs(n) > 1e12) return NaN
  return n
}

function finiteOrNull(v) {
  if (v === null || v === undefined || v === "") return null
  var n = finite(v)
  return isFinite(n) ? n : null
}

function intOf(v) {
  var n = finite(v)
  if (!isFinite(n)) return 0
  return Math.round(n)
}

function pickColor(hex, fallback) {
  if (typeof hex === "string" && /^#[0-9A-Fa-f]{6}$/.test(hex)) return hex
  return fallback
}

function sanitizeColors(raw) {
  var out = {}
  if (!raw || typeof raw !== "object") return out
  for (var i = 0; i < COLOR_KEYS.length; i++) {
    var key = COLOR_KEYS[i]
    var hex = pickColor(raw[key], "")
    if (hex) out[key] = hex
  }
  return out
}

function storeColor(key, index, colors, fallback) {
  var k = String(key || "").toUpperCase().replace(/^\s+|\s+$/g, "")
  var name = STORE_COLOR_NAMES[k]
  if (!name) {
    var i = parseInt(index, 10)
    if (!isFinite(i) || i < 0) i = 0
    name = STORE_COLOR_FALLBACK[i % STORE_COLOR_FALLBACK.length]
  }
  return pickColor(colors && colors[name], fallback)
}

function emptyChannels() {
  return {
    paid: 0, organic: 0, direct: 0, email: 0,
    prevPaid: null, prevOrganic: null, prevDirect: null, prevEmail: null
  }
}

function emptyChannelBars() {
  return { paid: [], organic: [], direct: [], email: [] }
}

function emptyPrevDaily() {
  return {
    revenue: [], orders: [], sessions: [], spend: [],
    cvr: [], aov: [], cos: []
  }
}

function emptyPayload() {
  return {
    ok: false,
    error: "No data",
    symbol: "£",
    today: { date: "", calendarDate: "", revenue: 0, orders: 0, sessions: 0, cos: "", spend: null, cvr: null },
    period: { days: 0, revenue: 0, prevRevenue: 0, orders: 0, sessions: 0, spend: 0 },
    channels: emptyChannels(),
    channelBars: emptyChannelBars(),
    prevDaily: emptyPrevDaily(),
    month: { forecastRevenue: 0 },
    bars: [],
    orderBars: [],
    sessionBars: [],
    spendBars: [],
    cvrBars: [],
    aovBars: [],
    cosBars: []
  }
}

function dateOf(v) {
  var text = plain(v, 32)
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : ""
}

function barsOf(list) {
  if (!Array.isArray(list)) return []
  if (list.length > MAX_BARS) return null
  var out = []
  for (var i = 0; i < list.length; i++) {
    var b = list[i]
    if (!b || typeof b !== "object") continue
    var value = finite(b.value)
    if (!isFinite(value) || value < 0) value = 0
    out.push({ date: dateOf(b.date), value: value })
  }
  return out
}

function normalizePayload(json) {
  var empty = emptyPayload()
  if (!json || typeof json !== "object" || Array.isArray(json)) return empty

  var bars = barsOf(json.bars)
  var orderBars = barsOf(json.orderBars)
  var sessionBars = barsOf(json.sessionBars)
  var spendBars = barsOf(json.spendBars)
  var cvrBars = barsOf(json.cvrBars)
  var aovBars = barsOf(json.aovBars)
  var cosBars = barsOf(json.cosBars)
  if (!bars || !orderBars || !sessionBars || !spendBars || !cvrBars || !aovBars || !cosBars)
    return empty

  var today = json.todayDetail && typeof json.todayDetail === "object" ? json.todayDetail : {}
  var period = json.period && typeof json.period === "object" ? json.period : {}
  var channelBarsIn = json.channelBars && typeof json.channelBars === "object" ? json.channelBars : {}
  var paidBars = barsOf(channelBarsIn.paid)
  var organicBars = barsOf(channelBarsIn.organic)
  var directBars = barsOf(channelBarsIn.direct)
  var emailBars = barsOf(channelBarsIn.email)
  if (!paidBars || !organicBars || !directBars || !emailBars) return empty

  var prevIn = json.prevDaily && typeof json.prevDaily === "object" ? json.prevDaily : {}
  var prevRevenue = barsOf(prevIn.revenue)
  var prevOrders = barsOf(prevIn.orders)
  var prevSessions = barsOf(prevIn.sessions)
  var prevSpend = barsOf(prevIn.spend)
  var prevCvr = barsOf(prevIn.cvr)
  var prevAov = barsOf(prevIn.aov)
  var prevCos = barsOf(prevIn.cos)
  if (!prevRevenue || !prevOrders || !prevSessions || !prevSpend || !prevCvr || !prevAov || !prevCos)
    return empty

  var channels = json.channels && typeof json.channels === "object" ? json.channels : {}
  var month = json.month && typeof json.month === "object" ? json.month : {}
  var days = intOf(period.days)
  if (days < 0) days = 0
  if (days > 366) days = 366

  var symbol = plain(json.symbol, 4)
  if (!symbol) symbol = "£"

  var payload = {
    ok: false,
    error: "",
    symbol: symbol,
    today: {
      date: dateOf(today.date),
      calendarDate: dateOf(today.calendarDate),
      revenue: finite(today.revenue) || 0,
      orders: Math.max(0, intOf(today.orders)),
      sessions: Math.max(0, intOf(today.sessions)),
      cos: plain(today.cos, 16),
      spend: finiteOrNull(today.spend),
      cvr: finiteOrNull(today.cvr)
    },
    period: {
      days: days,
      revenue: finite(period.revenue) || 0,
      prevRevenue: finite(period.prevRevenue) || 0,
      orders: Math.max(0, intOf(period.orders)),
      sessions: Math.max(0, intOf(period.sessions)),
      spend: finite(period.spend) || 0
    },
    channels: {
      paid: Math.max(0, finite(channels.paid) || 0),
      organic: Math.max(0, finite(channels.organic) || 0),
      direct: Math.max(0, finite(channels.direct) || 0),
      email: Math.max(0, finite(channels.email) || 0),
      prevPaid: finiteOrNull(channels.prevPaid),
      prevOrganic: finiteOrNull(channels.prevOrganic),
      prevDirect: finiteOrNull(channels.prevDirect),
      prevEmail: finiteOrNull(channels.prevEmail)
    },
    channelBars: {
      paid: paidBars,
      organic: organicBars,
      direct: directBars,
      email: emailBars
    },
    prevDaily: {
      revenue: prevRevenue,
      orders: prevOrders,
      sessions: prevSessions,
      spend: prevSpend,
      cvr: prevCvr,
      aov: prevAov,
      cos: prevCos
    },
    month: { forecastRevenue: Math.max(0, finite(month.forecastRevenue) || 0) },
    bars: bars,
    orderBars: orderBars,
    sessionBars: sessionBars,
    spendBars: spendBars,
    cvrBars: cvrBars,
    aovBars: aovBars,
    cosBars: cosBars
  }

  var revenue = finite(json.revenue) || 0
  var orders = intOf(json.orders)
  payload.ok = payload.today.date !== "" || payload.bars.length > 0 || revenue !== 0 || orders !== 0
  if (!payload.ok) {
    var err = plain(json.text || json.label || "No data", 160)
    payload.error = err || "No data"
  }
  return payload
}

function storeKeyOk(key) {
  if (key === "__proto__" || key === "constructor" || key === "prototype") return false
  return /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(key)
}

function parseSnapshot(raw) {
  var text = String(raw || "").replace(/^\s+|\s+$/g, "")
  var empty = { stores: [], payloads: {} }
  if (!text) return empty
  var json
  try { json = JSON.parse(text) } catch (e) { return empty }
  if (!json || typeof json !== "object" || Array.isArray(json)) return empty

  var list = Array.isArray(json.stores) ? json.stores : []
  if (list.length > MAX_STORES) return empty
  var stores = []
  for (var i = 0; i < list.length; i++) {
    var entry = list[i] || {}
    var key = plain(entry.key, 64).replace(/^\s+|\s+$/g, "")
    if (!storeKeyOk(key)) continue
    var title = plain(entry.title || key, MAX_TEXT).replace(/^\s+|\s+$/g, "")
    stores.push({ key: key, title: title || key })
  }

  var src = json.payloads && typeof json.payloads === "object" && !Array.isArray(json.payloads)
    ? json.payloads : {}
  var payloads = {}
  for (var s = 0; s < stores.length; s++) {
    var storeKey = stores[s].key
    payloads[storeKey] = Object.prototype.hasOwnProperty.call(src, storeKey)
      ? normalizePayload(src[storeKey])
      : emptyPayload()
  }
  return { stores: stores, payloads: payloads }
}

function asPayload(p) {
  if (!p || typeof p !== "object" || !Array.isArray(p.bars)) return emptyPayload()
  return p
}

function currency(p) {
  var payload = asPayload(p)
  return payload.symbol || "£"
}

function commaInt(n) {
  var rounded = Math.round(n)
  var neg = rounded < 0
  var s = String(Math.abs(rounded))
  var out = ""
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 === 0) out += ","
    out += s.charAt(i)
  }
  return (neg ? "-" : "") + out
}

function formatRevenue(val, symbol) {
  var n = finite(val)
  if (!isFinite(n)) n = 0
  return (symbol || "£") + commaInt(n)
}

function formatMoney(val, symbol) {
  if (val === null || val === undefined || !isFinite(val) || val <= 0) return "—"
  return formatRevenue(val, symbol)
}

function formatPct(val) {
  if (val === null || val === undefined || !isFinite(val)) return "—"
  return (val * 100).toFixed(1) + "%"
}

function formatInt(n) {
  var v = finite(n)
  if (!isFinite(v)) v = 0
  return commaInt(v)
}

function formatAov(detail, symbol) {
  if (!detail || !detail.orders) return "—"
  return formatRevenue(detail.revenue / detail.orders, symbol)
}

function formatDay(dateStr) {
  var text = String(dateStr || "").replace(/^\s+|\s+$/g, "")
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text)
  if (!m) return ""
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var month = parseInt(m[2], 10)
  var day = parseInt(m[3], 10)
  if (month < 1 || month > 12 || day < 1 || day > 31) return ""
  return months[month - 1] + " " + day
}

function dashIfEmpty(s) {
  var text = String(s || "").replace(/^\s+|\s+$/g, "")
  if (!text || text === "—") return "—"
  return plain(text, 16)
}

function kpiHeroMeta(detail) {
  if (!detail) return ""
  var date = String(detail.date || "")
  var cal = String(detail.calendarDate || "")
  if (date && cal && date !== cal) {
    var label = formatDay(date)
    if (label) return "As of " + label
  }
  return ""
}

function metricById(id) {
  return CHARTS[id] || CHARTS.revenue
}

function barsFor(payload, id) {
  var p = asPayload(payload)
  if (id === "orders") return p.orderBars
  if (id === "sessions") return p.sessionBars
  if (id === "cvr") return p.cvrBars
  if (id === "aov") return p.aovBars
  if (id === "cos") return p.cosBars
  if (id === "spend") return p.spendBars
  return p.bars
}

function prevBarsFor(payload, id) {
  var p = asPayload(payload)
  var prev = p.prevDaily || emptyPrevDaily()
  if (id === "orders") return prev.orders
  if (id === "sessions") return prev.sessions
  if (id === "cvr") return prev.cvr
  if (id === "aov") return prev.aov
  if (id === "cos") return prev.cos
  if (id === "spend") return prev.spend
  return prev.revenue
}

function utcDay(dateStr) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateStr || ""))
  if (!match) return NaN
  return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
}

function weekdayAlign(current, previous) {
  var prev = (previous || []).slice()
  prev.sort(function(a, b) {
    return String(a && a.date || "").localeCompare(String(b && b.date || ""))
  })
  var out = []
  if (!current || !current.length || !prev.length) return out
  var currentStart = utcDay(current[0] && current[0].date)
  var prevStart = utcDay(prev[0] && prev[0].date)
  if (!isFinite(currentStart) || !isFinite(prevStart)) return out
  var shift = (new Date(currentStart).getUTCDay() - new Date(prevStart).getUTCDay() + 7) % 7
  for (var i = 0; i < current.length; i++) {
    var src = prev[i + shift]
    var value = src && typeof src.value === "number" ? src.value : null
    out.push({ date: current[i] && current[i].date || "", value: value })
  }
  return out
}

function compareBarsFor(payload, id) {
  return weekdayAlign(barsFor(payload, id), prevBarsFor(payload, id))
}

function chartFigure(payload, metricId) {
  var p = asPayload(payload)
  var cur = currency(p)
  var period = p.period
  if (metricId === "revenue") return formatRevenue(period.revenue, cur)
  if (metricId === "orders") return formatInt(period.orders)
  if (metricId === "sessions") return formatInt(period.sessions)
  if (metricId === "spend") return formatMoney(period.spend, cur)
  if (metricId === "aov")
    return period.orders > 0 ? formatMoney(period.revenue / period.orders, cur) : "—"
  if (metricId === "cos")
    return period.revenue > 0 ? formatPct(period.spend / period.revenue) : "—"
  if (metricId === "cvr")
    return period.sessions > 0 ? formatPct(period.orders / period.sessions) : "—"
  return ""
}

function chartChange(payload, metricId) {
  if (metricId !== "revenue") return { text: "", tone: "up" }
  var p = asPayload(payload)
  var delta = pctDelta(p.period.revenue, p.period.prevRevenue)
  var tone = "up"
  if (delta !== null && Math.abs(delta) >= 0.05 && delta < 0) tone = "down"
  return { text: formatDelta(delta), tone: tone }
}

function metricClickable(payload, id) {
  var p = asPayload(payload)
  if (!p.ok) return false
  if (KPI_ORDER.indexOf(id) < 0) return false
  return barsFor(p, id).length > 0
}

function nextMetric(payload, current, dir) {
  var step = dir === 0 || dir === undefined ? 1 : dir
  var idx = 0
  for (var i = 0; i < KPI_ORDER.length; i++) {
    if (KPI_ORDER[i] === current) { idx = i; break }
  }
  var n = KPI_ORDER.length
  for (var j = 0; j < n; j++) {
    idx = (idx + step + n) % n
    if (metricClickable(payload, KPI_ORDER[idx])) return KPI_ORDER[idx]
  }
  return current
}

function periodDays(p) {
  if (p.period.days > 0) return p.period.days
  if (p.bars.length > 0) return p.bars.length
  return 30
}

function seriesDelta(series) {
  if (!series || series.length < 2) return null
  var last = series[series.length - 1]
  var current = last && last.value
  if (typeof current !== "number" || !isFinite(current)) return null
  var previous = null
  var target = utcDay(last && last.date)
  if (isFinite(target)) {
    var weekAgo = target - 7 * 86400000
    for (var i = 0; i < series.length; i++) {
      if (utcDay(series[i] && series[i].date) === weekAgo) {
        previous = series[i].value
        break
      }
    }
  } else if (series.length > 7) {
    previous = series[series.length - 8].value
  }
  if (typeof previous !== "number" || !isFinite(previous)) return null
  return pctDelta(current, previous)
}

function todayPoint(detail, id) {
  if (!detail || !detail.date) return null
  if (id === "revenue") return detail.revenue
  if (id === "orders") return detail.orders
  if (id === "sessions") return detail.sessions
  if (id === "spend") return detail.spend
  if (id === "cvr") return detail.cvr
  if (id === "aov") return detail.orders ? detail.revenue / detail.orders : null
  if (id === "cos") {
    if (!detail.revenue || detail.spend === null || detail.spend === undefined) return null
    return detail.spend / detail.revenue
  }
  return null
}

function withToday(series, detail, id) {
  var value = todayPoint(detail, id)
  var base = series ? series.slice() : []
  if (value === null || !isFinite(value) || !detail || !detail.date) return base
  if (base.length && base[base.length - 1] && base[base.length - 1].date === detail.date) return base
  base.push({ date: detail.date, value: value })
  return base
}

function kpiCells(payload, metricId) {
  var p = asPayload(payload)
  if (!p.ok) return []
  var cur = currency(p)
  var d = p.today
  var specs = [
    ["revenue", "Rev.", formatRevenue(d.revenue, cur)],
    ["orders", "Orders", formatInt(d.orders)],
    ["cos", "CoS", dashIfEmpty(d.cos)],
    ["cvr", "CvR", formatPct(d.cvr)],
    ["aov", "AoV", formatAov(d, cur)],
    ["sessions", "Sess.", formatInt(d.sessions)],
    ["spend", "Spend", formatMoney(d.spend, cur)]
  ]
  var out = []
  for (var i = 0; i < specs.length; i++) {
    var spec = specs[i]
    var series = withToday(barsFor(p, spec[0]), d, spec[0])
    var delta = seriesDelta(series)
    var higherIsWorse = spec[0] === "cos" || spec[0] === "spend"
    var tone = "up"
    if (delta !== null && Math.abs(delta) >= 0.05)
      tone = (higherIsWorse ? delta > 0 : delta < 0) ? "down" : "up"
    out.push({
      id: spec[0],
      label: spec[1],
      value: spec[2],
      spark: sparkValues(series),
      delta: formatDelta(delta),
      tone: tone,
      selected: spec[0] === metricId,
      clickable: metricClickable(p, spec[0])
    })
  }
  return out
}

function pctDelta(current, previous) {
  if (previous === null || previous === undefined || !isFinite(previous)) return null
  if (Math.abs(previous) < 1e-9) return null
  if (!isFinite(current)) return null
  return ((current - previous) / previous) * 100
}

function formatDelta(delta) {
  if (delta === null || !isFinite(delta)) return ""
  var sign = delta > 0 ? "+" : ""
  return sign + delta.toFixed(1) + "%"
}

function sparkValues(series) {
  if (!series || !series.length) return []
  var out = []
  for (var i = 0; i < series.length; i++) {
    var v = series[i] && series[i].value
    out.push(typeof v === "number" && isFinite(v) ? v : 0)
  }
  return out
}

function channelCards(payload) {
  var p = asPayload(payload)
  var cur = currency(p)
  var ch = p.channels || emptyChannels()
  var bars = p.channelBars || emptyChannelBars()
  var specs = [
    ["Paid revenue", ch.paid, ch.prevPaid, bars.paid],
    ["Organic revenue", ch.organic, ch.prevOrganic, bars.organic],
    ["Direct revenue", ch.direct, ch.prevDirect, bars.direct],
    ["Email revenue", ch.email, ch.prevEmail, bars.email]
  ]
  var total = 0
  var cards = []
  for (var i = 0; i < specs.length; i++) {
    var value = finite(specs[i][1]) || 0
    total += value
    var delta = pctDelta(value, specs[i][2])
    var tone = "flat"
    if (delta !== null && Math.abs(delta) >= 0.05) tone = delta > 0 ? "up" : "down"
    cards.push({
      label: specs[i][0],
      value: formatRevenue(value, cur),
      delta: formatDelta(delta),
      tone: tone,
      spark: sparkValues(specs[i][3])
    })
  }
  return { total: total, cards: cards }
}

function chartTitle(payload, metricId) {
  var p = asPayload(payload)
  var def = metricById(metricId)
  return periodDays(p) + " day " + def.label
}

