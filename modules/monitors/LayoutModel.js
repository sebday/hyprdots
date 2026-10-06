// Which outputs carry the bar and the notification popups, and on which edge.
// Panel.qml, MonitorLayoutPicker.qml and Service.qml all read
// placements through here.

function normalizeBarEdge(edge) {
  var value = String(edge || "top").toLowerCase()
  if (value === "bottom" || value === "left" || value === "right") return value
  return "top"
}

function normalizeVertical(position) {
  return String(position || "top") === "bottom" ? "bottom" : "top"
}

function normalizeAlign(align) {
  var value = String(align || "right").toLowerCase()
  if (value === "left") return "left"
  if (value === "center" || value === "middle" || value === "centre") return "center"
  return "right"
}

function screenNames(screens) {
  var out = []
  if (!screens) return out
  for (var i = 0; i < screens.length; i++) {
    if (screens[i] && screens[i].name)
      out.push(String(screens[i].name))
  }
  return out
}

function findPlacement(placements, output) {
  var name = String(output || "")
  var list = placements || []
  for (var i = 0; i < list.length; i++) {
    var p = list[i]
    if (p && String(p.output) === name)
      return p
  }
  return null
}

// One entry per output; a later entry for the same output wins.
function dedupeByOutput(placements) {
  var seen = {}
  var out = []
  for (var i = placements.length - 1; i >= 0; i--) {
    var p = placements[i]
    if (!p) continue
    var name = String(p.output || "")
    if (!name || seen[name]) continue
    seen[name] = true
    out.unshift(p)
  }
  return out
}

function mapPlacements(list, normalize) {
  var out = []
  if (!Array.isArray(list)) return out
  for (var i = 0; i < list.length; i++) {
    var entry = list[i]
    if (!entry) continue
    var output = String(entry.output || "").trim()
    if (output) out.push(normalize(output, entry))
  }
  return dedupeByOutput(out)
}

function readBarPlacements(barConfig) {
  var cfg = barConfig || {}
  var mapped = mapPlacements(cfg.placements, function(output, entry) {
    return { output: output, position: normalizeBarEdge(entry.position) }
  })
  if (mapped.length > 0) return mapped
  var output = String(cfg.output || "").trim()
  if (!output) return []
  return [{ output: output, position: normalizeBarEdge(cfg.position) }]
}

// Plugins can only persist the bar subtree, so the notification placements
// live in bar.notificationPlacements. notifications.placements is read as a
// fallback for configs written before that.
function readNotificationPlacements(shellConfig) {
  var config = shellConfig || {}
  var bar = config.bar || {}
  var notes = config.notifications || {}
  var list = Array.isArray(bar.notificationPlacements)
    ? bar.notificationPlacements
    : notes.placements
  var mapped = mapPlacements(list, function(output, entry) {
    return {
      output: output,
      position: normalizeVertical(entry.position),
      align: normalizeAlign(entry.align)
    }
  })
  if (mapped.length > 0) return mapped
  var output = String(notes.output || bar.output || "").trim()
  if (!output) return []
  return [{
    output: output,
    position: normalizeVertical(notes.position || "top"),
    align: normalizeAlign(notes.align || "right")
  }]
}

// The connected screens named by the placements. An empty list stays empty:
// popups must not fan out onto every output when nothing was chosen.
function screensForPlacements(placements, screens) {
  var list = screens || []
  if (!Array.isArray(placements) || placements.length === 0)
    return []

  var out = []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && findPlacement(placements, list[i].name))
      out.push(list[i])
  }
  if (out.length === 0 && list.length > 0) out.push(list[0])
  return out
}

function hasBarEdge(placements, output, edge) {
  var entry = findPlacement(placements, output)
  if (!entry) return false
  return normalizeBarEdge(entry.position) === normalizeBarEdge(edge)
}

function hasNotificationAlign(placements, output, edge, align) {
  var entry = findPlacement(placements, output)
  if (!entry) return false
  return normalizeVertical(entry.position) === normalizeVertical(edge)
    && normalizeAlign(entry.align) === normalizeAlign(align)
}

// One bar. Clicking a monitor or one of its edges moves that bar; it does
// not leave a second bar behind on the previous output.
function toggleBarPlacementForOutput(placements, output, edge) {
  var name = String(output || "")
  var next = normalizeBarEdge(edge)
  if (!name) return placements || []
  return [{ output: name, position: next }]
}

// One notification screen. The clicked corner replaces every other output.
function toggleNotificationPlacement(placements, output, edge, align) {
  var name = String(output || "")
  if (!name) return placements || []
  return [{
    output: name,
    position: normalizeVertical(edge),
    align: normalizeAlign(align)
  }]
}

function writeBarPlacements(config, placements) {
  if (!config.bar || typeof config.bar !== "object") config.bar = {}
  var list = dedupeByOutput(placements)
  config.bar.placements = list
  if (!config.bar.id) config.bar.id = "evo.monitors"
  var chosen = list.length ? list[list.length - 1] : null
  if (!chosen) return
  // The live bar follows output and position. placements alone does not move it.
  config.bar.output = String(chosen.output)
  config.bar.position = normalizeBarEdge(chosen.position)
}

function writeNotificationPlacements(config, placements) {
  if (!config.bar || typeof config.bar !== "object") config.bar = {}
  if (!config.notifications || typeof config.notifications !== "object")
    config.notifications = {}
  var list = dedupeByOutput(placements)
  config.bar.notificationPlacements = list
  var chosen = list.length ? list[list.length - 1] : null
  if (!chosen) return
  config.notifications.output = String(chosen.output)
  config.notifications.position = normalizeVertical(chosen.position)
  config.notifications.align = normalizeAlign(chosen.align)
}

function applyBarPlacements(mutator, placements) {
  mutator(function(config) { writeBarPlacements(config, placements) })
}

function applyNotificationsPlacements(mutator, placements) {
  mutator(function(config) { writeNotificationPlacements(config, placements) })
}

function resetOmarchyLayout(mutator, screens) {
  var names = screenNames(screens)
  var layout = { barPlacements: [], notificationsPlacements: [] }
  for (var i = 0; i < names.length; i++) {
    layout.barPlacements.push({ output: names[i], position: "top" })
    layout.notificationsPlacements.push({ output: names[i], position: "top", align: "right" })
  }
  mutator(function(config) {
    writeBarPlacements(config, layout.barPlacements)
    writeNotificationPlacements(config, layout.notificationsPlacements)
  })
  return layout
}

// Where a screen's popup column sits. The bar's own edge gets the bar's
// clearance instead of the plain gap.
function popupPlacementForScreen(notificationPlacement, barEdge, barClearance, gapsOut) {
  var placement = notificationPlacement || {}
  var vertical = normalizeVertical(placement.position)
  var align = normalizeAlign(placement.align)
  var edge = barEdge ? normalizeBarEdge(barEdge) : ""
  var clearance = Number(barClearance)
  var gap = Number(gapsOut)
  if (!isFinite(clearance)) clearance = 0
  if (!isFinite(gap)) gap = 0

  var margins = { top: gap, bottom: gap, left: gap, right: gap }
  if (vertical === "top" && edge === "top") margins.top = clearance
  if (vertical === "bottom" && edge === "bottom") margins.bottom = clearance
  if (align === "right" && edge === "right") margins.right = clearance
  if (align === "left" && edge === "left") margins.left = clearance

  return { vertical: vertical, align: align, margins: margins }
}
