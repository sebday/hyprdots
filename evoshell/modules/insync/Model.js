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

function emptyData(error) {
  return {
    ok: false,
    error: String(error || ""),
    status: "",
    paused: false,
    accounts: [],
    files: [],
    errors: [],
    recent: [],
    syncedFiles: 0,
    syncedBytes: 0
  }
}

function list(data, key) {
  if (!data || !Array.isArray(data[key])) return []
  return data[key]
}

function parsePayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return emptyData()

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return emptyData("Invalid response")
  }

  return {
    ok: json.ok === true,
    error: String(json.error || ""),
    status: String(json.status || ""),
    paused: json.paused === true,
    accounts: Array.isArray(json.accounts) ? json.accounts : [],
    files: json.paused === true ? [] : (Array.isArray(json.files) ? json.files : []),
    errors: Array.isArray(json.errors) ? json.errors : [],
    recent: recentFiles(json),
    syncedFiles: nonNegative(json.syncedFiles),
    syncedBytes: nonNegative(json.syncedBytes)
  }
}

function recentFiles(data) {
  var rows = list(data, "recent")
  var out = []
  for (var i = 0; i < rows.length && out.length < 3; i++) {
    var row = rows[i]
    var name = plain(row && row.name, 160)
    if (!name) continue
    out.push({
      name: name,
      provider: plain(row && row.provider, 40),
      at: nonNegative(row && row.at)
    })
  }
  return out
}

function formatAgo(unix) {
  var t = nonNegative(unix)
  if (!t) return ""
  var sec = Math.round(Date.now() / 1000) - t
  if (sec < 45) return "just now"
  if (sec < 3600) return Math.max(1, Math.round(sec / 60)) + "m ago"
  if (sec < 86400) return Math.max(1, Math.round(sec / 3600)) + "h ago"
  var days = Math.round(sec / 86400)
  if (days < 14) return days + "d ago"
  var date = new Date(t * 1000)
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  return months[date.getMonth()] + " " + date.getDate()
}

function recentMeta(row) {
  var provider = plain(row && row.provider, 40)
  var when = formatAgo(row && row.at)
  if (provider && when) return provider + " · " + when
  return provider || when || ""
}

function nonNegative(value) {
  var n = Math.round(Number(value) || 0)
  return n > 0 ? n : 0
}

function formatCount(n) {
  var value = nonNegative(n)
  var digits = String(value)
  var out = ""
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 === 0) out += ","
    out += digits.charAt(i)
  }
  return out
}

function formatBytes(n) {
  n = Number(n) || 0
  if (n < 1024) return Math.round(n) + " B"
  if (n < 1048576) return (n / 1024).toFixed(1) + " KB"
  if (n < 1073741824) return (n / 1048576).toFixed(n >= 104857600 ? 0 : 1) + " MB"
  if (n < 1099511627776) return (n / 1073741824).toFixed(n >= 10737418240 ? 0 : 1) + " GB"
  return (n / 1099511627776).toFixed(2) + " TB"
}

function fileExt(name) {
  var s = String(name || "").toLowerCase()
  var dot = s.lastIndexOf(".")
  if (dot < 0 || dot === s.length - 1) return ""
  return s.substring(dot + 1)
}

function hasExt(ext, list) {
  return ext !== "" && (" " + list + " ").indexOf(" " + ext + " ") >= 0
}

function fileIcon(name) {
  var ext = fileExt(name)
  if (hasExt(ext, "png jpg jpeg gif webp svg heic heif bmp tif tiff avif ico")) return "󰈟"
  if (hasExt(ext, "pdf")) return "󰈦"
  if (hasExt(ext, "xls xlsx xlsm csv ods gdsheet gsheet numbers")) return "󰈛"
  if (hasExt(ext, "ppt pptx odp key")) return "󰈧"
  if (hasExt(ext, "doc docx odt rtf txt md markdown")) return "󰈙"
  if (hasExt(ext, "mp3 flac wav m4a ogg aac opus wma aiff")) return "󰈣"
  if (hasExt(ext, "mp4 mkv mov webm avi m4v")) return "󰈫"
  if (hasExt(ext, "zip gz tgz tar bz2 xz 7z rar")) return "󰗄"
  if (hasExt(ext, "js ts jsx tsx py go rs java c h cpp hpp css scss html htm xml json yml yaml sh sql toml")) return "󰈮"
  return "󰈔"
}

function providerIcon(provider) {
  var p = String(provider || "").toLowerCase()
  if (p.indexOf("google") >= 0) return "󰊾"
  if (p.indexOf("onedrive") >= 0) return "󰀄"
  if (p.indexOf("dropbox") >= 0) return "󰇚"
  return "󰖟"
}

function isSyncing(data, loading) {
  if (loading || !data) return false
  return list(data, "files").length > 0 && !data.paused
}

function hasWarning(data) {
  if (!data) return false
  if (list(data, "errors").length > 0) return true
  if (String(data.status || "").toUpperCase().indexOf("ERROR") >= 0) return true
  return false
}

function isUnavailable(data) {
  if (!data) return true
  if (data.ok) return false
  if (data.error) return true
  return list(data, "accounts").length === 0
}

function statusLine(data, loading) {
  if (loading) return "Loading…"
  if (!data) return "Idle"
  if (data.error) return data.error
  if (data.paused) return "Paused"
  if (isSyncing(data, loading)) return "Syncing"
  if (data.status) return data.status
  return "Idle"
}

function statusLineColor(data, loading, accent, urgent, foreground) {
  if (loading) return foreground
  if (data && (data.error || hasWarning(data))) return urgent
  if (isSyncing(data, loading)) return accent
  return foreground
}

function iconActive(data, loading) {
  return isSyncing(data, loading)
}

function barTooltip(data, loading) {
  var line = statusLine(data, loading)
  if (line && line !== "Idle") return plain(line)
  var n = list(data, "accounts").length
  if (n > 0) return n + " account" + (n === 1 ? "" : "s")
  return "Insync"
}

function accountSummary(data) {
  var n = list(data, "accounts").length
  if (n === 0) return ""
  return n + " account" + (n === 1 ? "" : "s")
}

function heroMeta(data, loading) {
  var status = statusLine(data, loading)
  var summary = accountSummary(data)
  if (summary && status && status !== summary)
    return status + " · " + summary
  return status || summary || "Idle"
}
