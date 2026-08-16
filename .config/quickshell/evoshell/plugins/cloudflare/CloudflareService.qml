import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons"
import "Api.js" as Api
import "Model.js" as Model

// Cloudflare account data for evoshell (wrangler OAuth + Cloudflare API).
Item {
  id: root
  visible: false

  property var shell: null

  function traySettings() {
    if (!shell || !shell.barConfig || !shell.barConfig.layout)
      return ({})
    var layout = shell.barConfig.layout
    var sections = [layout.center, layout.left, layout.right]
    for (var s = 0; s < sections.length; s++) {
      var list = sections[s]
      if (!Array.isArray(list))
        continue
      for (var i = 0; i < list.length; i++) {
        var item = list[i]
        if (item && String(item.id) === "evo.tray" && item.cloudflare)
          return item.cloudflare
      }
    }
    return ({})
  }

  // --- credentials ---------------------------------------------------------
  //
  // Wrangler does not keep its credentials in one fixed place. This machine has
  // both ~/.wrangler and ~/.config/.wrangler, and wrangler switched which one it
  // wrote to partway through a session — leaving the hardcoded path holding an
  // expired token while the live one sat elsewhere, which looks exactly like a
  // broken login. So watch every candidate and use whichever holds the token
  // that expires furthest in the future.
  readonly property var wranglerConfigPaths: {
    var explicit = String(setting("wranglerConfigPath", "") || "").trim()
    if (explicit !== "") return [explicit]
    var home = Quickshell.env("HOME")
    var xdg = Quickshell.env("XDG_CONFIG_HOME")
    if (!xdg || xdg === "") xdg = home + "/.config"
    var paths = [home + "/.wrangler/config/default.toml"]
    var xdgPath = xdg + "/.wrangler/config/default.toml"
    if (paths.indexOf(xdgPath) < 0) paths.push(xdgPath)
    return paths
  }
  // Path the credentials in use came from, for diagnose.
  property string credentialSource: ""
  property var credentialCandidates: ({})
  property string token: ""
  property double tokenExpiresMs: 0
  property var tokenScopes: []
  property bool loggedIn: token !== ""
  property bool refreshingToken: false

  // --- account -------------------------------------------------------------
  property string accountId: ""
  property string accountName: ""

  // --- resources -----------------------------------------------------------
  property var workers: []
  property var pages: []
  property var buckets: []
  property var databases: []
  property var namespaces: []
  property var queues: []
  property var zones: []

  // --- live URLs -----------------------------------------------------------
  property string accountSubdomain: ""     // the account's *.workers.dev prefix
  property var workerDomains: ({})         // script name -> custom hostname
  property var workerDotDev: ({})          // script name -> workers.dev enabled
  property var _dotDevQueue: []

  // --- analytics -----------------------------------------------------------
  property var analytics: emptyAnalytics()

  // --- status --------------------------------------------------------------
  property bool refreshing: false
  property bool analyticsRefreshing: false
  property double lastRefreshMs: 0
  property string lastError: ""
  property string actionStatus: ""
  property var projectDirs: ({})

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 60, 15, 3600)
  readonly property int analyticsIntervalSec: intSetting("analyticsIntervalSec", 900, 60, 7200)
  readonly property int deployRows: intSetting("deployRows", 8, 3, 30)
  // The overview shows a glance, not a log — the rest are one keypress away
  // under Workers or Pages.
  readonly property int overviewDeployRows: intSetting("overviewDeployRows", 3, 1, 10)
  readonly property int errorRatePercent: intSetting("errorRatePercent", 1, 1, 100)
  readonly property string projectsRoot: {
    var configured = String(setting("projectsRoot", "") || "").trim()
    return configured !== "" ? configured : Quickshell.env("HOME") + "/Projects"
  }
  // Zero means "no allowance configured", which renders the figure without a
  // percentage. Free-tier numbers were the original defaults and they lied on
  // a paid account, so nothing is assumed about the plan.
  readonly property var limits: ({
    workerRequestsPerDay: intSetting("workerRequestsPerDay", 0, 0, 1000000000),
    r2StorageGb: intSetting("r2StorageGb", 0, 0, 100000),
    d1RowsReadPerDay: intSetting("d1RowsReadPerDay", 0, 0, 100000000000)
  })

  readonly property bool busy: refreshing || analyticsRefreshing || refreshingToken
  readonly property int failedDeploys: Model.failedDeployCount(
    Model.buildDeploys(workers, pages, deployRows, null))
  readonly property bool warning: !loggedIn || failedDeploys > 0 || analytics.workersOverErrorRate > 0

  // Manifest `defaults` are never merged into the injected settings by the
  // shell, so every default is restated here. Changing one means changing both.
  function setting(name, fallback) {
    var settings = traySettings()
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
      perWorker: ({}), perBucket: ({}), perDatabase: ({}), perZone: ({})
    }
  }

  // Snapshot handed to Model.buildRows. Kept as a function rather than a
  // property so the panel controls when the ~70-row list is rebuilt.
  function resourceState() {
    return {
      workers: workers, pages: pages, buckets: buckets, databases: databases,
      namespaces: namespaces, queues: queues, zones: zones,
      errorRateThreshold: errorRatePercent,
      accountSubdomain: accountSubdomain, workerDomains: workerDomains,
      workerDotDev: workerDotDev
    }
  }

  // ------------------------------------------------------------- credentials

  // One watcher per candidate path. Each reports what it found; the merge
  // below decides which one is actually current.
  Instantiator {
    model: root.wranglerConfigPaths
    delegate: QtObject {
      required property string modelData
      readonly property FileView view: FileView {
        path: modelData
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.noteCredentials(modelData, text())
        onLoadFailed: root.noteCredentials(modelData, "")
      }
    }
  }

  property bool configLoaded: false
  property int credentialsSeen: 0

  function noteCredentials(path, text) {
    var next = {}
    for (var key in root.credentialCandidates) next[key] = root.credentialCandidates[key]
    next[path] = Api.parseWranglerConfig(text)
    root.credentialCandidates = next
    root.credentialsSeen++
    // Wait for every watcher to report once before judging, so a missing file
    // that happens to load first cannot declare the user logged out.
    if (root.credentialsSeen >= root.wranglerConfigPaths.length) root.configLoaded = true
    root.applyBestCredentials()
  }

  // Furthest-future expiry wins. A wrangler refresh writes one file and leaves
  // the other stale, and the stale one is not evidence of anything.
  function applyBestCredentials() {
    var best = null
    var bestPath = ""
    for (var path in root.credentialCandidates) {
      var candidate = root.credentialCandidates[path]
      if (!candidate || !candidate.token) continue
      if (!best || candidate.expiresMs > best.expiresMs) { best = candidate; bestPath = path }
    }

    if (!best) {
      if (root.configLoaded) {
        root.token = ""
        root.lastError = "wrangler is not logged in — run `wrangler login`"
      }
      return
    }

    var changed = best.token !== root.token
    root.token = best.token
    root.tokenExpiresMs = best.expiresMs
    root.tokenScopes = best.scopes
    root.credentialSource = bestPath
    if (root.lastError.indexOf("wrangler") >= 0 || root.lastError.indexOf("oauth_token") >= 0) root.lastError = ""
    // The watchers are the only thing that know a usable token has arrived —
    // whether from first load or from a wrangler refresh — so they own
    // restarting the work that was waiting on one.
    if (changed) Qt.callLater(function() { root.refresh() })
  }

  function tokenUsable() {
    // 120s of headroom: a token that expires mid-flight fails the whole sweep,
    // and the refresh costs one wrangler invocation an hour.
    return root.token !== "" && root.tokenExpiresMs > Date.now() + 120000
  }

  // Wrangler owns the OAuth refresh grant and rewrites default.toml when it
  // runs. Driving the refresh through it rather than reimplementing the grant
  // avoids racing wrangler's own writes to that file.
  Process {
    id: tokenRefresh
    command: ["wrangler", "whoami"]
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      root.refreshingToken = false
      if (exitCode !== 0) {
        root.lastError = "could not refresh the wrangler token"
        return
      }
      // The watchers pick up whichever file wrangler rewrote and resume the
      // sweep; there is no single file to reload by hand any more.
    }
  }

  property double lastAuthRecoveryMs: 0

  // Run wrangler to mint a fresh token. Rate limited, because a credential
  // wrangler cannot fix — a revoked grant, a logged-out account — would
  // otherwise spawn one process per refresh forever.
  function recoverAuth() {
    if (tokenRefresh.running) return false
    if (Date.now() - root.lastAuthRecoveryMs < 60000) return false
    root.lastAuthRecoveryMs = Date.now()
    root.refreshingToken = true
    tokenRefresh.running = true
    return true
  }

  function ensureToken() {
    // Before the config has been read once there is nothing to refresh — the
    // FileView's onLoaded starts the work instead.
    if (!root.configLoaded) return false
    if (root.token === "") return false
    // `expiration_time` is a hint, not a gate. `wrangler whoami` only rewrites
    // the config when the API actually rejects the token, so refusing to make
    // requests until the timestamp looks fresh livelocks the widget on stale
    // data whenever that timestamp is wrong. Nudge a refresh in the background
    // and send the request anyway; a genuine rejection is handled on the way
    // back, in isAuthFailure.
    if (!tokenUsable()) recoverAuth()
    return true
  }

  // Cloudflare reports an unusable credential a few different ways depending on
  // whether the gateway or the API rejected it.
  function isAuthFailure(env) {
    if (!env) return false
    if (env.code === 10000) return true
    var message = String(env.error || "").toLowerCase()
    return message.indexOf("invalid access token") >= 0
      || message.indexOf("authentication") >= 0
      || message.indexOf("unauthor") >= 0
      || message.indexOf("expired") >= 0
  }

  // ------------------------------------------------------------- fetching

  // One reusable request slot per endpoint. Each writes its curl config to
  // stdin, then drops stdin so curl sees EOF and proceeds; `stdinEnabled` is
  // re-armed before the next start because the channel state is read fresh
  // when the QProcess is created.
  component Request: Process {
    id: req
    property string url: ""
    property string body: ""
    property var handler: null
    property string configText: ""

    stdinEnabled: true
    stdout: StdioCollector { id: out; waitForEnd: true }
    stderr: StdioCollector { id: err; waitForEnd: true }

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
      write(configText)
      configText = ""
      // EOF, so `curl -K -` stops waiting for more config.
      stdinEnabled = false
    }

    onExited: function(exitCode) {
      var text = String(out.text || "")
      var errorText = String(err.text || "").trim()
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

  // Uniform completion handling. `label` names the endpoint in any error the
  // panel surfaces; `assign` receives the unwrapped result array.
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
          // wrangler owns the fix; applyCredentials restarts the sweep once the
          // new token lands in the config file.
          root.lastError = root.recoverAuth() ? "refreshing the wrangler token…" : label + ": " + env.error
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
    // One call covers every custom domain in the account; the per-script
    // workers.dev probe below only has to cover what is left over.
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
      // Zone ids are the analytics query's filter, so a zone list that arrives
      // after the query would leave zone traffic empty until the next tick.
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
      // Resolving the account is a prerequisite, not the refresh itself.
      Qt.callLater(function() { root.refresh() })
    }))
  }

  // ------------------------------------------------------- live URL probing

  // Whether a script answers on <name>.<subdomain>.workers.dev has no bulk
  // endpoint, so it costs one request per script. Scripts with a custom domain
  // never need asking, and an answer is cached for the session — enablement is
  // not something that changes minute to minute. The queue is drained one at a
  // time so this never competes with the refresh sweep for bandwidth.
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
      if (root.workerDomains[name]) continue          // custom domain wins anyway
      if (root.workerDotDev[name] !== undefined) continue  // already known
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

  // ------------------------------------------------------------- analytics

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

  // Collapse the GraphQL response into per-resource maps plus account totals.
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

    // r2StorageAdaptiveGroups reports a running maximum per bucket rather than
    // a delta, so the account total is the sum of the per-bucket maxima.
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

  // ------------------------------------------------------------- project scan

  Process {
    id: projectScan
    stdout: StdioCollector { id: scanOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.projectDirs = Api.parseProjectScan(String(scanOut.text || ""))
    }
  }

  function scanProjects() {
    if (projectScan.running) return
    projectScan.command = ["bash", "-c", Api.projectScanScript, root.projectsRoot]
    projectScan.running = true
  }

  function projectDirFor(name) {
    var dir = root.projectDirs[String(name || "")]
    return dir ? String(dir) : ""
  }

  // ------------------------------------------------------------- actions

  function notify(title, body) {
    var notif = root.shell ? root.shell.serviceFor("evo.notifications") : null
    if (notif && typeof notif.showBrief === "function")
      notif.showBrief(String(title), String(body || ""))
  }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["xdg-open", String(url)])
  }

  function runInTerminal(command) {
    Quickshell.execDetached(["ghostty", "-e", "bash", "-lc", String(command)])
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
    root.actionStatus = String(text || "")
    statusTimer.restart()
  }

  Timer {
    id: statusTimer
    interval: 2600
    onTriggered: root.actionStatus = ""
  }

  function tailWorker(name) {
    if (!name) return
    runInTerminal("wrangler tail " + Util.shellQuote(name))
    root.flashStatus("Tailing " + name)
  }

  function deployProject(name) {
    var dir = projectDirFor(name)
    if (dir === "") {
      notify("Cloudflare", "No local wrangler project found for " + name)
      return
    }
    runInTerminal("cd " + Util.shellQuote(dir) + " && wrangler deploy")
    root.flashStatus("Deploying " + name)
  }

  function rollbackProject(name) {
    var dir = projectDirFor(name)
    if (dir === "") {
      notify("Cloudflare", "No local wrangler project found for " + name)
      return
    }
    runInTerminal("cd " + Util.shellQuote(dir) + " && wrangler rollback")
    root.flashStatus("Rolling back " + name)
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
      // Expected: wrangler's OAuth grant has no cache-purge scope, so
      // Cloudflare answers 10000 "Authentication error". Reporting that
      // verbatim would send you looking for a broken login. The scope list is
      // right there in the config, so name the actual reason.
      if (root.isAuthFailure(env)) {
        root.flashStatus("Purge refused — the wrangler login has "
          + (root.tokenScopes.indexOf("zone:read") >= 0 ? "zone:read" : "no zone scope")
          + ", not Cache Purge. Press u here for the token page.")
        root.notify("Cloudflare", "Cache purge needs an API token with the Cache Purge permission.")
      } else {
        root.flashStatus("Purge failed: " + env.error)
      }
    })
  }

  // ------------------------------------------------------------- scheduling

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

  // A hung curl would otherwise wedge its slot forever, since every poll is
  // skipped while its own request is still running. curl's own --max-time is
  // the first line of defence; this is the backstop for a process that never
  // reports at all.
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
