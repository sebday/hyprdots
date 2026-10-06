.pragma library
.import qs.commons as Commons


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

function formatRevenue(val, symbol) {
  return Commons.Format.formatRevenue(val, symbol)
}

function fmtUsd(val) {
  var n = parseFloat(val)
  if (isNaN(n)) return "—"
  if (n >= 10000) return formatRevenue(n, "$")
  return "$" + n.toFixed(2)
}

function fmtUsdWhole(val) {
  var n = parseFloat(val)
  if (isNaN(n)) return "—"
  return formatRevenue(n, "$")
}

function fmtGbp(val) {
  var n = parseFloat(val)
  if (isNaN(n)) return "—"
  return formatRevenue(n, "£")
}

function fmtBtc(val) {
  var n = parseFloat(val)
  if (isNaN(n) || n <= 0) return "—"
  return n.toFixed(3)
}

function fmtQty(val) {
  var n = parseFloat(val)
  if (isNaN(n) || n <= 0) return "—"
  return n.toFixed(2)
}

function fmtSignedPct(val) {
  var n = parseFloat(val)
  if (isNaN(n)) return "—"
  return (n >= 0 ? "+" : "") + n.toFixed(2) + "%"
}

function fmtPositionValue(position) {
  if (!position || typeof position !== "object") return "—"
  if (position.value !== undefined && position.value !== null)
    return fmtGbp(position.value)
  if (position.valueUsd !== undefined && position.valueUsd !== null)
    return fmtUsd(position.valueUsd)
  return "—"
}

function parseMarketPayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return { ok: false, error: "No data" }

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "Invalid response" }
  }

  return {
    ok: true,
    text: String(json.text || ""),
    tooltip: String(json.tooltip || ""),
    detail: String(json.detail || ""),
    bars: Array.isArray(json.bars) ? json.bars : [],
    source: String(json.source || ""),
    quote: json.quote && typeof json.quote === "object" ? json.quote : {},
    period: json.period && typeof json.period === "object" ? json.period : {},
    position: json.position && typeof json.position === "object" ? json.position : {}
  }
}

function hasPosition(data) {
  if (!data || typeof data !== "object") return false
  var pos = data.position || {}
  var bal = parseFloat(pos.balance)
  if (!isNaN(bal) && bal > 0) return true
  var qty = parseFloat(pos.quantity)
  if (!isNaN(qty) && qty > 0) return true
  return false
}

function btcTooltip(btcData) {
  if (!btcData || !btcData.quote) return "Stocks"
  var price = btcData.quote.price
  if (price === undefined || price === null) return "Stocks"
  return "BTC " + fmtUsd(price)
}

function chartBars(data, chartHistoryDays) {
  var days = parseInt(chartHistoryDays, 10) || 30
  var bars = Array.isArray(data.bars) ? data.bars : []
  if (bars.length <= days) return bars
  return bars.slice(bars.length - days)
}

function chartDays(data, chartHistoryDays) {
  var days = parseInt(chartHistoryDays, 10) || 30
  var period = data.period || {}
  if (period.days) return Math.min(days, period.days)
  var bars = chartBars(data, days)
  return bars.length > 0 ? bars.length : days
}

function marketSection(data, fallbackName, href, chartColor, chartHistoryDays) {
  return {
    name: fallbackName,
    href: href,
    source: String(data.source || ""),
    quote: data.quote || {},
    period: data.period || {},
    position: data.position || {},
    bars: chartBars(data, chartHistoryDays),
    days: chartDays(data, chartHistoryDays),
    chartColor: chartColor
  }
}

function marketStatBoxes(market, accent, urgent, foreground) {
  var position = market.position || {}
  var quote = market.quote || {}
  var price = quote.price
  var priceValue = price !== undefined && price !== null
    ? (market.name === "SPCX" ? fmtUsdWhole(price) : fmtUsd(price))
    : "—"
  var quantityValue = market.name === "BTC" ? fmtBtc(position.balance) : fmtQty(position.quantity)
  var quantityLabel = market.name === "BTC" ? "BTC" : "Shares"
  var upnl = position.upnlPct
  var upnlColor = signedColor(upnl, accent, urgent, foreground)
  return [
    { label: "Price", value: priceValue, special: true },
    { label: "Value", value: fmtPositionValue(position) },
    { label: quantityLabel, value: quantityValue },
    {
      label: "P/L",
      value: fmtSignedPct(upnl),
      valueColor: upnlColor,
      customFill: true
    }
  ]
}

function signedColor(val, accent, urgent, foreground) {
  var n = parseFloat(val)
  if (isNaN(n) || n === 0) return foreground
  return n > 0 ? accent : urgent
}

function marketSymbolIcon(name) {
  if (name === "BTC") return "₿"
  if (name === "SPCX") return "𝕏"
  return name ? String(name).charAt(0) : "?"
}

function marketTooltip(name, data) {
  if (!data || !data.quote) return name || "Market"
  var price = data.quote.price
  if (price === undefined || price === null) return name || "Market"
  var formatted = name === "SPCX" ? fmtUsdWhole(price) : fmtUsd(price)
  if (formatted === "—") return name || "Market"
  return name + " " + formatted
}

function barPrice(name, data) {
  return plain(barPricePart(name, data), 32)
}

function httpsUrl(value) {
  var s = String(value || "")
  if (!s || s.length > 300 || s.indexOf("https://") !== 0) return ""
  for (var i = 0; i < s.length; i++) {
    var code = s.charCodeAt(i)
    if (code <= 32 || code >= 127) return ""
    var c = s.charAt(i)
    if (c === "<" || c === ">" || c === "\"" || c === "'" || c === "\\") return ""
  }
  return s
}

function parseNewsPayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return { ok: false, items: [] }
  try {
    var json = JSON.parse(text)
  } catch (e) {
    return { ok: false, items: [] }
  }
  var items = []
  var rawItems = Array.isArray(json.items) ? json.items : []
  for (var i = 0; i < rawItems.length && items.length < 3; i++) {
    var item = rawItems[i]
    if (!item || typeof item !== "object") continue
    var url = httpsUrl(item.url)
    var title = plain(item.title, 110)
    if (!url || !title) continue
    items.push({
      title: title,
      source: plain(item.source, 40),
      url: url
    })
  }
  return {
    ok: json.ok === true && items.length > 0,
    items: items,
    model: plain(json.model, 40),
    modelId: plain(json.modelId, 80)
  }
}

function barPricePart(name, data) {
  if (!data || !data.quote) return ""
  var price = data.quote.price
  if (price === undefined || price === null) return ""
  var formatted = name === "SPCX" ? fmtUsdWhole(price) : fmtUsd(price)
  if (formatted === "—") return ""
  return marketSymbolIcon(name) + " " + formatted
}

function barPrices(btcData, spcxData) {
  var parts = []
  var btc = barPricePart("BTC", btcData)
  var spcx = barPricePart("SPCX", spcxData)
  if (btc) parts.push(btc)
  if (spcx) parts.push(spcx)
  return plain(parts.join("  "), 48)
}
