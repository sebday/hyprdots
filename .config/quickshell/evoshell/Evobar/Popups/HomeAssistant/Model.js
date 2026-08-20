// Formatting helpers for Home Assistant popup rows.

function formatTemperature(value, unit) {
    var n = parseFloat(value)
    if (isNaN(n))
        return "—"
    var u = String(unit || "°C")
    return n.toFixed(1) + u
}

function relativeTime(whenMs, nowMs) {
    var when = Number(whenMs) || 0
    var now = Number(nowMs) || Date.now()
    if (when <= 0)
        return ""
    var delta = Math.max(0, Math.round((now - when) / 1000))
    if (delta < 5)
        return "just now"
    if (delta < 60)
        return delta + "s ago"
    if (delta < 3600)
        return Math.round(delta / 60) + "m ago"
    return Math.round(delta / 3600) + "h ago"
}

function barSummary(data) {
    if (!data || data.ok !== true)
        return ""
    var summary = data.summary || {}
    if (summary.temperature !== undefined && summary.temperature !== null)
        return formatTemperature(summary.temperature, summary.temperatureUnit)
    if (summary.lightsOn > 0)
        return String(summary.lightsOn) + " on"
    if (summary.camerasOnline > 0)
        return String(summary.camerasOnline) + " cam"
    return "ok"
}

function groupLightsByArea(lights) {
    if (!Array.isArray(lights) || lights.length === 0)
        return []
    var map = {}
    var areas = []
    for (var i = 0; i < lights.length; i++) {
        var light = lights[i]
        var area = String(light.area || "").trim()
        if (!area)
            area = String(light.name || light.entityId || "Other")
        if (!map[area]) {
            map[area] = []
            areas.push(area)
        }
        map[area].push(light)
    }
    areas.sort(function(a, b) {
        return a.localeCompare(b, undefined, { sensitivity: "base" })
    })
    return areas.map(function(area) {
        return { area: area, lights: map[area] }
    })
}

function distributeIntoColumns(items, columnCount) {
    if (!Array.isArray(items) || columnCount < 1)
        return []
    var columns = []
    for (var i = 0; i < columnCount; i++)
        columns.push([])
    for (var j = 0; j < items.length; j++)
        columns[j % columnCount].push(items[j])
    return columns
}
