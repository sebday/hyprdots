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

function fileUrl(path) {
  var value = String(path || "").trim()
  if (!value) return ""
  if (value.indexOf("file://") === 0) return value
  if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value)) return value
  var parts = value.split("/")
  var encoded = []
  for (var i = 0; i < parts.length; i++) {
    if (parts[i] === "" && i === 0) encoded.push("")
    else if (parts[i] !== "") encoded.push(encodeURIComponent(parts[i]))
  }
  return "file://" + encoded.join("/")
}

function isEvoplayer(player) {
  if (!player) return false
  var identity = String(player.identity || "").toLowerCase()
  if (identity === "evoplayer") return true
  var desktopEntry = String(player.desktopEntry || "").toLowerCase()
  if (desktopEntry === "evoplayer") return true
  var dbusName = String(player.dbusName || "").toLowerCase()
  return dbusName.indexOf("evoplayer") !== -1
}

function playbackLabel(player) {
  if (!player) return ""
  if (player.isPlaying) return "Playing"
  if (String(player.trackTitle || "").trim() !== "") return "Paused"
  return "Stopped"
}

function heroMeta(artist, album, identity) {
  var parts = []
  var artistText = String(artist || "").trim()
  var albumText = String(album || "").trim()
  var identityText = String(identity || "").trim()
  if (artistText) parts.push(artistText)
  if (albumText) parts.push(albumText)
  if (parts.length === 0 && identityText) parts.push(identityText)
  return parts.join(" · ")
}

function safeArtUrl(url) {
  var value = String(url || "").trim()
  if (value.indexOf("file://") !== 0) return ""
  if (value.indexOf("..") >= 0) return ""
  return value
}

function historyArtUrl(fileName, artDir) {
  var name = String(fileName || "")
  var dir = String(artDir || "")
  if (!name || !dir) return ""
  if (name.length > 240 || dir.length > 512) return ""
  if (name.indexOf("/") >= 0 || name.indexOf("\\") >= 0 || name.indexOf("..") >= 0) return ""
  if (name.charAt(0) === "." || name.slice(-4) !== ".jpg") return ""
  if (dir.charAt(0) !== "/" || dir.slice(-14) !== "/evoplayer/art") return ""
  if (dir.indexOf("..") >= 0 || dir.indexOf("\n") >= 0 || dir.indexOf("\r") >= 0) return ""
  for (var i = 0; i < name.length - 4; i++) {
    var code = name.charCodeAt(i)
    if (code < 32 || code === 127) return ""
  }
  return safeArtUrl(fileUrl(dir + "/" + name))
}

function barTooltip(playing, title, muted) {
  var label = "Media"
  if (playing && title) label = plain(title)
  else if (playing) label = "Now playing"
  if (muted) return label === "Media" ? "Muted" : label + " \u00b7 Muted"
  return label
}

function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function isHeadphones(node) {
  if (!node) return false
  var p = nodeProps(node)
  var blob = String([
    node.name, node.description, node.nickname,
    p["device.icon-name"] || "",
    p["device.product.name"] || "",
    p["node.description"] || "",
    p["node.nick"] || ""
  ].join(" ")).toLowerCase()
  return blob.indexOf("headphone") !== -1
    || blob.indexOf("headset") !== -1
    || blob.indexOf("earbud") !== -1
    || blob.indexOf("earphone") !== -1
    || blob.indexOf("airpod") !== -1
}

function outputIcon(sink, volume, muted) {
  if (!sink || !sink.audio) return ""
  if (isHeadphones(sink)) return "󰋋"
  if (muted) return ""
  var v = Number(volume) || 0
  if (v >= 0.67) return ""
  if (v >= 0.34) return ""
  if (v > 0) return ""
  return ""
}

function iconActive(playing) {
  return playing === true
}
