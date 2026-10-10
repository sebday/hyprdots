// location.json holds {"name": ..., "latitude": ..., "longitude": ...} (see
// bin/weather-location, which owns the format). Missing, blank, or
// unparseable means the location is auto-detected from the IP address.
function parseLocationFile(raw) {
  var unset = { name: "", latitude: null, longitude: null }
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return unset

    var latitude = parseFloat(data.latitude)
    var longitude = parseFloat(data.longitude)
    var hasCoordinates = !isNaN(latitude) && !isNaN(longitude)
    return {
      name: typeof data.name === "string" ? data.name.replace(/^\s+|\s+$/g, "") : "",
      latitude: hasCoordinates ? latitude : null,
      longitude: hasCoordinates ? longitude : null
    }
  } catch (e) {
    return unset
  }
}

// wttr.in path segment for a configured location: exact coordinates when
// both are present, the URL-encoded name as a fallback (hand-edited
// weather.loc files may only carry a name), empty for IP auto-detect.
function wttrLocationQuery(location, latitude, longitude) {
  var lat = parseFloat(String(latitude))
  var lon = parseFloat(String(longitude))
  if (!isNaN(lat) && !isNaN(lon)) return lat + "," + lon

  var name = String(location || "").replace(/^\s+|\s+$/g, "")
  return name === "" ? "" : encodeURIComponent(name)
}

// Open-Meteo geocoding response → suggestion rows for the location picker.
function parseGeocodingResults(raw) {
  try {
    var data = JSON.parse(String(raw || "{}"))
    var results = data.results
    if (!results || !results.length) return []

    var out = []
    for (var i = 0; i < results.length; i++) {
      var r = results[i]
      if (!r || !r.name || r.latitude === undefined || r.longitude === undefined) continue
      var region = [r.admin1, r.country].filter(function(part) { return !!part }).join(", ")
      out.push({
        name: String(r.name),
        description: region,
        latitude: r.latitude,
        longitude: r.longitude
      })
    }
    return out
  } catch (e) {
    return []
  }
}

function locationCommit(text, suggestions, selectedIndex) {
  var name = String(text || "").replace(/^\s+|\s+$/g, "")
  if (name === "") return { name: "", latitude: null, longitude: null }

  var choices = suggestions || []
  var index = Math.max(0, Math.min(parseInt(selectedIndex, 10) || 0, choices.length - 1))
  var suggestion = choices[index]
  if (suggestion) return suggestion

  return { name: name, latitude: null, longitude: null }
}

function isFutureForecastDate(dateString, todayString) {
  if (!dateString) return false
  return String(dateString).slice(0, 10) > String(todayString || "")
}

function roundedTemp(value) {
  if (value === undefined || value === null || value === "") return ""
  var n = parseFloat(String(value))
  return isNaN(n) ? "" : String(Math.round(n))
}

function celsiusToFahrenheit(value) {
  if (value === undefined || value === null || value === "") return ""
  var n = parseFloat(String(value))
  return isNaN(n) ? "" : (n * 9 / 5) + 32
}

function formatTemp(value, useImperial) {
  if (value === undefined || value === null || value === "") return ""
  return value + "°" + (useImperial ? "F" : "C")
}

function barTemp(tempNum, tempUnit) {
  var n = String(tempNum == null ? "" : tempNum).replace(/^\s+|\s+$/g, "")
  if (!n) return ""
  return plain(n + String(tempUnit || ""), 12)
}

function normalizedUnit(value) {
  return String(value || "").replace(/^\s+|\s+$/g, "").toLowerCase()
}

function localeUsesImperial(localeName) {
  var name = String(localeName || "").replace(".", "_")
  return /^en[_-]US($|[_.-])/.test(name) || /^en[_-]LR($|[_.-])/.test(name) || /^my($|[_.-])/.test(name)
}

function countryUsesImperial(countryName) {
  var country = String(countryName || "")
    .replace(/^\s+|\s+$/g, "")
    .replace(/[._-]+/g, " ")
    .toLowerCase()
  if (!country) return null
  if (country === "us" || country === "usa" || country === "united states" || country === "united states of america") return true
  if (country === "liberia" || country === "myanmar" || country === "burma") return true
  return false
}

function shouldUseImperial(unitOverride, localeName, countryName) {
  var unit = normalizedUnit(unitOverride)
  if (unit === "imperial") return true
  if (unit === "metric") return false

  var countryPreference = countryUsesImperial(countryName)
  if (countryPreference !== null) return countryPreference

  return localeUsesImperial(localeName)
}

function dayName(dateString, formatter) {
  if (!dateString) return ""
  var d = new Date(dateString + "T12:00:00")
  if (isNaN(d.getTime())) return ""
  if (formatter) return formatter(d)
  return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][d.getDay()]
}

function openMeteoForecastDays(dailyForecastReport, todayString) {
  var daily = dailyForecastReport && dailyForecastReport.daily ? dailyForecastReport.daily : null
  if (!daily || !daily.time) return []

  var result = []
  for (var i = 0; i < daily.time.length && result.length < 3; ++i) {
    var date = daily.time[i]
    if (!isFutureForecastDate(date, todayString)) continue

    var maxC = daily.temperature_2m_max ? daily.temperature_2m_max[i] : ""
    var minC = daily.temperature_2m_min ? daily.temperature_2m_min[i] : ""
    result.push({
      date: date,
      maxtempC: roundedTemp(maxC),
      mintempC: roundedTemp(minC),
      maxtempF: roundedTemp(celsiusToFahrenheit(maxC)),
      mintempF: roundedTemp(celsiusToFahrenheit(minC)),
      openMeteoWeatherCode: daily.weather_code ? daily.weather_code[i] : null
    })
  }
  return result
}

// Open-Meteo bundles current conditions with the daily forecast request and
// answers far faster than wttr.in. Normalize them to wttr's
// current_condition shape so the panel can use either source
// interchangeably. Open-Meteo reports metric (°C, km/h).
function openMeteoCurrentCondition(dailyForecastReport) {
  var current = dailyForecastReport && dailyForecastReport.current ? dailyForecastReport.current : null
  if (!current || current.temperature_2m === undefined || current.temperature_2m === null) return null
  return {
    temp_C: roundedTemp(current.temperature_2m),
    temp_F: roundedTemp(celsiusToFahrenheit(current.temperature_2m)),
    FeelsLikeC: roundedTemp(current.apparent_temperature),
    FeelsLikeF: roundedTemp(celsiusToFahrenheit(current.apparent_temperature)),
    windspeedKmph: roundedTemp(current.wind_speed_10m),
    windspeedMiles: roundedTemp(current.wind_speed_10m * 0.621371),
    humidity: roundedTemp(current.relative_humidity_2m),
    openMeteoWeatherCode: current.weather_code,
    isDay: current.is_day
  }
}

function currentIcon(current, fallback) {
  if (!current) return fallback || ""
  if (current.openMeteoWeatherCode !== undefined && current.openMeteoWeatherCode !== null)
    return iconForOpenMeteoCode(current.openMeteoWeatherCode, Number(current.isDay) === 0)
  if (current.weatherCode !== undefined && current.weatherCode !== null)
    return iconForCode(current.weatherCode, false)
  return fallback || ""
}

// wttr.in has no day/night flag. Use its icon only to fill an empty initial
// state, never to replace a day/night-aware icon resolved by Open-Meteo.
function provisionalCurrentIcon(current, resolvedIcon) {
  return resolvedIcon || currentIcon(current, "")
}

function weatherResponseCompletesSave(hasConfiguredCoordinates, source) {
  return hasConfiguredCoordinates ? source === "open-meteo" : source === "wttr"
}

function wttrNextForecastDays(report, todayString) {
  var days = report && report.weather ? report.weather : []
  var result = []
  for (var i = 0; i < days.length && result.length < 3; ++i) {
    if (isFutureForecastDate(days[i].date, todayString)) result.push(days[i])
  }
  return result
}

function buildForecastDays(report, dailyForecastReport, todayString) {
  var days = openMeteoForecastDays(dailyForecastReport, todayString)
  return days.length > 0 ? days : wttrNextForecastDays(report, todayString)
}

function bareTempForDay(day, kind, useImperial) {
  if (!day) return ""
  var v = useImperial
    ? (kind === "max" ? day.maxtempF : day.mintempF)
    : (kind === "max" ? day.maxtempC : day.mintempC)
  if (v === undefined || v === null || v === "") return ""
  return v + "°"
}

function dayIcon(day) {
  if (!day) return ""
  if (day.openMeteoWeatherCode !== undefined && day.openMeteoWeatherCode !== null)
    return iconForOpenMeteoCode(day.openMeteoWeatherCode)
  if (!day.hourly || day.hourly.length === 0) return ""

  var best = day.hourly[0]
  var bestDist = 9999
  for (var i = 0; i < day.hourly.length; ++i) {
    var t = parseInt(String(day.hourly[i].time || "0"), 10)
    var dist = Math.abs(t - 1200)
    if (dist < bestDist) {
      bestDist = dist
      best = day.hourly[i]
    }
  }
  return iconForCode(best.weatherCode, false)
}

function iconForOpenMeteoCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  if (c === 0) return iconForCode(113, night)
  if (c === 1 || c === 2) return iconForCode(116, night)
  if (c === 3) return iconForCode(119, night)
  if (c === 45 || c === 48) return iconForCode(143, night)
  if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57 || c === 61) return iconForCode(266, night)
  if (c === 63 || c === 65 || c === 66 || c === 67 || c === 80 || c === 81 || c === 82) return iconForCode(308, night)
  if (c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86) return iconForCode(338, night)
  if (c === 95 || c === 96 || c === 99) return iconForCode(389, night)
  return iconForCode(119, night)
}

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

function expandSparseCells(grid, sparse) {
  var n = grid * grid
  var out = []
  var i
  for (i = 0; i < n; i++)
    out.push({ r: 0, g: 0, b: 0, a: 0 })
  if (!(sparse instanceof Array)) return out
  var max = Math.min(sparse.length, n)
  for (i = 0; i < max; i++) {
    var cell = sparse[i]
    if (!(cell instanceof Array) || cell.length < 5) continue
    var idx = parseInt(cell[0], 10)
    if (!(idx >= 0 && idx < n)) continue
    var r = parseInt(cell[1], 10) || 0
    var g = parseInt(cell[2], 10) || 0
    var b = parseInt(cell[3], 10) || 0
    var a = parseInt(cell[4], 10) || 0
    if (r < 0 || r > 255) r = 0
    if (g < 0 || g > 255) g = 0
    if (b < 0 || b > 255) b = 0
    if (a < 0 || a > 255) a = 0
    out[idx] = { r: r, g: g, b: b, a: a }
  }
  return out
}

function parseRadarHistory(raw) {
  var empty = { ok: false, error: "No radar", frames: [] }
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return empty
    var grid = parseInt(data.grid, 10)
    if (grid < 16 || grid > 64) return empty
    var list = data.frames
    if (!(list instanceof Array) || list.length < 2 || list.length > 16)
      return empty
    var frames = []
    for (var i = 0; i < list.length; i++) {
      var frame = list[i]
      if (!frame || typeof frame !== "object") continue
      var stamp = parseInt(frame.time, 10)
      if (!stamp) continue
      frames.push({ time: stamp, cells: expandSparseCells(grid, frame.cells) })
    }
    if (frames.length < 2) return empty
    var lat = parseFloat(data.lat)
    var lon = parseFloat(data.lon)
    var zoom = parseInt(data.zoom, 10)
    return {
      ok: data.ok === true,
      error: typeof data.error === "string" ? data.error.slice(0, 80) : "",
      grid: grid,
      zoom: zoom >= 3 && zoom <= 8 ? zoom : 7,
      lat: isNaN(lat) ? 0 : lat,
      lon: isNaN(lon) ? 0 : lon,
      frames: frames
    }
  } catch (e) {
    return empty
  }
}

function parseRadarPayload(raw) {
  var empty = { ok: false, error: "No radar", time: 0, grid: 64, zoom: 7, lat: 0, lon: 0, cells: [] }
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return empty
    var grid = parseInt(data.grid, 10)
    if (grid < 16 || grid > 64) return empty
    var cells = data.cells
    if (!(cells instanceof Array) || cells.length !== grid * grid) return empty
    var out = []
    for (var i = 0; i < cells.length; i++) {
      var cell = cells[i]
      if (!(cell instanceof Array) || cell.length < 4) {
        out.push({ r: 0, g: 0, b: 0, a: 0 })
        continue
      }
      var r = parseInt(cell[0], 10) || 0
      var g = parseInt(cell[1], 10) || 0
      var b = parseInt(cell[2], 10) || 0
      var a = parseInt(cell[3], 10) || 0
      if (r < 0 || r > 255) r = 0
      if (g < 0 || g > 255) g = 0
      if (b < 0 || b > 255) b = 0
      if (a < 0 || a > 255) a = 0
      out.push({ r: r, g: g, b: b, a: a })
    }
    var lat = parseFloat(data.lat)
    var lon = parseFloat(data.lon)
    var zoom = parseInt(data.zoom, 10)
    return {
      ok: data.ok === true,
      error: typeof data.error === "string" ? data.error.slice(0, 80) : "",
      time: parseInt(data.time, 10) || 0,
      grid: grid,
      zoom: zoom >= 3 && zoom <= 8 ? zoom : 7,
      lat: isNaN(lat) ? 0 : lat,
      lon: isNaN(lon) ? 0 : lon,
      cells: out
    }
  } catch (e) {
    return empty
  }
}

var RADAR_TOWNS = [
  { name: "Nottingham", lat: 52.9548, lon: -1.1505 },
  { name: "Leicester", lat: 52.6369, lon: -1.1398 },
  { name: "Birmingham", lat: 52.4862, lon: -1.8904 },
  { name: "Sheffield", lat: 53.3811, lon: -1.4701 }
]

function lonToTile(lon, zoom) {
  return ((lon + 180) / 360) * Math.pow(2, zoom)
}

function latToTile(lat, zoom) {
  var rad = (lat * Math.PI) / 180
  return ((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * Math.pow(2, zoom)
}

function radarProject(lat, lon, originLat, originLon, viewSize, zoom) {
  return {
    x: (lonToTile(lon, zoom) - lonToTile(originLon, zoom)) * viewSize + viewSize / 2,
    y: (latToTile(lat, zoom) - latToTile(originLat, zoom)) * viewSize + viewSize / 2
  }
}

function radarRingRadii(originLat, viewSize, zoom) {
  if (!viewSize || isNaN(originLat)) return []
  var tileMetres = (Math.cos((originLat * Math.PI) / 180) * 40075016.686) / Math.pow(2, zoom)
  var mpp = tileMetres / viewSize
  if (!(mpp > 0)) return []
  var kms = [25, 50, 100]
  var out = []
  for (var i = 0; i < kms.length; i++)
    out.push((kms[i] * 1000) / mpp)
  return out
}

function radarTowns(originLat, originLon, viewSize, zoom, homeName, homeLat, homeLon) {
  if (!viewSize || isNaN(originLat) || isNaN(originLon)) return []
  var pad = 20
  var seen = {}
  var list = RADAR_TOWNS.slice()
  if (homeName && !isNaN(homeLat) && !isNaN(homeLon))
    list = [{ name: String(homeName), lat: homeLat, lon: homeLon, home: true }].concat(list)

  var out = []
  for (var i = 0; i < list.length; i++) {
    var place = list[i]
    var label = plain(place.name, 24)
    if (!label) continue
    var key = label.toLowerCase()
    var pt = radarProject(place.lat, place.lon, originLat, originLon, viewSize, zoom)
    if (pt.x < pad || pt.x > viewSize - pad || pt.y < pad || pt.y > viewSize - pad)
      continue
    if (seen[key]) {
      if (place.home === true) {
        for (var j = 0; j < out.length; j++) {
          if (out[j].name.toLowerCase() === key) {
            out[j].home = true
            break
          }
        }
      }
      continue
    }
    seen[key] = true
    out.push({ name: label, x: pt.x, y: pt.y, home: place.home === true })
  }
  return out
}

function radarCoastPaths(rings, originLat, originLon, viewSize, zoom) {
  if (!rings || !viewSize || isNaN(originLat) || isNaN(originLon)) return []
  var margin = viewSize * 0.2
  var out = []
  for (var i = 0; i < rings.length; i++) {
    var ring = rings[i]
    if (!ring || ring.length < 3) continue
    var path = []
    var visible = false
    for (var j = 0; j < ring.length; j++) {
      var pt = radarProject(ring[j][0], ring[j][1], originLat, originLon, viewSize, zoom)
      path.push(pt)
      if (pt.x > -margin && pt.x < viewSize + margin && pt.y > -margin && pt.y < viewSize + margin)
        visible = true
    }
    if (visible)
      out.push(path)
  }
  return out
}

function radarHexByte(n) {
  var h = (parseInt(n, 10) || 0).toString(16)
  return h.length === 1 ? "0" + h : h
}

function radarCellColor(cell) {
  if (!cell || (cell.a || 0) <= 0)
    return "transparent"
  return "#" + radarHexByte(cell.a) + radarHexByte(cell.r) + radarHexByte(cell.g) + radarHexByte(cell.b)
}

function iconForCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  switch (c) {
    case 113: return night ? "" : ""
    case 116: return night ? "" : ""
    case 119: case 122: return ""
    case 143: case 248: case 260: return night ? "\ue346" : "\ue313"
    case 176: case 263: case 353: return night ? "" : ""
    case 179: case 227: case 230: case 323: case 326: case 368: return night ? "" : ""
    case 182: case 185: case 281: case 284: case 311: case 314:
    case 317: case 320: case 350: case 362: case 365: case 374: case 377: return ""
    case 200: case 386: case 389: case 392: case 395: return ""
    case 266: case 293: case 296: case 299: case 302: case 305: case 308: case 356: case 359: return ""
    case 329: case 332: case 335: case 338: case 371: return ""
    default: return ""
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseLocationFile: parseLocationFile,
    wttrLocationQuery: wttrLocationQuery,
    parseGeocodingResults: parseGeocodingResults,
    locationCommit: locationCommit,
    isFutureForecastDate: isFutureForecastDate,
    roundedTemp: roundedTemp,
    celsiusToFahrenheit: celsiusToFahrenheit,
    formatTemp: formatTemp,
    barTemp: barTemp,
    normalizedUnit: normalizedUnit,
    localeUsesImperial: localeUsesImperial,
    countryUsesImperial: countryUsesImperial,
    shouldUseImperial: shouldUseImperial,
    dayName: dayName,
    openMeteoForecastDays: openMeteoForecastDays,
    openMeteoCurrentCondition: openMeteoCurrentCondition,
    currentIcon: currentIcon,
    provisionalCurrentIcon: provisionalCurrentIcon,
    weatherResponseCompletesSave: weatherResponseCompletesSave,
    wttrNextForecastDays: wttrNextForecastDays,
    buildForecastDays: buildForecastDays,
    bareTempForDay: bareTempForDay,
    dayIcon: dayIcon,
    iconForOpenMeteoCode: iconForOpenMeteoCode,
    iconForCode: iconForCode,
    plain: plain,
    parseRadarPayload: parseRadarPayload,
    parseRadarHistory: parseRadarHistory,
    radarCellColor: radarCellColor,
    radarTowns: radarTowns,
    radarRingRadii: radarRingRadii,
    radarCoastPaths: radarCoastPaths
  }
}
