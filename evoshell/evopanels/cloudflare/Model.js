// Formatting and row-shaping. Pure functions only — the panel renders whatever
// the build* functions return and holds no knowledge of Cloudflare's response
// shapes.
//
// Information architecture, after a first version that rendered all ninety-odd
// resources as one flat list:
//
//   overview   what is broken, what changed, what it is costing, and one
//              summary row per resource type
//   type view  everything of one kind, ordered by significance
//   search     one flat list across every kind, reachable from anywhere
//
// The overview never lists individual resources except the ones that are
// failing or that just deployed. Everything else is a count you drill into.

// ---------------------------------------------------------------- formatting

function formatBytes(bytes) {
  var n = Number(bytes)
  if (!isFinite(n) || n <= 0) return "0 B"
  var units = ["B", "KB", "MB", "GB", "TB", "PB"]
  var i = 0
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
  return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + " " + units[i]
}

function formatCount(value) {
  var n = Number(value)
  if (!isFinite(n)) return "—"
  if (n < 1000) return String(Math.round(n))
  if (n < 1000000) return (n / 1000).toFixed(n < 10000 ? 1 : 0) + "k"
  if (n < 1000000000) return (n / 1000000).toFixed(n < 10000000 ? 1 : 0) + "M"
  return (n / 1000000000).toFixed(1) + "B"
}

// Coarse on purpose: a deployment list is scanned, not read, so "3d" carries
// the same information as "3 days ago" in a third of the width.
function relativeTime(thenMs, nowMs) {
  var then = Number(thenMs)
  if (!isFinite(then) || then <= 0) return ""
  var delta = Math.max(0, Number(nowMs) - then)
  var minutes = Math.floor(delta / 60000)
  if (minutes < 1) return "just now"
  if (minutes < 60) return minutes + "m"
  var hours = Math.floor(minutes / 60)
  if (hours < 24) return hours + "h"
  var days = Math.floor(hours / 24)
  if (days < 30) return days + "d"
  var months = Math.floor(days / 30)
  if (months < 12) return months + "mo"
  return Math.floor(months / 12) + "y"
}

// Grouped digits for the hover text. The row itself shows "128k"; the tooltip
// is where the real number belongs.
function formatExact(value) {
  var n = Math.round(Number(value))
  if (!isFinite(n)) return "—"
  var sign = n < 0 ? "-" : ""
  var digits = String(Math.abs(n))
  var out = ""
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 === 0) out += ","
    out += digits[i]
  }
  return sign + out
}

function two(n) { return (n < 10 ? "0" : "") + n }

// "13 Aug 2026, 09:10". Local time, because that is the clock the user is
// comparing against when they wonder how long ago something shipped.
function absoluteTime(ms) {
  var t = Number(ms)
  if (!isFinite(t) || t <= 0) return ""
  var d = new Date(t)
  var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
  return d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear()
    + ", " + two(d.getHours()) + ":" + two(d.getMinutes())
}

function parseTime(value) {
  if (!value) return 0
  var ms = Date.parse(String(value))
  return isFinite(ms) ? ms : 0
}

// ---------------------------------------------------------------- glyphs

// Escapes rather than literal characters, and every codepoint checked against
// JetBrainsMono Nerd Font's cmap: a glyph the family lacks renders as a tofu
// box or, worse, as an unrelated character that looks deliberate. The first
// set here did the latter -- they all came out as a guillemet.
function glyphFor(kind) {
  switch (kind) {
  case "worker": return ""  // bolt
  case "pages":  return ""  // globe
  case "r2":     return ""  // archive
  case "d1":     return ""  // database
  case "kv":     return ""  // key
  case "queue":  return ""  // inbox
  case "zone":   return ""  // sitemap
  case "token":  return ""  // shield
  }
  return ""                 // cloud
}

// Plural label for a type, used as both the group row's name and the type
// view's title so the two can never disagree.
function typeLabel(kind) {
  switch (kind) {
  case "worker": return "Workers"
  case "pages":  return "Pages"
  case "r2":     return "R2 buckets"
  case "d1":     return "D1 databases"
  case "kv":     return "KV namespaces"
  case "queue":  return "Queues"
  case "zone":   return "Zones"
  case "token":  return "Create a token"
  }
  return kind
}

var RESOURCE_KINDS = ["worker", "pages", "r2", "d1", "kv", "queue", "zone"]

// ---------------------------------------------------------------- live URLs

// The address the thing actually serves on, mirroring what the Cloudflare
// dashboard prints under each application name.
//
// A custom domain always wins over the platform hostname: it is what the site
// is really called, and it is what you would paste to someone.
//
// `<name>.<subdomain>.workers.dev` is only offered when the account has told us
// that script has the subdomain route enabled. Assuming it would hand out dead
// links — a third of this account's Workers have it switched off.
function workerLiveHost(name, state) {
  var custom = state.workerDomains ? state.workerDomains[name] : ""
  if (custom) return String(custom)
  if (state.accountSubdomain && state.workerDotDev && state.workerDotDev[name] === true)
    return name + "." + state.accountSubdomain + ".workers.dev"
  return ""
}

function pagesLiveHost(project) {
  var domains = Array.isArray(project.domains) ? project.domains : []
  for (var i = 0; i < domains.length; i++) {
    var host = String(domains[i] || "")
    if (host && host.indexOf(".pages.dev") < 0) return host
  }
  return String(project.subdomain || (domains.length ? domains[0] : ""))
}

function hostToUrl(host) {
  var h = String(host || "").trim()
  if (!h) return ""
  return /^https?:\/\//.test(h) ? h : "https://" + h
}

// Name -> hostname for the two kinds that have deployments, so a deployment row
// can offer the same link as the resource row it refers to.
function buildLiveHosts(state) {
  var worker = {}
  var pages = {}
  var i
  for (i = 0; i < state.workers.length; i++) {
    var wn = String(state.workers[i].id || "")
    var wh = workerLiveHost(wn, state)
    if (wh) worker[wn] = wh
  }
  for (i = 0; i < state.pages.length; i++) {
    var ph = pagesLiveHost(state.pages[i])
    if (ph) pages[String(state.pages[i].name || "")] = ph
  }
  return { worker: worker, pages: pages }
}

// ---------------------------------------------------------------- deployments

// Workers and Pages report deployment state through different shapes. Both are
// normalized to {name, target, status, whenMs} so the panel sorts one list.
//
// A Worker's script record carries no build status — only when it last changed
// — so its status is always "deployed". Pages projects embed the real pipeline
// stage, which is where a failure actually shows up.
function buildDeploys(workers, pages, limit, liveHosts) {
  var rows = []
  var i

  for (i = 0; i < workers.length; i++) {
    var w = workers[i]
    var dhost = liveHosts ? String(liveHosts.worker[String(w.id || "")] || "") : ""
    rows.push({
      kind: "deploy",
      target: "worker",
      name: String(w.id || ""),
      status: "deployed",
      failed: false,
      via: String(w.last_deployed_from || ""),
      liveHost: dhost, liveUrl: hostToUrl(dhost),
      whenMs: parseTime(w.modified_on || w.created_on)
    })
  }

  for (i = 0; i < pages.length; i++) {
    var p = pages[i]
    var latest = p.latest_deployment
    var stage = latest && latest.latest_stage ? latest.latest_stage : null
    var status = stage ? String(stage.status || "") : "none"
    var dphost = liveHosts ? String(liveHosts.pages[String(p.name || "")] || "") : ""
    rows.push({
      kind: "deploy",
      target: "pages",
      name: String(p.name || ""),
      status: status,
      failed: status === "failure" || status === "canceled",
      building: status === "active" || status === "idle",
      via: stage ? String(stage.name || "") : "",
      liveHost: dphost, liveUrl: hostToUrl(dphost),
      whenMs: latest ? parseTime(latest.created_on) : 0
    })
  }

  rows.sort(function(a, b) { return b.whenMs - a.whenMs })
  var cap = Math.max(1, Number(limit) || 8)
  return rows.slice(0, cap)
}

function failedDeployCount(rows) {
  var n = 0
  for (var i = 0; i < rows.length; i++) if (rows[i].failed) n++
  return n
}

// ---------------------------------------------------------------- usage

// A usage row is either metered (has a limit, renders a bar) or a plain
// readout. Zone traffic has no account-level allowance to divide by, so it is
// reported as a number rather than a fake percentage.
function meterRow(id, title, used, limit, detail, tooltip) {
  var pct = limit > 0 ? used / limit : -1
  return {
    kind: "usage", id: id, title: title, metered: true,
    used: used, limit: limit, percent: pct, detail: detail || "",
    tooltip: tooltip || ""
  }
}

function valueRow(id, title, value, detail, tooltip) {
  return {
    kind: "usage", id: id, title: title, metered: false,
    value: value, percent: -1, detail: detail || "",
    tooltip: tooltip || ""
  }
}

// A meter when the user has told us their allowance, a plain readout when they
// have not. An allowance of 0 means "unset".
//
// The defaults used to be the free-tier numbers, which produced a red 143 GB /
// 10 GB = 1432% bar on a paid account. The figure was right and the
// denominator was fiction; a percentage against a guessed limit is worse than
// no percentage, so an unset allowance now shows the number and says how to
// turn it into a meter.
// The "set X for a meter" hint lives in the hover text, not in a row of its
// own. It is a one-time configuration note; giving it permanent space on a
// panel you read every day was the wrong trade.
function usageRow(id, title, used, limit, detail, hint, settingKey, unit) {
  var exact = formatExact(used) + (unit ? " " + unit : "")
  return limit > 0
    ? meterRow(id, title, used, limit, detail,
        exact + " of " + formatExact(limit) + (unit ? " " + unit : "")
        + " (" + Math.round((used / limit) * 100) + "%)")
    : valueRow(id, title, used, hint,
        exact + "  —  set " + settingKey + " in shell.json to show this as a meter")
}

function buildUsage(analytics, limits) {
  var rows = []
  if (!analytics || !analytics.loaded) return rows

  rows.push(usageRow(
    "worker-requests", "Worker requests, 24h",
    analytics.workerRequests, limits.workerRequestsPerDay,
    formatCount(analytics.workerRequests) + " / " + formatCount(limits.workerRequestsPerDay),
    formatCount(analytics.workerRequests),
    "workerRequestsPerDay", "requests"))

  var errorPct = analytics.workerRequests > 0
    ? (analytics.workerErrors / analytics.workerRequests) * 100
    : 0
  rows.push(valueRow(
    "worker-errors", "Worker errors, 24h", analytics.workerErrors,
    formatCount(analytics.workerErrors) + (analytics.workerRequests > 0 ? "  \u00b7  " + errorPct.toFixed(2) + "%" : ""),
    formatExact(analytics.workerErrors) + " errors from "
      + formatExact(analytics.workerRequests) + " requests in the last 24 hours"))

  var storageLimit = limits.r2StorageGb * 1024 * 1024 * 1024
  rows.push(usageRow(
    "r2-storage", "R2 storage",
    analytics.r2Bytes, storageLimit,
    formatBytes(analytics.r2Bytes) + " / " + limits.r2StorageGb + " GB",
    formatBytes(analytics.r2Bytes) + "  \u00b7  " + formatCount(analytics.r2Objects) + " objects",
    "r2StorageGb", "bytes"))

  rows.push(usageRow(
    "d1-reads", "D1 rows read, 24h",
    analytics.d1RowsRead, limits.d1RowsReadPerDay,
    formatCount(analytics.d1RowsRead) + " / " + formatCount(limits.d1RowsReadPerDay),
    formatCount(analytics.d1RowsRead) + " rows",
    "d1RowsReadPerDay", "rows"))

  return rows
}

// ---------------------------------------------------------------- resources

// Every resource of one kind, normalized to the row shape the panel renders.
// `weight` is the number the type view sorts by, so the busiest Worker and the
// biggest bucket come first instead of whatever the API happened to return.
function resourcesOf(kind, state, analytics) {
  var rows = []
  var i

  if (kind === "worker") {
    for (i = 0; i < state.workers.length; i++) {
      var w = state.workers[i]
      var wname = String(w.id || "")
      var wstats = analytics.perWorker[wname]
      var routes = Array.isArray(w.routes) ? w.routes.length : 0
      var whost = workerLiveHost(wname, state)
      rows.push({
        kind: "worker", name: wname, id: wname,
        liveHost: whost, liveUrl: hostToUrl(whost),
        weight: wstats ? wstats.requests : -1,
        detail: wstats
          ? formatCount(wstats.requests) + " req/24h" + (wstats.errors > 0 ? "  ·  " + formatCount(wstats.errors) + " err" : "")
          : (routes > 0 ? routes + (routes === 1 ? " route" : " routes") : "idle"),
        alarming: !!(wstats && wstats.errorRate >= state.errorRateThreshold),
        reason: wstats && wstats.errorRate >= state.errorRateThreshold
          ? wstats.errorRate.toFixed(1) + "% errors" : ""
      })
    }
  } else if (kind === "pages") {
    for (i = 0; i < state.pages.length; i++) {
      var p = state.pages[i]
      var stage = p.latest_deployment && p.latest_deployment.latest_stage
        ? p.latest_deployment.latest_stage : null
      var pfailed = !!(stage && (stage.status === "failure" || stage.status === "canceled"))
      var phost = pagesLiveHost(p)
      rows.push({
        kind: "pages", name: String(p.name || ""), id: String(p.id || ""),
        liveHost: phost, liveUrl: hostToUrl(phost),
        weight: p.latest_deployment ? parseTime(p.latest_deployment.created_on) : 0,
        detail: phost,
        alarming: pfailed,
        reason: pfailed ? "last build " + stage.status : ""
      })
    }
  } else if (kind === "r2") {
    for (i = 0; i < state.buckets.length; i++) {
      var b = state.buckets[i]
      var bname = String(b.name || "")
      var bstats = analytics.perBucket[bname]
      rows.push({
        kind: "r2", name: bname, id: bname,
        weight: bstats ? bstats.bytes : -1,
        detail: bstats
          ? formatBytes(bstats.bytes) + "  ·  " + formatCount(bstats.objects) + " objects"
          : String(b.location || "empty")
      })
    }
  } else if (kind === "d1") {
    for (i = 0; i < state.databases.length; i++) {
      var d = state.databases[i]
      var did = String(d.uuid || d.id || "")
      var dstats = analytics.perDatabase[did]
      rows.push({
        kind: "d1", name: String(d.name || ""), id: did,
        weight: dstats ? dstats.rowsRead : -1,
        detail: dstats
          ? formatCount(dstats.rowsRead) + " rows read/24h"
          : (d.file_size ? formatBytes(d.file_size) : "idle")
      })
    }
  } else if (kind === "kv") {
    for (i = 0; i < state.namespaces.length; i++) {
      var k = state.namespaces[i]
      rows.push({ kind: "kv", name: String(k.title || ""), id: String(k.id || ""), weight: 0, detail: "" })
    }
  } else if (kind === "queue") {
    for (i = 0; i < state.queues.length; i++) {
      var q = state.queues[i]
      var consumers = Array.isArray(q.consumers) ? q.consumers.length : 0
      rows.push({
        kind: "queue", name: String(q.queue_name || q.name || ""), id: String(q.queue_id || q.id || ""),
        weight: consumers,
        detail: consumers > 0 ? consumers + (consumers === 1 ? " consumer" : " consumers") : "no consumers"
      })
    }
  } else if (kind === "zone") {
    for (i = 0; i < state.zones.length; i++) {
      var z = state.zones[i]
      var zid = String(z.id || "")
      var zstats = analytics.perZone[zid]
      var zactive = String(z.status || "") === "active"
      rows.push({
        kind: "zone", name: String(z.name || ""), id: zid,
        liveHost: String(z.name || ""), liveUrl: hostToUrl(z.name),
        weight: zstats ? zstats.requests : -1,
        detail: zstats
          ? formatCount(zstats.requests) + " req/7d  ·  " + formatBytes(zstats.bytes)
          : String(z.status || ""),
        alarming: !zactive,
        reason: zactive ? "" : "zone is " + String(z.status || "inactive")
      })
    }
  }

  return rows
}

function allResources(state, analytics) {
  var all = []
  for (var i = 0; i < RESOURCE_KINDS.length; i++)
    all = all.concat(resourcesOf(RESOURCE_KINDS[i], state, analytics))
  return all
}

// Busiest and biggest first, falling back to name so the order is stable
// between polls when the weights tie (all the idle Workers, every KV namespace).
function bySignificance(a, b) {
  if (b.weight !== a.weight) return b.weight - a.weight
  return String(a.name).localeCompare(String(b.name))
}

function matchesFilter(row, filter) {
  if (!filter) return true
  var needle = filter.toLowerCase()
  return String(row.name || "").toLowerCase().indexOf(needle) >= 0
    || String(row.kind || "").toLowerCase().indexOf(needle) >= 0
    || String(row.detail || "").toLowerCase().indexOf(needle) >= 0
}

// ---------------------------------------------------------------- flattening

// Section headers are carried on the first row of each group rather than
// existing as rows of their own, so the cursor can never land on one.
function flatten(groups) {
  var rows = []
  for (var g = 0; g < groups.length; g++) {
    var group = groups[g]
    if (!group.rows || group.rows.length === 0) continue
    for (var i = 0; i < group.rows.length; i++) {
      var row = group.rows[i]
      row.section = group.title
      row.sectionTitle = i === 0 ? group.title : ""
      row.index = rows.length
      rows.push(row)
    }
  }
  return rows
}

// ---------------------------------------------------------------- overview

// One row per resource type: the count, an aggregate worth knowing, and a
// marker that there is something behind it. This is the row that replaced
// seventy individual resources.
function groupRow(kind, state, analytics) {
  var rows = resourcesOf(kind, state, analytics)
  var detail = ""
  var alarming = 0
  var i

  for (i = 0; i < rows.length; i++) if (rows[i].alarming) alarming++

  if (kind === "worker") detail = formatCount(analytics.workerRequests) + " req/24h"
  else if (kind === "r2") detail = formatBytes(analytics.r2Bytes)
  else if (kind === "d1") detail = formatCount(analytics.d1RowsRead) + " rows/24h"
  else if (kind === "zone") detail = formatCount(analytics.zoneRequests) + " req/7d"
  else if (kind === "queue") {
    var consumers = 0
    for (i = 0; i < rows.length; i++) consumers += Number(rows[i].weight) || 0
    detail = consumers + (consumers === 1 ? " consumer" : " consumers")
  }

  if (alarming > 0) detail = alarming + (alarming === 1 ? " needs attention" : " need attention")

  return {
    kind: "group", target: kind, name: typeLabel(kind),
    count: rows.length, detail: detail, alarming: alarming > 0
  }
}

function buildOverview(state, analytics, options) {
  var groups = []
  var i

  // Anything failing, listed by name. This is the only place the overview
  // names individual resources, because a count of broken things is not
  // actionable and the name is.
  var attention = []
  var everything = allResources(state, analytics)
  for (i = 0; i < everything.length; i++) {
    if (!everything[i].alarming) continue
    var row = everything[i]
    row.detail = row.reason || row.detail
    attention.push(row)
  }
  attention.sort(bySignificance)
  groups.push({ title: "NEEDS ATTENTION", rows: attention })

  groups.push({ title: "USAGE", rows: buildUsage(analytics, options.limits) })

  var typeRows = []
  for (i = 0; i < RESOURCE_KINDS.length; i++) {
    var group = groupRow(RESOURCE_KINDS[i], state, analytics)
    if (group.count > 0) typeRows.push(group)
  }
  groups.push({ title: "RESOURCES", rows: typeRows })

  // Recent activity, trimmed hard. Eight deployments was a list; three is a
  // glance, and the rest are one keypress away under Workers or Pages.
  groups.push({
    title: "RECENT ACTIVITY",
    rows: buildDeploys(state.workers, state.pages, options.overviewDeployRows, buildLiveHosts(state))
  })

  groups.push({
    title: "",
    rows: [{
      kind: "group", target: "token", name: typeLabel("token"),
      count: options.tokenRows.length,
      detail: "account, user, R2, AI Gateway, Turnstile", alarming: false
    }]
  })

  return flatten(groups)
}

// ---------------------------------------------------------------- type view

function buildTypeView(kind, state, analytics, options) {
  if (kind === "token")
    return flatten([{ title: "CREATE A TOKEN", rows: options.tokenRows.slice() }])

  var rows = resourcesOf(kind, state, analytics)
  rows.sort(bySignificance)
  return flatten([{ title: typeLabel(kind).toUpperCase(), rows: rows }])
}

// ---------------------------------------------------------------- search

// Search reaches every resource from anywhere, which is what keeps the
// drill-down from becoming a maze: you never have to know which type something
// is in to get to it.
function buildSearch(state, analytics, options) {
  var matched = []
  var everything = allResources(state, analytics)
  for (var i = 0; i < everything.length; i++)
    if (matchesFilter(everything[i], options.filter)) matched.push(everything[i])
  matched.sort(bySignificance)

  if (matched.length === 0) {
    return flatten([{
      title: "SEARCH",
      rows: [{ kind: "empty", name: "Nothing matches “" + options.filter + "”", selectable: false }]
    }])
  }
  return flatten([{ title: matched.length + " MATCHES", rows: matched }])
}

// ---------------------------------------------------------------- entry point

function buildRows(state, analytics, options) {
  if (options.filter) return buildSearch(state, analytics, options)
  if (options.route) return buildTypeView(options.route, state, analytics, options)
  return buildOverview(state, analytics, options)
}

// Section boundaries, for jumps across a long list.
function sectionStarts(rows) {
  var starts = []
  for (var i = 0; i < rows.length; i++) if (rows[i].sectionTitle !== "") starts.push(i)
  return starts
}
