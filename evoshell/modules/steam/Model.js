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
    running: false,
    installedCount: 0,
    ownedCount: 0,
    totalPlaytimeMin: 0,
    playedGames: [],
    runningGames: []
  }
}

function parsePayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return emptyData()

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return emptyData("Invalid response")
  }

  if (json.ok !== true) {
    return {
      ok: false,
      error: String(json.error || "Steam unavailable"),
      running: false,
      installedCount: 0,
      ownedCount: 0,
      totalPlaytimeMin: 0,
      playedGames: [],
      runningGames: []
    }
  }

  return {
    ok: true,
    error: String(json.error || ""),
    running: json.running === true,
    installedCount: parseInt(json.installed_count !== undefined
      ? json.installed_count : json.library_count, 10) || 0,
    ownedCount: parseInt(json.owned_count !== undefined
      ? json.owned_count : json.library_total, 10) || 0,
    totalPlaytimeMin: parseInt(json.total_playtime_min, 10) || 0,
    playedGames: filterKnownGames(json.played_games),
    runningGames: filterKnownGames(json.running_games)
  }
}

function isKnownGame(game) {
  if (!game || typeof game !== "object") return false
  var appid = String(game.appid || "").trim()
  var name = String(game.name || "").trim()
  if (!appid.length || !name.length || name === "App " + appid) return false
  var lower = name.toLowerCase()
  if (lower.indexOf("proton") >= 0) return false
  if (lower.indexOf("steamworks") >= 0) return false
  if (lower.indexOf("steam linux runtime") >= 0) return false
  if (lower.indexOf("redistributable") >= 0) return false
  return true
}

function filterKnownGames(games) {
  var out = []
  if (!Array.isArray(games)) return out
  for (var i = 0; i < games.length; i++) {
    if (isKnownGame(games[i])) out.push(games[i])
  }
  return out
}

function formatPlaytime(minutes) {
  var m = Number(minutes) || 0
  if (m <= 0) return ""
  var hours = Math.round(m / 60)
  if (hours <= 0) return ""
  return String(hours) + "h"
}

function formatLastPlayed(ts) {
  var n = parseInt(ts, 10) || 0
  if (n <= 0) return "—"
  var now = Math.floor(Date.now() / 1000)
  var diff = now - n
  if (diff < 3600) return Math.max(1, Math.floor(diff / 60)) + "m ago"
  if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
  if (diff < 86400 * 7) return Math.floor(diff / 86400) + "d ago"
  var d = new Date(n * 1000)
  return d.getDate() + "/" + (d.getMonth() + 1)
}

function formatTotalPlayed(totalPlaytimeMin, loading) {
  if (loading) return "…"
  var hours = Math.round(Number(totalPlaytimeMin) / 60)
  if (hours <= 0) return "—"
  return String(hours) + "h"
}

function statusPillText(data, loading) {
  if (loading) return "Loading…"
  if (!data || !data.ok) return data && data.error ? data.error : ""
  if (!data.running) return "Not running"
  if (data.runningGames.length > 0)
    return "Playing · " + String(data.runningGames[0].name || "")
  return ""
}

function statusPillColor(data, loading, accent, urgent, foreground) {
  if (loading) return foreground
  if (!data || !data.ok) return urgent
  if (data.running && data.runningGames.length > 0) return accent
  return foreground
}

function iconActive(data) {
  if (!data || !data.ok) return false
  return data.runningGames.length > 0
}

function barTooltip(data) {
  if (!data || !data.ok) return "Steam"
  if (data.runningGames.length > 0)
    return plain(data.runningGames[0].name || "Playing")
  if (data.running)
    return data.ownedCount + " game" + (data.ownedCount === 1 ? "" : "s")
  return "Steam not running"
}

function gameArtUrl(path) {
  var p = String(path || "").trim()
  if (!p) return ""
  if (/^https?:/i.test(p) || p.indexOf("data:") === 0) return ""
  if (p.indexOf("file://") === 0) {
    if (p.indexOf("..") >= 0) return ""
    return p
  }
  if (p.indexOf("..") >= 0) return ""
  return "file://" + p
}
