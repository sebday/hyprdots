import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons
import qs.ui
import "Model.js" as Model
import "UkCoast.js" as Coast

Panel {
  id: root
  moduleName: "evo.weather"
  ipcTarget: "evo.weather"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against `slot.activeItem`, and switchPanelFrom looks the
  // slot up the same way.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Theme.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Theme.font.family

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    locationFile.reload()
    root.refresh()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    locationFile.reload()
    root.refresh()
    // Set after showing, not before: showing hands the popout coordinator
    // over, which closes whichever panel was open, and that close clears the
    // shared flag. Deferring means the panel taking over always wins, while
    // a handoff to a panel that does not manage the flag still leaves it
    // cleared rather than stuck on.
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    root.radarFrameIndex = -1
    setCenterHoverRevealSuppressed(false)
    if (root.editingLocation) root.cancelEditingLocation()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // Parsed wttr.in j1 response. Kept on failure so stale data stays visible.
  property var report: null
  property var dailyForecastReport: null
  property string wttrLocation: ""

  // Configured location, read from $EVOSHELL_STATE/weather/location.json
  // (owned by bin/weather-location). The query is the wttr.in path segment
  // (coordinates when stored, else the encoded name); empty means IP
  // auto-detect. The watch makes hand edits take effect live.
  property var configuredLocationState: ({ name: "", latitude: null, longitude: null })
  readonly property string configuredLocation: configuredLocationState.name
  readonly property string locationQuery: Model.wttrLocationQuery(configuredLocationState.name, configuredLocationState.latitude, configuredLocationState.longitude)

  // Keep the previous report visible while the new location loads. The
  // editor remains open with a spinner, so stale data is never presented
  // under the newly configured location label.
  onLocationQueryChanged: {
    if (savingLocation) savingLocationQueryStarted = true
    forecastRetries = 0
    dailyForecastRetries = 0
    forecastProc.running = false
    dailyForecastProc.running = false
    Qt.callLater(refresh)
  }

  property FileView locationFile: FileView {
    path: Util.statePath(Quickshell.env("HOME"), "weather/location.json")
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.configuredLocationState = Model.parseLocationFile(text())
    onLoadFailed: root.configuredLocationState = Model.parseLocationFile("")
  }

  // The first read can race shell startup (observed sporadically), leaving a
  // stored location unhonored until the next file write. One delayed reload
  // self-corrects; if the first read was fine it's a no-op, since identical
  // state doesn't change locationQuery and so triggers no refetch.
  Timer {
    interval: 1500
    running: true
    onTriggered: locationFile.reload()
  }

  property int forecastRetries: 0
  property int dailyForecastRetries: 0

  // Click-to-edit state for the location label.
  property bool editingLocation: false
  property bool savingLocation: false
  property bool savingLocationQueryStarted: false
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string geocodePendingQuery: ""
  property string geocodeActiveQuery: ""

  // Shared hero/bar icon state, updated with each successful weather response.
  property string label: ""

  // wttr's current conditions when available; open-meteo's (bundled with the
  // much faster daily forecast fetch) fill the hero while wttr is in flight.
  readonly property bool hasConfiguredCoordinates: !isNaN(parseFloat(String(configuredLocationState.latitude))) && !isNaN(parseFloat(String(configuredLocationState.longitude)))
  readonly property var openMeteoCurrent: Model.openMeteoCurrentCondition(dailyForecastReport)
  readonly property var current: (hasConfiguredCoordinates && openMeteoCurrent) ? openMeteoCurrent : ((report && report.current_condition && report.current_condition[0]) ? report.current_condition[0] : openMeteoCurrent)
  readonly property var areaInfo: report && report.nearest_area && report.nearest_area[0] ? report.nearest_area[0] : null
  readonly property var forecastDays: buildForecastDays()
  readonly property string reportCountry: areaInfo && areaInfo.country && areaInfo.country[0] ? areaInfo.country[0].value : ""

  readonly property bool useImperial: Model.shouldUseImperial(setting("unit", ""), Qt.locale().name, reportCountry)

  // Auto-refresh interval in minutes; clamped to a sane minimum.
  readonly property int refreshMinutes: Math.max(1, parseInt(setting("refreshMinutes", 15), 10) || 15)
  readonly property string radarScript: Util.localPath(Qt.resolvedUrl("bin/weather-radar"))
  readonly property string locationScript: Util.localPath(Qt.resolvedUrl("bin/weather-location"))
  property var radarData: ({ ok: false, error: "", time: 0, grid: 64, zoom: 7, lat: 0, lon: 0, cells: [] })
  property var radarFrames: []
  property int radarFrameIndex: -1
  property int radarStepPending: 0
  property bool radarLoading: false
  property bool radarHistoryLoading: false
  readonly property bool radarCanBack: !root.radarHistoryLoading && root.radarFrameIndex > 0
  readonly property bool radarCanForward: !root.radarHistoryLoading && root.radarData && root.radarData.ok === true && (root.radarFrames.length < 2 || root.radarFrameIndex < root.radarFrames.length - 1)
  readonly property var radarCells: {
    var frames = root.radarFrames
    var i = root.radarFrameIndex
    if (frames && i >= 0 && i < frames.length && frames[i] && frames[i].cells)
      return frames[i].cells
    return (radarData && radarData.cells instanceof Array) ? radarData.cells : []
  }
  readonly property int radarViewTime: {
    var frames = root.radarFrames
    var i = root.radarFrameIndex
    if (frames && i >= 0 && i < frames.length && frames[i])
      return parseInt(frames[i].time, 10) || 0
    return (root.radarData && root.radarData.time) ? root.radarData.time : 0
  }
  readonly property int radarGrid: (radarData && radarData.grid) ? radarData.grid : 64
  readonly property int radarZoom: (radarData && radarData.zoom) ? radarData.zoom : 7
  readonly property bool iconError: !root.current && root.label === ""
  readonly property bool iconBusy: forecastProc.running || dailyForecastProc.running || radarProc.running || radarHistoryProc.running
  readonly property string barTooltip: {
    if (root.reportLocation && root.reportTempNum)
      return root.reportLocation + " " + root.reportTempNum + root.tempUnit
    return "Weather"
  }
  readonly property string barValue: Model.barTemp(root.reportTempNum, root.tempUnit)
  readonly property string radarStatus: {
    if (root.radarLoading && root.radarCells.length === 0)
      return "RADAR…"
    if (!root.radarData || root.radarData.ok !== true)
      return Model.plain(root.radarData && root.radarData.error ? root.radarData.error : "")
    var t = root.radarViewTime
    var nowSec = Date.now() / 1000
    var delta = t ? Math.round((t - nowSec) / 60) : 0
    var stamp = t ? Qt.formatTime(new Date(t * 1000), "HH:mm") : ""
    if (delta > 0)
      return stamp + "  +" + delta + "m"
    var age = Math.max(0, -delta)
    return (age <= 20 ? "LIVE" : "STALE") + "  " + stamp + "  " + age + "m"
  }

  readonly property string reportLocation:  configuredLocation || wttrLocation || (areaInfo && areaInfo.areaName && areaInfo.areaName[0] ? areaInfo.areaName[0].value : "")
  readonly property string reportTempNum:   current ? String(useImperial ? current.temp_F : current.temp_C) : ""
  readonly property string tempUnit:        "°" + (useImperial ? "F" : "C")
  readonly property string reportFeels:     current ? formatTemp(useImperial ? current.FeelsLikeF : current.FeelsLikeC) : ""
  readonly property string reportWind:      current ? (useImperial ? (current.windspeedMiles + " mph") : (current.windspeedKmph + " km/h")) : ""
  readonly property string reportHumidity:  current ? (current.humidity + "%") : ""

  function refresh() {
    // Each full refresh cycle gets a fresh retry budget, so an earlier
    // exhausted round (e.g. waking with the network still down) doesn't
    // starve retries for the rest of the session.
    forecastRetries = 0
    dailyForecastRetries = 0
    if (!forecastProc.running) forecastProc.running = true
    if (root.locationQuery === "" && !locationProc.running) locationProc.running = true
    // With stored coordinates this fetches open-meteo right away — no need
    // to wait for the slow wttr response. Without them it's a no-op until
    // wttr reports the detected area.
    refreshDailyForecast(null)
    if (root.opened)
      root.refreshRadar()
  }

  function radarLatLon() {
    var lat = parseFloat(String(root.configuredLocationState.latitude))
    var lon = parseFloat(String(root.configuredLocationState.longitude))
    if (isNaN(lat) || isNaN(lon)) {
      var area = root.areaInfo
      if (!area) return null
      lat = parseFloat(String(area.latitude || ""))
      lon = parseFloat(String(area.longitude || ""))
    }
    if (isNaN(lat) || isNaN(lon)) return null
    return { lat: lat, lon: lon }
  }

  function refreshRadar() {
    var coords = root.radarLatLon()
    if (!coords || !root.radarScript || radarProc.running) return
    root.radarLoading = true
    radarProc.command = ["/usr/bin/python3", "-I", root.radarScript, String(coords.lat), String(coords.lon)]
    radarProc.running = true
  }

  function clearRadarFrames() {
    root.radarStepPending = 0
    root.radarFrames = []
    root.radarFrameIndex = -1
  }

  // Frame 0 is the latest observation, which the live image already shows.
  // Forward from live lands on the next frame. Back from the first future
  // frame returns to the live image.
  function applyRadarStep(delta) {
    var n = root.radarFrames.length
    if (n < 2) return
    var i = root.radarFrameIndex
    if (delta > 0) {
      var next = (i < 0 ? 0 : i) + 1
      if (next >= n) next = n - 1
      root.radarFrameIndex = next
      return
    }
    var prev = i - 1
    if (prev <= 0) prev = -1
    root.radarFrameIndex = prev
  }

  function stepRadar(delta) {
    if (delta !== 1 && delta !== -1) return
    if (root.radarHistoryLoading || radarHistoryProc.running) return
    if (delta < 0 && !root.radarCanBack) return
    if (delta > 0 && !root.radarCanForward) return
    if (root.radarFrames.length >= 2) {
      root.applyRadarStep(delta)
      return
    }
    root.radarStepPending = delta
    root.loadRadarHistory()
    if (!root.radarHistoryLoading) root.radarStepPending = 0
  }

  function loadRadarHistory() {
    var coords = root.radarLatLon()
    if (!coords || !root.radarScript || radarHistoryProc.running) return
    root.radarHistoryLoading = true
    radarHistoryProc.command = ["/usr/bin/python3", "-I", root.radarScript, String(coords.lat), String(coords.lon), "play"]
    radarHistoryProc.running = true
  }

  function refreshDailyForecast(sourceReport) {
    if (dailyForecastProc.running) return

    var lat = parseFloat(String(root.configuredLocationState.latitude))
    var lon = parseFloat(String(root.configuredLocationState.longitude))
    if (isNaN(lat) || isNaN(lon)) {
      var area = sourceReport && sourceReport.nearest_area && sourceReport.nearest_area[0] ? sourceReport.nearest_area[0] : root.areaInfo
      if (!area) return
      lat = parseFloat(String(area.latitude || ""))
      lon = parseFloat(String(area.longitude || ""))
    }
    if (isNaN(lat) || isNaN(lon)) return

    var url = "https://api.open-meteo.com/v1/forecast"
      + "?latitude=" + encodeURIComponent(String(lat))
      + "&longitude=" + encodeURIComponent(String(lon))
      + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
      + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
      + "&forecast_days=4"
      + "&timezone=auto"
    dailyForecastProc.command = ["curl", "-fsS", "--max-time", "5", url]
    dailyForecastProc.running = true
  }

  // ---- Location editing. Clicking the location label swaps it for a search
  //      field; picking a geocoded suggestion persists name + coordinates
  //      through bin/weather-location. An empty commit returns to auto.
  function startEditingLocation() {
    editingLocation = true
    savingLocation = false
    savingLocationQueryStarted = false
    locationSuggestions = []
    suggestionIndex = 0
    Qt.callLater(function() {
      locationField.text = root.configuredLocation
      locationField.selectAll()
      locationField.forceActiveFocus()
    })
  }

  function cancelEditingLocation() {
    editingLocation = false
    savingLocation = false
    savingLocationQueryStarted = false
    locationSuggestions = []
    geocodeDebounce.stop()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function commitLocation() {
    var location = Model.locationCommit(locationField.text, locationSuggestions, suggestionIndex)
    if (location.name === "") {
      clearLocation()
      return
    }
    savingLocation = true
    savingLocationQueryStarted = false
    configuredLocationState = {
      name: location.name,
      latitude: location.latitude,
      longitude: location.longitude
    }
    persistLocation(location.name, location.latitude, location.longitude)
  }

  function clearLocation() {
    persistLocation("", null, null)
    wttrLocation = ""
    cancelEditingLocation()
  }

  function pickSuggestion(suggestion) {
    if (!suggestion) return
    savingLocation = true
    savingLocationQueryStarted = false
    configuredLocationState = {
      name: suggestion.name,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude
    }
    persistLocation(suggestion.name, suggestion.latitude, suggestion.longitude)
  }

  function finishSavingLocation() {
    if (savingLocation && savingLocationQueryStarted) cancelEditingLocation()
  }

  function persistLocation(name, latitude, longitude) {
    if (name && latitude !== null && longitude !== null)
      locationSaveProc.command = [root.locationScript, "--set", name, latitude + "," + longitude]
    else if (name)
      locationSaveProc.command = [root.locationScript, "--set", name]
    else
      locationSaveProc.command = [root.locationScript, "--clear"]
    locationSaveProc.running = true
  }

  // Debounced geocoding. Only one curl runs at a time; if the query moved on
  // while a fetch was in flight, the latest query is fetched right after.
  function requestGeocode() {
    var query = locationField.text.trim()
    if (query.length < 2) {
      locationSuggestions = []
      return
    }
    geocodePendingQuery = query
    if (!geocodeProc.running) startGeocode()
  }

  function startGeocode() {
    geocodeActiveQuery = geocodePendingQuery
    geocodeProc.command = ["curl", "-fsS", "--max-time", "5",
      "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(geocodeActiveQuery) + "&count=5&language=en&format=json"]
    geocodeProc.running = true
  }

  function buildForecastDays() {
    return Model.buildForecastDays(report, dailyForecastReport, Qt.formatDate(new Date(), "yyyy-MM-dd"))
  }

  function openMeteoForecastDays() {
    return Model.openMeteoForecastDays(dailyForecastReport, Qt.formatDate(new Date(), "yyyy-MM-dd"))
  }

  function wttrNextForecastDays() {
    return Model.wttrNextForecastDays(report, Qt.formatDate(new Date(), "yyyy-MM-dd"))
  }

  function isFutureForecastDate(dateString) {
    return Model.isFutureForecastDate(dateString, Qt.formatDate(new Date(), "yyyy-MM-dd"))
  }

  function roundedTemp(value) {
    return Model.roundedTemp(value)
  }

  function celsiusToFahrenheit(value) {
    return Model.celsiusToFahrenheit(value)
  }

  function formatTemp(value) {
    return Model.formatTemp(value, useImperial)
  }

  function dayName(dateString) {
    return Model.dayName(dateString, function(date) { return Qt.formatDate(date, "dddd") })
  }

  // Bare degree value (no unit letter), used in the forecast row.
  function bareTempForDay(day, kind) {
    return Model.bareTempForDay(day, kind, useImperial)
  }

  // Representative icon for a forecast day: the hourly entry nearest noon.
  function dayIcon(day) {
    return Model.dayIcon(day)
  }

  function iconForOpenMeteoCode(code) {
    return Model.iconForOpenMeteoCode(code)
  }

  // wttr.in weather code → nerd-font glyph mapping.
  function iconForCode(code, night) {
    return Model.iconForCode(code, night)
  }

  Process {
    id: forecastProc
    command: ["curl", "-fsS", "--max-time", "10", "https://wttr.in/" + root.locationQuery + "?format=j1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.scheduleForecastRetry()
          return
        }
        try {
          var parsed = JSON.parse(raw)
          root.report = parsed
          if (!root.hasConfiguredCoordinates)
            root.label = Model.provisionalCurrentIcon(parsed.current_condition && parsed.current_condition[0], root.label)
          root.forecastRetries = 0
          if (Model.weatherResponseCompletesSave(root.hasConfiguredCoordinates, "wttr"))
            root.finishSavingLocation()
          // Stored coordinates already drove the fast open-meteo fetch from
          // refresh(); only auto-detect needs the area wttr reported.
          if (isNaN(parseFloat(String(root.configuredLocationState.latitude))))
            root.refreshDailyForecast(parsed)
          root.refreshRadar()
        } catch (e) {
          // Keep last-good report visible, but try again shortly.
          root.scheduleForecastRetry()
        }
      }
    }
  }

  // wttr.in can be slow or flaky, especially for a location it hasn't
  // cached yet. Retry a few times before leaving it to the refresh timer.
  function scheduleForecastRetry() {
    if (forecastRetries >= 3) return
    forecastRetries++
    forecastRetryTimer.restart()
  }

  Timer {
    id: forecastRetryTimer
    interval: 2500
    onTriggered: if (!forecastProc.running) forecastProc.running = true
  }

  // With configured coordinates this fetch is the only thing that updates the
  // bar icon, so a dropped response (e.g. waking before the network is back)
  // must retry rather than wait out the refresh timer with a stale icon.
  function scheduleDailyForecastRetry() {
    if (dailyForecastRetries >= 3) return
    dailyForecastRetries++
    dailyForecastRetryTimer.restart()
  }

  Timer {
    id: dailyForecastRetryTimer
    interval: 2500
    onTriggered: root.refreshDailyForecast(null)
  }

  Process {
    id: dailyForecastProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.scheduleDailyForecastRetry()
          return
        }
        try {
          var parsed = JSON.parse(raw)
          var parsedCurrent = Model.openMeteoCurrentCondition(parsed)
          root.dailyForecastReport = parsed
          root.label = Model.currentIcon(parsedCurrent, root.label)
          root.dailyForecastRetries = 0
          if (Model.weatherResponseCompletesSave(root.hasConfiguredCoordinates, "open-meteo"))
            root.finishSavingLocation()
        } catch (e) {
          // Keep last-good daily forecast visible, but try again shortly.
          root.scheduleDailyForecastRetry()
        }
      }
    }
  }

  Process {
    id: geocodeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.locationSuggestions = root.editingLocation ? Model.parseGeocodingResults(text) : []
        root.suggestionIndex = 0
        if (root.geocodePendingQuery !== root.geocodeActiveQuery) Qt.callLater(root.startGeocode)
      }
    }
  }

  Timer {
    id: geocodeDebounce
    interval: 300
    onTriggered: root.requestGeocode()
  }

  Process {
    id: locationSaveProc
    onExited: function(exitCode) {
      if (exitCode !== 0 || !root.savingLocation) return

      // FileView handles changed locations. Explicitly refresh here too so
      // saving the already-active location cannot strand the spinner.
      locationFile.reload()
      if (!root.savingLocationQueryStarted) {
        root.savingLocationQueryStarted = true
        root.forecastRetries = 0
        root.dailyForecastRetries = 0
        forecastProc.running = false
        dailyForecastProc.running = false
        Qt.callLater(root.refresh)
      }
    }
  }

  Process {
    id: locationProc
    command: ["curl", "-fsS", "--max-time", "4", "https://wttr.in/?format=%l"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        root.wttrLocation = raw.split(",")[0]
      }
    }
  }

  Process {
    id: radarProc
    onStarted: { stdoutBuf = ""; stderrBuf = "" }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        radarProc.stdoutBuf += chunk
        if (radarProc.stdoutBuf.length > 131072) {
          radarProc.signal(15)
          radarProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        radarProc.stderrBuf += chunk
        if (radarProc.stderrBuf.length > 4096) {
          radarProc.signal(15)
          radarProc.stderrBuf = ""
        }
      }
    }
    onExited: function() {
      root.radarLoading = false
      var raw = String(stdoutBuf || "").trim()
      if (!raw) {
        if (!root.radarData || root.radarData.ok !== true)
          root.radarData = { ok: false, error: "unavailable", time: 0, grid: 64, zoom: 7, lat: 0, lon: 0, cells: [] }
        return
      }
      var parsed = Model.parseRadarPayload(raw)
      var prev = root.radarData
      root.radarData = parsed
      if (!parsed || parsed.ok !== true) return
      if (prev && parsed.lat === prev.lat && parsed.lon === prev.lon) return
      root.clearRadarFrames()
    }
  }

  Process {
    id: radarHistoryProc
    onStarted: { stdoutBuf = ""; stderrBuf = ""; radarHistoryWatch.restart() }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        radarHistoryProc.stdoutBuf += chunk
        if (radarHistoryProc.stdoutBuf.length > 393216) {
          radarHistoryProc.signal(15)
          radarHistoryProc.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        radarHistoryProc.stderrBuf += chunk
        if (radarHistoryProc.stderrBuf.length > 4096) {
          radarHistoryProc.signal(15)
          radarHistoryProc.stderrBuf = ""
        }
      }
    }
    onExited: function() {
      radarHistoryWatch.stop()
      root.radarHistoryLoading = false
      var pending = root.radarStepPending
      root.radarStepPending = 0
      var raw = String(stdoutBuf || "").trim()
      if (!raw) return
      var parsed = Model.parseRadarHistory(raw)
      if (!parsed || parsed.ok !== true || parsed.frames.length < 2) return
      root.radarFrames = parsed.frames
      root.radarFrameIndex = -1
      if (pending) root.applyRadarStep(pending)
    }
  }

  Timer {
    id: radarHistoryWatch
    interval: 25000
    repeat: false
    onTriggered: {
      if (radarHistoryProc.running) radarHistoryProc.signal(15)
    }
  }

  Component.onDestruction: {
    root.radarFrameIndex = -1
    if (radarProc.running) radarProc.signal(15)
    if (radarHistoryProc.running) radarHistoryProc.signal(15)
  }

  onOpenedChanged: {
    if (!root.opened)
      root.radarFrameIndex = -1
    else
      root.refreshRadar()
  }

  Timer {
    id: refreshTimer
    interval: root.refreshMinutes * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function edit(): void { root.openFromHotkey(); root.startEditingLocation() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Theme.space(380))
    contentHeight: panel.fittedContentHeight(weatherColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLocation
      onReturnRequested: root.startEditingLocation()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.stepRadar(dx > 0 ? 1 : -1)
      }

      Flickable {
        id: weatherScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: weatherColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: weatherColumn
          width: weatherScroll.width
          spacing: Theme.space(14)

      PanelHero {
        id: weatherHero
        width: parent.width
        title: root.current ? ((root.reportTempNum || "—") + root.tempUnit) : "Weather"
        meta: root.editingLocation ? "" : (root.reportLocation || "")
        foreground: root.foreground
        fontFamily: root.fontFamily

        iconComponent: Component {
          Text {
            textFormat: Text.PlainText
            text: root.label || "—"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.display
          }
        }

        TapHandler {
          onTapped: if (!root.editingLocation) root.startEditingLocation()
        }
        HoverHandler {
          cursorShape: root.editingLocation ? Qt.ArrowCursor : Qt.PointingHandCursor
        }
      }

      Row {
        visible: root.editingLocation
        width: parent.width
        spacing: Theme.space(6)

        TextField {
          id: locationField
          width: parent.width - Theme.space(18) - parent.spacing
          enabled: !root.savingLocation
          placeholderText: "Search city"
          foreground: root.foreground
          font.family: root.fontFamily

          onTextChanged: if (root.editingLocation && !root.savingLocation) geocodeDebounce.restart()

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.cancelEditingLocation()
              event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              if (root.suggestionIndex < root.locationSuggestions.length - 1) root.suggestionIndex++
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              if (root.suggestionIndex > 0) root.suggestionIndex--
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.commitLocation()
              event.accepted = true
            }
          }
        }

        Rectangle {
          width: Theme.space(18)
          height: Theme.space(18)
          anchors.verticalCenter: parent.verticalCenter
          radius: Math.min(4, Theme.cornerRadius)
          color: !root.savingLocation && clearLocationArea.containsMouse ? Theme.hoverFillFor(root.foreground, Theme.accent) : "transparent"

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: root.savingLocation ? "󰦖" : "✕"
            font.family: root.fontFamily
            color: Qt.darker(root.foreground, 1.4)
            font.pixelSize: Theme.font.bodySmall

            RotationAnimator on rotation {
              running: root.savingLocation
              from: 0; to: 360
              duration: 800
              loops: Animation.Infinite
            }
          }

          MouseArea {
            id: clearLocationArea
            anchors.fill: parent
            enabled: !root.savingLocation
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.clearLocation()
          }
        }
      }

      Row {
        id: weatherStats
        visible: !!root.current
        width: parent.width
        spacing: Theme.space(8)

        Column {
          width: (weatherStats.width - weatherStats.spacing * 2) / 3
          spacing: Theme.space(2)
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "FEELS"
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Theme.font.caption
            font.letterSpacing: 1
            elide: Text.ElideRight
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.reportFeels
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            font.bold: true
            elide: Text.ElideRight
          }
        }

        Column {
          width: (weatherStats.width - weatherStats.spacing * 2) / 3
          spacing: Theme.space(2)
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "WIND"
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Theme.font.caption
            font.letterSpacing: 1
            elide: Text.ElideRight
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.reportWind
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            font.bold: true
            elide: Text.ElideRight
          }
        }

        Column {
          width: (weatherStats.width - weatherStats.spacing * 2) / 3
          spacing: Theme.space(2)
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "HUMID"
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Theme.font.caption
            font.letterSpacing: 1
            elide: Text.ElideRight
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.reportHumidity
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.body
            font.bold: true
            elide: Text.ElideRight
          }
        }
      }

      // ---- Geocoding suggestions while the location is being edited.
      Column {
        visible: root.editingLocation && !root.savingLocation && root.locationSuggestions.length > 0
        width: parent.width
        spacing: 0

        Repeater {
          model: root.locationSuggestions

          Rectangle {
            required property var modelData
            required property int index
            width: parent.width
            height: suggestionRow.implicitHeight + Theme.space(12)
            radius: Theme.cornerRadius
            color: index === root.suggestionIndex ? Theme.hoverFillFor(root.foreground, Theme.accent) : "transparent"

            Row {
              id: suggestionRow
              anchors.left: parent.left
              anchors.leftMargin: Theme.space(16)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Theme.space(8)

              Text {
                textFormat: Text.PlainText
                text: modelData.name
                color: index === root.suggestionIndex ? Theme.hoverStateColor(root.foreground, Theme.accent) : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Theme.font.body
              }
              Text {
                textFormat: Text.PlainText
                visible: text !== ""
                text: modelData.description
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Theme.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: root.suggestionIndex = index
              onClicked: root.pickSuggestion(modelData)
            }
          }
        }
      }

      Text {
        visible: !root.current
        textFormat: Text.PlainText
        text: "Fetching forecast…"
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Theme.font.bodySmall
        font.italic: true
      }

      // ---- Divider between current conditions and forecast.
      Rectangle {
        visible: root.forecastDays.length > 0
        width: parent.width
        height: Theme.spacing.hairline
        color: root.foreground
        opacity: 0.12
      }

      Row {
        id: forecastRow
        visible: root.forecastDays.length > 0
        width: parent.width
        spacing: Theme.space(16)

        Repeater {
          model: root.forecastDays

          ForecastTile {
            required property var modelData
            required property int index
            width: (forecastRow.width - forecastRow.spacing * Math.max(0, root.forecastDays.length - 1)) / Math.max(1, root.forecastDays.length)
            day: root.dayName(modelData.date).toUpperCase()
            icon: root.dayIcon(modelData)
            high: root.bareTempForDay(modelData, "max")
            low: root.bareTempForDay(modelData, "min")
          }
        }
      }

      Item {
        id: radarWrap
        visible: root.radarCells.length > 0 || root.radarLoading || (root.radarData && root.radarData.error)
        width: parent.width
        height: radarBox.height
        readonly property real cellSize: radarMap.width / root.radarGrid
        readonly property int cross: Math.max(8, Math.round(cellSize))

        Column {
          id: radarBox
          width: parent.width
          spacing: Theme.space(4)

          Item {
            id: radarMap
            width: parent.width
            height: width
            readonly property real originLat: root.radarData && root.radarData.ok ? root.radarData.lat : NaN
            readonly property real originLon: root.radarData && root.radarData.ok ? root.radarData.lon : NaN
            readonly property var rings: Model.radarRingRadii(originLat, width, root.radarZoom)
            readonly property var towns: Model.radarTowns(
              originLat, originLon, width, root.radarZoom,
              root.reportLocation, originLat, originLon)
            readonly property color ink: root.foreground
            readonly property string mapFont: root.fontFamily

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(0, 0, 0, 0.28)
            }

            Canvas {
              id: coastCanvas
              anchors.fill: parent
              contextType: "2d"
              readonly property var paths: Model.radarCoastPaths(
                Coast.RINGS, radarMap.originLat, radarMap.originLon,
                width, root.radarZoom)
              readonly property color landFill: Qt.rgba(
                radarMap.ink.r, radarMap.ink.g, radarMap.ink.b, 0.04)
              readonly property color shore: Qt.rgba(
                radarMap.ink.r, radarMap.ink.g, radarMap.ink.b, 0.22)

              onPathsChanged: requestPaint()
              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()
              onLandFillChanged: requestPaint()
              onShoreChanged: requestPaint()

              onPaint: {
                var ctx = getContext("2d")
                if (!ctx) return
                ctx.clearRect(0, 0, width, height)
                var rings = paths
                if (!rings || !rings.length) return
                ctx.lineWidth = 0.75
                ctx.strokeStyle = shore
                ctx.fillStyle = landFill
                ctx.lineJoin = "round"
                for (var i = 0; i < rings.length; i++) {
                  var ring = rings[i]
                  if (!ring || ring.length < 3) continue
                  ctx.beginPath()
                  ctx.moveTo(ring[0].x, ring[0].y)
                  for (var j = 1; j < ring.length; j++)
                    ctx.lineTo(ring[j].x, ring[j].y)
                  ctx.closePath()
                  ctx.fill()
                  ctx.stroke()
                }
              }
            }

            Canvas {
              id: rainCanvas
              anchors.fill: parent
              contextType: "2d"
              // Antialiased fills blend with the previous frame. Cells that
              // go empty (the edge the storm moves off) would keep the old color.
              antialiasing: false
              smooth: false
              readonly property var cells: root.radarCells
              readonly property int grid: root.radarGrid
              readonly property int frameIndex: root.radarFrameIndex

              onCellsChanged: requestPaint()
              onGridChanged: requestPaint()
              onFrameIndexChanged: requestPaint()
              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()

              onPaint: {
                var ctx = getContext("2d")
                if (!ctx) return
                var rain = rainCanvas.cells
                var n = rainCanvas.grid
                var w = width
                var h = height
                // "copy" replaces the pixel, including turning it transparent.
                // clearRect does not, once the painter is scaled for the screen.
                ctx.globalCompositeOperation = "copy"
                if (!rain || !n || n < 1 || rain.length < n * n) {
                  ctx.fillStyle = "rgba(0,0,0,0)"
                  ctx.fillRect(0, 0, Math.ceil(w) + 1, Math.ceil(h) + 1)
                  ctx.globalCompositeOperation = "source-over"
                  return
                }
                for (var row = 0; row < n; row++) {
                  var y0 = Math.floor(row * h / n)
                  var y1 = row === n - 1 ? Math.ceil(h) + 1 : Math.floor((row + 1) * h / n)
                  for (var col = 0; col < n; col++) {
                    var c = rain[row * n + col]
                    var x0 = Math.floor(col * w / n)
                    var x1 = col === n - 1 ? Math.ceil(w) + 1 : Math.floor((col + 1) * w / n)
                    if (!c || (c.a || 0) <= 0)
                      ctx.fillStyle = "rgba(0,0,0,0)"
                    else
                      ctx.fillStyle = "rgba(" + c.r + "," + c.g + "," + c.b + "," + (c.a / 255) + ")"
                    ctx.fillRect(x0, y0, x1 - x0, y1 - y0)
                  }
                }
                ctx.globalCompositeOperation = "source-over"
              }
            }

            Repeater {
              model: radarMap.rings

              Rectangle {
                required property real modelData
                width: modelData * 2
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.darker(radarMap.ink, 1.5)
                opacity: 0.4
                anchors.centerIn: parent
              }
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              width: radarWrap.cross
              height: 1
              color: Theme.accent
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              width: 1
              height: radarWrap.cross
              color: Theme.accent
            }

            Repeater {
              model: radarMap.towns

              Item {
                required property var modelData
                x: modelData.x
                y: modelData.y

                Rectangle {
                  width: 4
                  height: 4
                  x: -2
                  y: -2
                  color: modelData.home ? Theme.accent : radarMap.ink
                }

                Text {
                  textFormat: Text.PlainText
                  x: 6
                  y: -7
                  text: modelData.name
                  color: modelData.home ? Theme.accent : Qt.darker(radarMap.ink, 1.25)
                  font.family: radarMap.mapFont
                  font.pixelSize: Theme.font.caption
                }
              }
            }

          }

          Item {
            width: parent.width
            height: radarNav.visible ? radarNav.height : radarErrorLabel.implicitHeight
            visible: radarNav.visible || radarErrorLabel.visible

            Text {
              id: radarErrorLabel
              textFormat: Text.PlainText
              width: parent.width
              visible: root.radarStatus !== "" && !(root.radarData && root.radarData.ok === true)
              text: root.radarStatus
              color: Qt.darker(radarMap.ink, 1.4)
              font.family: radarMap.mapFont
              font.pixelSize: Theme.font.caption
              font.letterSpacing: 1
              horizontalAlignment: Text.AlignHCenter
            }

            Row {
              id: radarNav
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Theme.space(2)
              visible: root.radarData && root.radarData.ok === true

              PanelActionButton {
                id: radarBack
                iconText: "󰅁"
                tooltipText: "Back"
                enabled: root.radarCanBack
                foreground: Qt.darker(radarMap.ink, 1.4)
                hoverColor: radarMap.ink
                fontFamily: radarMap.mapFont
                onClicked: root.stepRadar(-1)
              }

              Text {
                textFormat: Text.PlainText
                width: Theme.space(156)
                height: radarBack.height
                verticalAlignment: Text.AlignVCenter
                text: root.radarStatus
                color: Qt.darker(radarMap.ink, 1.4)
                font.family: radarMap.mapFont
                font.pixelSize: Theme.font.caption
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
              }

              PanelActionButton {
                iconText: "󰅂"
                tooltipText: "Forward"
                enabled: root.radarCanForward
                foreground: Qt.darker(radarMap.ink, 1.4)
                hoverColor: radarMap.ink
                fontFamily: radarMap.mapFont
                onClicked: root.stepRadar(1)
              }
            }
          }
        }
      }
    }
  }
  }
  }

  component ForecastTile: Item {
    id: tile
    property string day: ""
    property string icon: ""
    property string high: ""
    property string low: ""

    implicitWidth: Theme.space(108)
    implicitHeight: Theme.font.display + Theme.font.title + Theme.space(40)

    Rectangle {
      id: frame
      anchors.fill: parent
      anchors.topMargin: legendChip.visible ? legendChip.height / 2 : 0
      color: "transparent"
      radius: Theme.space(8)
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.28)
      antialiasing: true
    }

    Item {
      id: legendChip
      x: Theme.space(14)
      y: 0
      width: Math.min(legendTextItem.implicitWidth + Theme.space(8), Math.max(Theme.space(24), parent.width - Theme.space(20)))
      height: Math.max(1, legendTextItem.implicitHeight)
      visible: tile.day !== ""

      Rectangle {
        anchors.fill: parent
        color: Theme.popups.background
      }

      Text {
        id: legendTextItem
        x: Theme.space(4)
        width: Math.max(1, parent.width - Theme.space(8))
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: tile.day
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Theme.font.caption
        font.bold: true
        elide: Text.ElideRight
      }
    }

    Column {
      anchors.centerIn: frame
      width: Math.max(1, frame.width - Theme.space(12))
      spacing: Theme.space(2)

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: tile.icon || "—"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Theme.font.display
        horizontalAlignment: Text.AlignHCenter
      }

      Item {
        width: parent.width
        height: tempRow.implicitHeight

        Row {
          id: tempRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Theme.space(6)

          Text {
            textFormat: Text.PlainText
            text: tile.high
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Theme.font.title
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: tile.low
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Theme.font.title
            font.bold: true
          }
        }
      }
    }
  }
}
