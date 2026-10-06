import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons
import "Api.js" as Api
import "Model.js" as Model

Item {
  id: root
  visible: false

  property var shell: null
  property var manifest: null
  property var settingsOverride: null

  readonly property string tokenScript: Qt.resolvedUrl("bin/load-token").toString().replace("file://", "")
  readonly property string passTokenPath: "evoshell/cloudflare/token"
  property string passToken: ""
  property bool passTokenLoaded: false
  property string token: ""
  property bool loggedIn: token !== ""
  property bool configLoaded: false

  property string accountId: ""
  property string accountName: ""

  property var workers: []
  property var pages: []
  property var buckets: []
  property var databases: []
  property var namespaces: []
  property var queues: []
  property var zones: []

  property string accountSubdomain: ""
  property var workerDomains: ({})
  property var workerDotDev: ({})
  property var _dotDevQueue: []

  property var analytics: emptyAnalytics()

  property bool refreshing: false
  property bool analyticsRefreshing: false
  property double lastRefreshMs: 0
  property string lastError: ""
  property string actionStatus: ""
  property var projectDirs: ({})

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 60, 30, 3600)
  readonly property int analyticsIntervalSec: intSetting("analyticsIntervalSec", 900, 60, 7200)
  readonly property int deployRows: intSetting("deployRows", 8, 3, 30)
  readonly property int overviewDeployRows: intSetting("overviewDeployRows", 3, 1, 10)
  readonly property int errorRatePercent: intSetting("errorRatePercent", 1, 1, 100)
  readonly property string projectsRootOverride: String(setting("projectsRoot", "") || "").trim()
  readonly property var projectScanRoots: {
    if (projectsRootOverride !== "")
      return [projectsRootOverride]
    var home = Quickshell.env("HOME") || ""
    return Api.defaultLinuxProjectRoots(home, "")
  }
  readonly property var limits: ({
    workerRequestsPerDay: intSetting("workerRequestsPerDay", 0, 0, 1000000000),
    r2StorageGb: intSetting("r2StorageGb", 0, 0, 100000),
    d1RowsReadPerDay: intSetting("d1RowsReadPerDay", 0, 0, 100000000000)
  })

  readonly property bool busy: refreshing || analyticsRefreshing
  readonly property int failedDeploys: Model.failedDeployCount(
    Model.buildDeploys(workers, pages, deployRows, null))
  readonly property bool warning: !loggedIn || failedDeploys > 0 || analytics.workersOverErrorRate > 0

  function widgetSettings() {
    var defaults = (manifest && manifest.barWidget && manifest.barWidget.defaults)
      ? manifest.barWidget.defaults : {}
    var merged = {}
    for (var key in defaults) merged[key] = defaults[key]
    if (settingsOverride && typeof settingsOverride === "object") {
      for (var overrideKey in settingsOverride) {
        if (overrideKey !== "id") merged[overrideKey] = settingsOverride[overrideKey]
      }
      return merged
    }
    if (!shell || !shell.barConfig || !shell.barConfig.layout)
      return merged
    var layout = shell.barConfig.layout
    var sections = [layout.center, layout.left, layout.right]
    for (var s = 0; s < sections.length; s++) {
      var list = sections[s]
      if (!Array.isArray(list))
        continue
      for (var i = 0; i < list.length; i++) {
        var item = list[i]
        if (item && String(item.id) === "evo.cloudflare") {
          for (var k in item) {
            if (k !== "id") merged[k] = item[k]
          }
          return merged
        }
      }
    }
    return merged
  }

  function setting(name, fallback) {
    var settings = widgetSettings()
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }

  function emptyAnalytics() {
    return {
      loaded: false,
      workerRequests: 0, workerErrors: 0,
      r2Bytes: 0, r2Objects: 0,
      d1RowsRead: 0, d1RowsWritten: 0,
      zoneRequests: 0, zoneBytes: 0, zoneThreats: 0,
      workersOverErrorRate: 0,
      requestHours: [],
      perWorker: ({}), perBucket: ({}), perDatabase: ({}), perZone: ({})
    }
  }

  function resourceState() {
    return {
      workers: workers, pages: pages, buckets: buckets, databases: databases,
      namespaces: namespaces, queues: queues, zones: zones,
      errorRateThreshold: errorRatePercent,
      accountSubdomain: accountSubdomain, workerDomains: workerDomains,
      workerDotDev: workerDotDev
    }
  }

  Process {
    id: passTokenLoad
    onStarted: { stdoutBuf = ""; stderrBuf = "" }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    command: ["bash", root.tokenScript]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        passTokenLoad.stdoutBuf += chunk
        if (passTokenLoad.stdoutBuf.length > 262144) {
          passTokenLoad.signal(15)
          passTokenLoad.stdoutBuf = ""
        }
      }
    }
    onExited: root.notePassToken(String(passTokenLoad.stdoutBuf || ""))
  }

  Component.onCompleted: passTokenLoad.running = true

  function notePassToken(text) {
    root.passToken = String(text || "").trim()
    root.passTokenLoaded = true
    root.configLoaded = true
    root.token = root.passToken
    if (root.lastError.indexOf("pass insert") >= 0) root.lastError = ""
    if (root.passToken !== "") Qt.callLater(function() { root.refresh() })
    else root.lastError = "set a Cloudflare API token: pass insert " + root.passTokenPath
  }

  function ensureToken() {
    if (!root.configLoaded) return false
    if (root.token === "") return false
    return true
  }

  function isAuthFailure(env) {
    if (!env) return false
    if (env.code === 10000) return true
    var message = String(env.error || "").toLowerCase()
    return message.indexOf("invalid access token") >= 0
      || message.indexOf("invalid token") >= 0
      || message.indexOf("authentication") >= 0
      || message.indexOf("unauthor") >= 0
      || message.indexOf("expired") >= 0
  }

  component Request: Process {
    id: req

    property string stdoutBuf: ""
    property string stderrBuf: ""
    property string url: ""
    property string body: ""
    property var handler: null
    property string configText: ""

    stdinEnabled: true
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        req.stdoutBuf += chunk
        if (req.stdoutBuf.length > 262144) {
          req.signal(15)
          req.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        req.stderrBuf += chunk
        if (req.stderrBuf.length > 4096) {
          req.signal(15)
          req.stderrBuf = ""
        }
      }
    }

    function send(targetUrl, postBody, onDone) {
      if (req.running) return false
      req.url = targetUrl
      req.body = postBody || ""
      req.handler = onDone
      req.configText = Api.curlConfig(root.token, targetUrl)
      req.command = postBody ? Api.curlPost(postBody) : Api.curlGet()
      req.stdinEnabled = true
      req.running = true
      return true
    }

    onStarted: {
      stdoutBuf = ""; stderrBuf = ""

      write(configText)
      configText = ""
      stdinEnabled = false
    }

    onExited: function(exitCode) {
      var text = String(req.stdoutBuf || "")
      var errorText = String(req.stderrBuf || "").trim()
      if (req.handler) req.handler(exitCode, text, errorText)
      req.handler = null
    }
  }

  Request { id: accountsReq }
  Request { id: workersReq }
  Request { id: pagesReq }
  Request { id: r2Req }
  Request { id: d1Req }
  Request { id: kvReq }
  Request { id: queuesReq }
  Request { id: zonesReq }
  Request { id: domainsReq }
  Request { id: subdomainReq }
  Request { id: dotDevReq }
  Request { id: graphqlReq }
  Request { id: purgeReq }

  property int _pending: 0

  function beginSweep(count) {
    root._pending = count
    root.refreshing = true
  }

  function endOne() {
    root._pending = Math.max(0, root._pending - 1)
    if (root._pending === 0) {
      root.refreshing = false
      root.lastRefreshMs = Date.now()
    }
  }

  function handle(label, assign) {
    return function(exitCode, text, errorText) {
      if (exitCode !== 0) {
        root.lastError = label + ": " + (errorText || "curl exited " + exitCode)
        root.endOne()
        return
      }
      var env = Api.parseEnvelope(text)
      if (!env.ok) {
        if (root.isAuthFailure(env)) {
          root.lastError = label + ": " + env.error
            + " — check pass " + root.passTokenPath
        } else {
          root.lastError = label + ": " + env.error
        }
        root.endOne()
        return
      }
      assign(env.result)
      root.endOne()
    }
  }

  function asArray(value) { return Array.isArray(value) ? value : [] }

  function refresh() {
    if (root.refreshing) return
    if (!ensureToken()) return
    if (root.accountId === "") { resolveAccount(); return }

    root.lastError = ""
    beginSweep(8)
    workersReq.send(Api.workersUrl(accountId), "", handle("workers", function(r) { root.workers = asArray(r) }))
    pagesReq.send(Api.pagesUrl(accountId), "", handle("pages", function(r) { root.pages = asArray(r) }))
    r2Req.send(Api.r2Url(accountId), "", handle("r2", function(r) { root.buckets = r && r.buckets ? asArray(r.buckets) : [] }))
    d1Req.send(Api.d1Url(accountId), "", handle("d1", function(r) { root.databases = asArray(r) }))
    kvReq.send(Api.kvUrl(accountId), "", handle("kv", function(r) { root.namespaces = asArray(r) }))
    queuesReq.send(Api.queuesUrl(accountId), "", handle("queues", function(r) { root.queues = asArray(r) }))
    domainsReq.send(Api.workersDomainsUrl(accountId), "", handle("domains", function(r) {
      var map = {}
      var list = asArray(r)
      for (var i = 0; i < list.length; i++) {
        var service = String(list[i].service || "")
        var hostname = String(list[i].hostname || "")
        if (service && hostname && !map[service]) map[service] = hostname
      }
      root.workerDomains = map
      root.queueDotDevProbes()
    }))
    zonesReq.send(Api.zonesUrl(), "", handle("zones", function(r) {
      root.zones = asArray(r)
      if (!root.analytics.loaded) root.refreshAnalytics()
    }))
  }

  function resolveAccount() {
    if (accountsReq.running) return
    if (!ensureToken()) return
    beginSweep(1)
    accountsReq.send(Api.accountsUrl(), "", handle("accounts", function(result) {
      var list = asArray(result)
      if (list.length === 0) {
        root.lastError = "no Cloudflare account on this token"
        return
      }
      root.accountId = String(list[0].id || "")
      root.accountName = String(list[0].name || "")
      Qt.callLater(function() { root.refresh() })
    }))
  }

  function queueDotDevProbes() {
    if (root.accountId === "") return
    if (root.accountSubdomain === "" && !subdomainReq.running) {
      subdomainReq.send(Api.workersSubdomainUrl(root.accountId), "", function(exitCode, text) {
        if (exitCode !== 0) return
        var env = Api.parseEnvelope(text)
        if (env.ok && env.result) root.accountSubdomain = String(env.result.subdomain || "")
        root.queueDotDevProbes()
      })
      return
    }
    if (root.accountSubdomain === "") return

    var pending = []
    for (var i = 0; i < root.workers.length; i++) {
      var name = String(root.workers[i].id || "")
      if (!name) continue
      if (root.workerDomains[name]) continue
      if (root.workerDotDev[name] !== undefined) continue
      pending.push(name)
    }
    root._dotDevQueue = pending
    root.drainDotDevQueue()
  }

  function drainDotDevQueue() {
    if (dotDevReq.running) return
    if (!root._dotDevQueue || root._dotDevQueue.length === 0) return
    var queue = root._dotDevQueue.slice()
    var name = queue.shift()
    root._dotDevQueue = queue
    dotDevReq.send(Api.scriptSubdomainUrl(root.accountId, name), "", function(exitCode, text) {
      var enabled = false
      if (exitCode === 0) {
        var env = Api.parseEnvelope(text)
        if (env.ok && env.result) enabled = env.result.enabled === true
      }
      var next = {}
      for (var key in root.workerDotDev) next[key] = root.workerDotDev[key]
      next[name] = enabled
      root.workerDotDev = next
      Qt.callLater(function() { root.drainDotDevQueue() })
    })
  }

  function refreshAnalytics() {
    if (root.analyticsRefreshing || graphqlReq.running) return
    if (root.accountId === "") return
    if (!ensureToken()) return

    var zoneIds = []
    for (var i = 0; i < root.zones.length; i++) {
      var id = String(root.zones[i].id || "")
      if (id !== "") zoneIds.push(id)
    }

    root.analyticsRefreshing = true
    graphqlReq.send(Api.graphqlUrl(), Api.usageQuery(root.accountId, zoneIds, Date.now()), function(exitCode, text, errorText) {
      root.analyticsRefreshing = false
      if (exitCode !== 0) {
        root.lastError = "analytics: " + (errorText || "curl exited " + exitCode)
        return
      }
      var parsed = Api.parseGraphql(text)
      if (!parsed.ok) {
        root.lastError = "analytics: " + parsed.error
        return
      }
      root.analytics = root.reduceAnalytics(parsed.data)
    })
  }

  function reduceAnalytics(data) {
    var next = emptyAnalytics()
    next.loaded = true

    var viewer = data.viewer || {}
    var accounts = Array.isArray(viewer.accounts) ? viewer.accounts : []
    var account = accounts.length > 0 ? accounts[0] : {}
    var i

    var invocations = Array.isArray(account.workersInvocationsAdaptive) ? account.workersInvocationsAdaptive : []
    for (i = 0; i < invocations.length; i++) {
      var inv = invocations[i]
      var name = String(inv.dimensions ? inv.dimensions.scriptName : "")
      var requests = Number(inv.sum ? inv.sum.requests : 0) || 0
      var errors = Number(inv.sum ? inv.sum.errors : 0) || 0
      next.workerRequests += requests
      next.workerErrors += errors
      var rate = requests > 0 ? (errors / requests) * 100 : 0
      next.perWorker[name] = { requests: requests, errors: errors, errorRate: rate }
      if (rate >= root.errorRatePercent) next.workersOverErrorRate++
    }

    var byHour = {}
    var hourGroups = Array.isArray(account.workerHours) ? account.workerHours : []
    for (i = 0; i < hourGroups.length; i++) {
      var hourGroup = hourGroups[i]
      var stamp = String(hourGroup.dimensions ? hourGroup.dimensions.datetimeHour : "")
      var hourKey = stamp.slice(0, 13)
      if (hourKey === "") continue
      byHour[hourKey] = (byHour[hourKey] || 0) + (Number(hourGroup.sum ? hourGroup.sum.requests : 0) || 0)
    }
    var hourNow = Date.now()
    for (var back = 23; back >= 0; back--) {
      var bucket = new Date(hourNow - back * 60 * 60 * 1000).toISOString().slice(0, 13)
      next.requestHours.push(byHour[bucket] || 0)
    }

    var storage = Array.isArray(account.r2StorageAdaptiveGroups) ? account.r2StorageAdaptiveGroups : []
    for (i = 0; i < storage.length; i++) {
      var s = storage[i]
      var bucket = String(s.dimensions ? s.dimensions.bucketName : "")
      var bytes = Number(s.max ? s.max.payloadSize : 0) || 0
      var objects = Number(s.max ? s.max.objectCount : 0) || 0
      var priorBucket = next.perBucket[bucket]
      if (priorBucket) {
        priorBucket.bytes = Math.max(priorBucket.bytes, bytes)
        priorBucket.objects = Math.max(priorBucket.objects, objects)
      } else {
        next.perBucket[bucket] = { bytes: bytes, objects: objects }
      }
    }
    for (var b in next.perBucket) {
      next.r2Bytes += next.perBucket[b].bytes
      next.r2Objects += next.perBucket[b].objects
    }

    var d1 = Array.isArray(account.d1AnalyticsAdaptiveGroups) ? account.d1AnalyticsAdaptiveGroups : []
    for (i = 0; i < d1.length; i++) {
      var d = d1[i]
      var dbId = String(d.dimensions ? d.dimensions.databaseId : "")
      var rowsRead = Number(d.sum ? d.sum.rowsRead : 0) || 0
      var rowsWritten = Number(d.sum ? d.sum.rowsWritten : 0) || 0
      next.d1RowsRead += rowsRead
      next.d1RowsWritten += rowsWritten
      var priorDb = next.perDatabase[dbId] || { rowsRead: 0, rowsWritten: 0 }
      priorDb.rowsRead += rowsRead
      priorDb.rowsWritten += rowsWritten
      next.perDatabase[dbId] = priorDb
    }

    var zoneList = Array.isArray(viewer.zones) ? viewer.zones : []
    for (i = 0; i < zoneList.length; i++) {
      var z = zoneList[i]
      var tag = String(z.zoneTag || "")
      var groups = Array.isArray(z.httpRequests1dGroups) ? z.httpRequests1dGroups : []
      var agg = { requests: 0, bytes: 0, threats: 0 }
      for (var g = 0; g < groups.length; g++) {
        var sum = groups[g].sum || {}
        agg.requests += Number(sum.requests) || 0
        agg.bytes += Number(sum.bytes) || 0
        agg.threats += Number(sum.threats) || 0
      }
      next.perZone[tag] = agg
      next.zoneRequests += agg.requests
      next.zoneBytes += agg.bytes
      next.zoneThreats += agg.threats
    }

    return next
  }

  Process {
    id: projectScan
    onStarted: { stdoutBuf = ""; stderrBuf = "" }

    property string stdoutBuf: ""
    property string stderrBuf: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        projectScan.stdoutBuf += chunk
        if (projectScan.stdoutBuf.length > 262144) {
          projectScan.signal(15)
          projectScan.stdoutBuf = ""
        }
      }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        projectScan.stderrBuf += chunk
        if (projectScan.stderrBuf.length > 4096) {
          projectScan.signal(15)
          projectScan.stderrBuf = ""
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.projectDirs = Api.parseProjectScan(String(projectScan.stdoutBuf || ""))
    }
  }

  function scanProjects() {
    if (projectScan.running) return
    var roots = root.projectScanRoots
    if (!roots || roots.length === 0) return
    var cmd = ["bash", "-c", Api.projectScanScript, "_"]
    for (var i = 0; i < roots.length; i++)
      cmd.push(String(roots[i]))
    projectScan.command = cmd
    projectScan.running = true
  }

  function projectDirFor(name) {
    var dir = root.projectDirs[String(name || "")]
    return dir ? String(dir) : ""
  }

  function notify(title, body) {
    var notif = root.shell && typeof root.shell.serviceFor === "function"
      ? root.shell.serviceFor("evo.sys.notifications") : null
    if (notif && typeof notif.showBrief === "function") {
      notif.showBrief(Model.plain(title, 80), Model.plain(body || "", 180))
      return
    }
    Quickshell.execDetached(["notify-send", Model.plain(title, 80), Model.plain(body || "", 180)])
  }

  function openUrl(url) {
    var u = String(url || "")
    if (!/^https:\/\/[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+$/.test(u)) return
    Quickshell.execDetached(["xdg-open", u])
  }

  function validWorkerName(name) {
    return /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(String(name || ""))
  }

  function runInTerminal(argv, workingDirectory) {
    var cmd = ["ghostty"]
    if (workingDirectory) {
      var dir = String(workingDirectory)
      if (dir.charAt(0) !== "/") return
      var parts = dir.split("/")
      for (var i = 0; i < parts.length; i++) {
        if (parts[i] === "." || parts[i] === "..") return
      }
      cmd.push("--working-directory=" + dir)
    }
    cmd.push("-e", "bash", "-lc", "\"$@\"; printf '\\n[exit %s] press Enter to close' \"$?\"; read -r _", "_")
    for (var j = 0; j < argv.length; j++) cmd.push(argv[j])
    Quickshell.execDetached(cmd)
  }

  function copyToClipboard(value, label) {
    var text = String(value || "")
    if (text === "") return
    clipboard.payload = text
    clipboard.stdinEnabled = true
    clipboard.running = true
    root.flashStatus("Copied " + (label || "value"))
  }

  Process {
    id: clipboard
    property string payload: ""
    command: ["wl-copy"]
    stdinEnabled: true
    onStarted: {
      write(payload)
      payload = ""
      stdinEnabled = false
    }
  }

  function flashStatus(text) {
    root.actionStatus = Model.plain(text, 180)
    statusTimer.restart()
  }

  Timer {
    id: statusTimer
    interval: 2600
    onTriggered: root.actionStatus = ""
  }

  function tailWorker(name) {
    if (!validWorkerName(name)) return
    runInTerminal(["wrangler", "tail", String(name)])
    root.flashStatus("Tailing " + Model.plain(name, 80))
  }

  function deployProject(name) {
    if (!validWorkerName(name)) return
    var dir = projectDirFor(name)
    if (dir === "") {
      notify("Cloudflare", "No local wrangler project found for " + Model.plain(name, 80))
      return
    }
    runInTerminal(["wrangler", "deploy"], dir)
    root.flashStatus("Deploying " + Model.plain(name, 80))
  }

  function rollbackProject(name) {
    if (!validWorkerName(name)) return
    var dir = projectDirFor(name)
    if (dir === "") {
      notify("Cloudflare", "No local wrangler project found for " + Model.plain(name, 80))
      return
    }
    runInTerminal(["wrangler", "rollback"], dir)
    root.flashStatus("Rolling back " + Model.plain(name, 80))
  }

  function purgeZone(zone) {
    if (!zone || !zone.id) return
    if (purgeReq.running) return
    if (!ensureToken()) return
    root.flashStatus("Purging " + zone.name + "…")
    purgeReq.send(Api.purgeUrl(zone.id), JSON.stringify({ purge_everything: true }), function(exitCode, text, errorText) {
      if (exitCode !== 0) {
        root.flashStatus("Purge failed: " + (errorText || "curl exited " + exitCode))
        return
      }
      var env = Api.parseEnvelope(text)
      if (env.ok) {
        root.flashStatus("Purged " + zone.name)
        notify("Cloudflare", "Cache purged for " + zone.name)
        return
      }
      if (root.isAuthFailure(env)) {
        root.flashStatus("Purge refused — the API token lacks Cache Purge permission.")
        root.notify("Cloudflare", "Cache purge needs an API token with the Cache Purge permission.")
      } else {
        root.flashStatus("Purge failed: " + env.error)
      }
    })
  }

  Timer {
    id: resourceTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: analyticsTimer
    interval: root.analyticsIntervalSec * 1000
    repeat: true
    running: true
    onTriggered: root.refreshAnalytics()
  }

  Timer {
    id: projectTimer
    interval: 600000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.scanProjects()
  }

  Timer {
    id: watchdog
    interval: 30000
    repeat: true
    running: root.refreshing || root.analyticsRefreshing
    onTriggered: {
      var slots = [accountsReq, workersReq, pagesReq, r2Req, d1Req, kvReq, queuesReq, zonesReq, graphqlReq]
      for (var i = 0; i < slots.length; i++) if (slots[i].running) slots[i].running = false
      root._pending = 0
      root.refreshing = false
      root.analyticsRefreshing = false
      root.lastError = "request timed out"
    }
  }
}
