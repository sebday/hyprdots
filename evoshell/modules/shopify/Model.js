.pragma library
.import qs.commons as Commons

var MAX_STORES = 16
var MAX_BARS = 400
var MAX_TEXT = 80

var KPI_ORDER = [
  "revenue", "orders", "cos", "refunds", "cvr", "aov",
  "sessions", "spend"
]

var CHARTS = {
  revenue: { id: "revenue", label: "revenue", valueKind: "currency" },
  orders: { id: "orders", label: "orders", valueKind: "integer" },
  sessions: { id: "sessions", label: "sessions", valueKind: "integer" },
  cvr: { id: "cvr", label: "conversion rate", valueKind: "percent" },
  aov: { id: "aov", label: "order value", valueKind: "currency" },
  cos: { id: "cos", label: "cost of sale", valueKind: "percent" },
  spend: { id: "spend", label: "ad spend", valueKind: "currency" },
  refunds: { id: "refunds", label: "refunds", valueKind: "currency" }
}

var HIGHER_IS_WORSE = { cos: true, spend: true, refunds: true }

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
    cvr: [], aov: [], cos: [], refunds: []
  }
}

function emptyPayload() {
  return {
    ok: false,
    error: "No data",
    symbol: "£",
    today: { date: "", calendarDate: "", revenue: 0, orders: 0, sessions: 0, cos: "", spend: null, cvr: null, refunds: null },
    period: { days: 0, revenue: 0, prevRevenue: 0, orders: 0, sessions: 0, spend: 0, refunds: null, prevRefunds: null },
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
    cosBars: [],
    refundBars: []
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
  var refundBars = barsOf(json.refundBars)
  if (!bars || !orderBars || !sessionBars || !spendBars || !cvrBars || !aovBars || !cosBars || !refundBars)
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
  var prevRefunds = barsOf(prevIn.refunds)
  if (!prevRevenue || !prevOrders || !prevSessions || !prevSpend || !prevCvr || !prevAov || !prevCos || !prevRefunds)
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
      cvr: finiteOrNull(today.cvr),
      refunds: finiteOrNull(today.refunds)
    },
    period: {
      days: days,
      revenue: finite(period.revenue) || 0,
      prevRevenue: finite(period.prevRevenue) || 0,
      orders: Math.max(0, intOf(period.orders)),
      sessions: Math.max(0, intOf(period.sessions)),
      spend: finite(period.spend) || 0,
      refunds: finiteOrNull(period.refunds),
      prevRefunds: finiteOrNull(period.prevRefunds)
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
      cos: prevCos,
      refunds: prevRefunds
    },
    month: { forecastRevenue: Math.max(0, finite(month.forecastRevenue) || 0) },
    bars: bars,
    orderBars: orderBars,
    sessionBars: sessionBars,
    spendBars: spendBars,
    cvrBars: cvrBars,
    aovBars: aovBars,
    cosBars: cosBars,
    refundBars: refundBars
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
  return Commons.Format.formatRevenue(val, symbol)
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

function formatRefund(val, symbol) {
  var n = finite(val)
  if (!isFinite(n)) return "—"
  return formatRevenue(n, symbol)
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
  if (id === "refunds") return p.refundBars || []
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
  if (id === "refunds") return prev.refunds || []
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

function seriesSum(series) {
  var total = 0
  var seen = false
  for (var i = 0; i < (series || []).length; i++) {
    var v = series[i] && series[i].value
    if (typeof v !== "number" || !isFinite(v)) continue
    total += v
    seen = true
  }
  return seen ? total : null
}

function ratio(a, b) {
  if (a === null || b === null || !isFinite(a) || !isFinite(b) || b <= 0) return null
  return a / b
}

// Period totals. The prior period is summed from prevDaily where the API has
// no total of its own.
function periodTotals(p, previous) {
  var period = p.period
  var prev = p.prevDaily || emptyPrevDaily()
  if (!previous) {
    return {
      revenue: period.revenue,
      orders: period.orders,
      sessions: period.sessions,
      spend: period.spend,
      refunds: period.refunds
    }
  }
  // The today cards do not use this. Their vs line is one day, seven days back.
  if (showsToday(p)) {
    return {
      revenue: seriesSum(prev.revenue),
      orders: seriesSum(prev.orders),
      sessions: seriesSum(prev.sessions),
      spend: seriesSum(prev.spend),
      refunds: seriesSum(prev.refunds)
    }
  }
  return {
    revenue: period.prevRevenue > 0 ? period.prevRevenue : seriesSum(prev.revenue),
    orders: seriesSum(prev.orders),
    sessions: seriesSum(prev.sessions),
    spend: seriesSum(prev.spend),
    refunds: period.prevRefunds !== null ? period.prevRefunds : seriesSum(prev.refunds)
  }
}

function periodValue(p, metricId, previous) {
  var t = periodTotals(p, previous)
  if (metricId === "aov") return ratio(t.revenue, t.orders)
  if (metricId === "cos") return ratio(t.spend, t.revenue)
  if (metricId === "cvr") return ratio(t.orders, t.sessions)
  var v = t[metricId]
  return typeof v === "number" && isFinite(v) ? v : null
}

function chartSource(payload, metricId, previous) {
  var p = asPayload(payload)
  return showsToday(p) ? comparisonValue(p, metricId, previous) : periodValue(p, metricId, previous)
}

function chartFigure(payload, metricId) {
  var p = asPayload(payload)
  var value = chartSource(p, metricId, false)
  return value === null ? "—" : formatSeriesValue(metricId, value, currency(p))
}

function chartCompare(payload, metricId) {
  var p = asPayload(payload)
  var previous = chartSource(p, metricId, true)
  return previous === null ? "" : versusText(formatSeriesValue(metricId, previous, currency(p)))
}

function chartChange(payload, metricId) {
  var p = asPayload(payload)
  var delta = pctDelta(chartSource(p, metricId, false), chartSource(p, metricId, true))
  return { text: formatDelta(delta), tone: toneOf(delta, HIGHER_IS_WORSE[metricId] === true) }
}

function toneOf(delta, higherIsWorse) {
  if (delta === null || !isFinite(delta) || Math.round(delta) === 0) return "flat"
  return (higherIsWorse ? delta > 0 : delta < 0) ? "down" : "up"
}

function rangeText(series) {
  if (!series || !series.length) return ""
  var first = formatDay(series[0] && series[0].date)
  var last = formatDay(series[series.length - 1] && series[series.length - 1].date)
  if (!first || !last) return ""
  return first === last ? first : first + " – " + last
}

function chartRanges(payload, metricId) {
  var p = asPayload(payload)
  var prev = (prevBarsFor(p, metricId) || []).slice()
  prev.sort(function(a, b) {
    return String(a && a.date || "").localeCompare(String(b && b.date || ""))
  })
  return { current: rangeText(barsFor(p, metricId)), previous: rangeText(prev) }
}

// Short axis labels: £12k, 1.2k, 3.5%.
function axisValue(metricId, value, symbol) {
  if (typeof value !== "number" || !isFinite(value)) return ""
  var kind = metricById(metricId).valueKind
  if (kind === "percent") {
    var pct = value * 100
    return (pct >= 10 ? String(Math.round(pct)) : trimZero(pct.toFixed(1))) + "%"
  }
  var abs = Math.abs(value)
  var text
  if (abs >= 1e6) text = trimZero((value / 1e6).toFixed(1)) + "M"
  else if (abs >= 1e3) text = trimZero((value / 1e3).toFixed(abs >= 1e4 ? 0 : 1)) + "k"
  else text = String(Math.round(value))
  return kind === "currency" ? (symbol || "£") + text : text
}

function trimZero(s) {
  return String(s).replace(/\.0$/, "")
}

// Rounds the axis top up to a tidy step for `ticks` gridlines.
function niceCeil(value, ticks) {
  if (!(value > 0)) return ticks
  var raw = (value * 1.05) / ticks
  var exp = Math.floor(Math.log(raw) / Math.LN10)
  var fraction = raw / Math.pow(10, exp)
  var steps = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]
  var nice = 10
  for (var i = 0; i < steps.length; i++) {
    if (fraction <= steps[i]) { nice = steps[i]; break }
  }
  return nice * Math.pow(10, exp) * ticks
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

function seriesPrevious(series) {
  if (!series || series.length < 2) return null
  var last = series[series.length - 1]
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
  return previous
}

function seriesDelta(series) {
  if (!series || series.length < 2) return null
  var last = series[series.length - 1]
  var current = last && last.value
  if (typeof current !== "number" || !isFinite(current)) return null
  return pctDelta(current, seriesPrevious(series))
}

function formatSeriesValue(id, value, cur) {
  if (typeof value !== "number" || !isFinite(value)) return ""
  if (id === "revenue" || id === "spend" || id === "refunds" || id === "aov")
    return formatRevenue(value, cur)
  if (id === "orders" || id === "sessions") return formatInt(value)
  if (id === "cvr" || id === "cos") return formatPct(value)
  return ""
}

function versusText(formatted) {
  if (!formatted) return ""
  return "vs " + formatted
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
  if (id === "refunds") return finiteOrNull(detail.refunds)
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

function showsToday(payload) {
  var p = asPayload(payload)
  if (p.period.days !== 1) return false
  var today = String(p.today.calendarDate || "")
  if (today === "" || String(p.today.date || "") !== today) return false
  var bars = p.bars || []
  if (!bars.length) return false
  return String(bars[bars.length - 1] && bars[bars.length - 1].date || "") === today
}

function pointOnDate(series, date) {
  if (!date) return null
  var rows = series || []
  for (var i = 0; i < rows.length; i++) {
    if (!rows[i] || rows[i].date !== date) continue
    var v = rows[i].value
    return typeof v === "number" && isFinite(v) ? v : null
  }
  return null
}

// Last 7 days against the previous 7. The chart uses this. Card headlines do not.
function comparisonValue(p, id, previous) {
  var revenue = seriesSum(previous ? prevBarsFor(p, "revenue") : barsFor(p, "revenue"))
  var orders = seriesSum(previous ? prevBarsFor(p, "orders") : barsFor(p, "orders"))
  var sessions = seriesSum(previous ? prevBarsFor(p, "sessions") : barsFor(p, "sessions"))
  var spend = seriesSum(previous ? prevBarsFor(p, "spend") : barsFor(p, "spend"))
  var refunds = seriesSum(previous ? prevBarsFor(p, "refunds") : barsFor(p, "refunds"))
  if (id === "aov") return ratio(revenue, orders)
  if (id === "cos") return ratio(spend, revenue)
  if (id === "cvr") return ratio(orders, sessions)
  if (id === "revenue") return revenue
  if (id === "orders") return orders
  if (id === "sessions") return sessions
  if (id === "spend") return spend
  if (id === "refunds") return refunds
  return null
}

function kpiCells(payload, metricId) {
  var p = asPayload(payload)
  if (!p.ok) return []
  if (showsToday(p)) return todayKpiCells(p, metricId)
  return periodKpiCells(p, metricId)
}

function periodKpiCells(payload, metricId) {
  var p = asPayload(payload)
  var cur = currency(p)
  var specs = [
    ["revenue", "Revenue"],
    ["orders", "Orders"],
    ["cos", "Cost of sale"],
    ["refunds", "Refunds"],
    ["cvr", "CvR"],
    ["aov", "AoV"],
    ["sessions", "Sessions"],
    ["spend", "Ad spend"]
  ]
  var out = []
  for (var i = 0; i < specs.length; i++) {
    var id = specs[i][0]
    var current = periodValue(p, id, false)
    var previous = periodValue(p, id, true)
    var delta = pctDelta(current, previous)
    out.push({
      id: id,
      label: specs[i][1],
      value: current === null ? "—" : formatSeriesValue(id, current, cur),
      compare: previous === null ? "" : versusText(formatSeriesValue(id, previous, cur)),
      spark: sparkValues(barsFor(p, id)),
      priorSpark: sparkValues(compareBarsFor(p, id), true),
      delta: formatDelta(delta),
      tone: toneOf(delta, HIGHER_IS_WORSE[id] === true),
      selected: id === metricId,
      clickable: metricClickable(p, id)
    })
  }
  return out
}

function todayKpiCells(payload, metricId) {
  var p = asPayload(payload)
  if (!p.ok) return []
  var cur = currency(p)
  var d = p.today
  var specs = [
    ["revenue", "Revenue", formatRevenue(d.revenue, cur)],
    ["orders", "Orders", formatInt(d.orders)],
    ["cos", "Cost of sale", dashIfEmpty(d.cos)],
    ["refunds", "Refunds", formatRefund(d.refunds, cur)],
    ["cvr", "CvR", formatPct(d.cvr)],
    ["aov", "AoV", formatAov(d, cur)],
    ["sessions", "Sessions", formatInt(d.sessions)],
    ["spend", "Ad spend", formatMoney(d.spend, cur)]
  ]
  var ago = addDays(String(d.date || ""), -7)
  var out = []
  for (var i = 0; i < specs.length; i++) {
    var spec = specs[i]
    var current = todayPoint(d, spec[0])
    var previous = pointOnDate(prevBarsFor(p, spec[0]), ago)
    var delta = pctDelta(current, previous)
    var compare = previous === null ? "" : versusText(formatSeriesValue(spec[0], previous, cur))
    out.push({
      id: spec[0],
      label: spec[1],
      value: spec[2],
      compare: compare,
      spark: sparkValues(barsFor(p, spec[0])),
      priorSpark: sparkValues(compareBarsFor(p, spec[0]), true),
      delta: formatDelta(delta),
      tone: toneOf(delta, HIGHER_IS_WORSE[spec[0]] === true),
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
  var rounded = Math.round(delta)
  if (rounded === 0) return "0%"
  return (rounded > 0 ? "+" : "") + rounded + "%"
}

// keepGaps leaves missing points as null so a line can skip them.
function sparkValues(series, keepGaps) {
  if (!series || !series.length) return []
  var out = []
  for (var i = 0; i < series.length; i++) {
    var v = series[i] && series[i].value
    out.push(typeof v === "number" && isFinite(v) ? v : (keepGaps ? null : 0))
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
    var previous = specs[i][2]
    cards.push({
      id: "",
      label: specs[i][0],
      value: formatRevenue(value, cur),
      compare: versusText(formatSeriesValue("revenue", typeof previous === "number" ? previous : NaN, cur)),
      delta: formatDelta(delta),
      tone: toneOf(delta, false),
      spark: sparkValues(specs[i][3]),
      priorSpark: [],
      selected: false,
      clickable: false
    })
  }
  return { total: total, cards: cards }
}

function chartTitle(payload, metricId) {
  return "Daily " + metricById(metricId).label
}

function periodLabel(payload) {
  return periodDays(asPayload(payload)) + " days"
}

var RANGE_PRESETS = [
  { kind: "today", label: "Today" },
  { kind: "last7Days", label: "Last 7 days" },
  { kind: "last30Days", label: "Last 30 days" },
  { kind: "last90Days", label: "Last 90 days" },
  { kind: "lastWeek", label: "Last Week" },
  { kind: "lastMonth", label: "Last Month" },
  { kind: "thisWeek", label: "This Week" },
  { kind: "thisMonth", label: "This Month" }
]

var MONTHS_LONG = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
]

function pad2(n) {
  return (n < 10 ? "0" : "") + n
}

function parseIso(value) {
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value || ""))
  if (!m) return ""
  var y = Number(m[1])
  var mo = Number(m[2])
  var d = Number(m[3])
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return ""
  var dt = new Date(Date.UTC(y, mo - 1, d))
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) return ""
  return m[0]
}

function isoToday() {
  var d = new Date()
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function addDays(iso, days) {
  var p = parseIso(iso)
  if (!p) return ""
  var parts = p.split("-")
  var dt = new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])))
  dt.setUTCDate(dt.getUTCDate() + Number(days))
  return dt.getUTCFullYear() + "-" + pad2(dt.getUTCMonth() + 1) + "-" + pad2(dt.getUTCDate())
}

function addMonths(iso, months) {
  var p = parseIso(iso)
  if (!p) return ""
  var parts = p.split("-")
  var y = Number(parts[0])
  var m = Number(parts[1]) - 1 + Number(months)
  var day = Number(parts[2])
  var dt = new Date(Date.UTC(y, m, 1))
  var dim = new Date(Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth() + 1, 0)).getUTCDate()
  dt.setUTCDate(Math.min(day, dim))
  return dt.getUTCFullYear() + "-" + pad2(dt.getUTCMonth() + 1) + "-" + pad2(dt.getUTCDate())
}

function startOfMonth(iso) {
  var p = parseIso(iso)
  return p ? p.slice(0, 7) + "-01" : ""
}

function endOfMonth(iso) {
  var start = startOfMonth(iso)
  return start ? addDays(addMonths(start, 1), -1) : ""
}

function startOfWeek(iso) {
  var p = parseIso(iso)
  if (!p) return ""
  var parts = p.split("-")
  var dt = new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])))
  return addDays(p, -((dt.getUTCDay() + 6) % 7))
}

function trailingRange(today, days) {
  var to = addDays(today, -1)
  return { from: addDays(to, -(days - 1)), to: to }
}

function rangeForPreset(kind, today) {
  var now = parseIso(today) || isoToday()
  if (kind === "today") return { from: now, to: now }
  if (kind === "last7Days") return trailingRange(now, 7)
  if (kind === "last30Days") return trailingRange(now, 30)
  if (kind === "last90Days") return trailingRange(now, 90)
  if (kind === "thisWeek") return { from: startOfWeek(now), to: now }
  if (kind === "thisMonth") return { from: startOfMonth(now), to: now }
  if (kind === "lastWeek") {
    var monday = startOfWeek(now)
    return { from: addDays(monday, -7), to: addDays(monday, -1) }
  }
  if (kind === "lastMonth") {
    var from = addMonths(startOfMonth(now), -1)
    return { from: from, to: endOfMonth(from) }
  }
  return trailingRange(now, 30)
}

function presetByKind(kind) {
  for (var i = 0; i < RANGE_PRESETS.length; i++) {
    if (RANGE_PRESETS[i].kind === kind) return RANGE_PRESETS[i]
  }
  return null
}

function formatDayLong(dateStr) {
  var text = parseIso(dateStr)
  if (!text) return ""
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  return Number(text.slice(8, 10)) + " " + months[Number(text.slice(5, 7)) - 1] + " " + text.slice(0, 4)
}

function rangeButtonLabel(preset, from, to) {
  var item = presetByKind(preset)
  if (item) return item.label
  var a = formatDayLong(from)
  var b = formatDayLong(to)
  if (!a || !b) return "Last 30 days"
  return a === b ? a : a + " – " + b
}

function monthTitle(monthIso) {
  var start = startOfMonth(monthIso)
  if (!start) return ""
  return MONTHS_LONG[Number(start.slice(5, 7)) - 1] + " " + start.slice(0, 4)
}

function calendarDays(monthIso, from, to, pending, today) {
  var month = startOfMonth(monthIso)
  var start = startOfWeek(month)
  if (!month || !start) return []
  var out = []
  for (var i = 0; i < 42; i++) {
    var day = addDays(start, i)
    var picked = pending ? day === pending : (day >= from && day <= to)
    out.push({
      date: day,
      label: String(Number(day.slice(8, 10))),
      outside: day.slice(0, 7) !== month.slice(0, 7),
      future: today !== "" && day > today,
      today: day === today,
      inRange: picked,
      edge: pending ? day === pending : (day === from || day === to)
    })
  }
  return out
}

