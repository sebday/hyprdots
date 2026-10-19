
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

function typeName(kind) {
  switch (kind) {
  case "worker": return "Worker"
  case "pages":  return "Pages project"
  case "r2":     return "R2 bucket"
  case "d1":     return "D1 database"
  case "kv":     return "KV namespace"
  case "queue":  return "Queue"
  case "zone":   return "Zone"
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

// Name -> hostname for the two kinds that have deployments, so a deployment row
// shows the same address as the resource row it refers to.
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
      liveHost: dhost,
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
      liveHost: dphost,
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
        liveHost: whost, raw: w,
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
        liveHost: phost, raw: p,
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
        kind: "r2", name: bname, id: bname, raw: b,
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
        kind: "d1", name: String(d.name || ""), id: did, raw: d,
        weight: dstats ? dstats.rowsRead : -1,
        detail: dstats
          ? formatCount(dstats.rowsRead) + " rows read/24h"
          : (d.file_size ? formatBytes(d.file_size) : "idle")
      })
    }
  } else if (kind === "kv") {
    for (i = 0; i < state.namespaces.length; i++) {
      var k = state.namespaces[i]
      rows.push({ kind: "kv", name: String(k.title || ""), id: String(k.id || ""), raw: k, weight: 0, detail: "" })
    }
  } else if (kind === "queue") {
    for (i = 0; i < state.queues.length; i++) {
      var q = state.queues[i]
      var consumers = Array.isArray(q.consumers) ? q.consumers.length : 0
      rows.push({
        kind: "queue", name: String(q.queue_name || q.name || ""), id: String(q.queue_id || q.id || ""), raw: q,
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
        liveHost: String(z.name || ""), raw: z,
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

// ---------------------------------------------------------------- detail pane

function typeRows(kind, state, analytics) {
  var rows = resourcesOf(kind, state, analytics)
  rows.sort(bySignificance)
  return rows
}

function resourceFor(kind, name, state, analytics) {
  var rows = resourcesOf(kind, state, analytics)
  for (var i = 0; i < rows.length; i++)
    if (rows[i].name === name) return rows[i]
  return null
}

function stamp(value, nowMs) {
  var ms = parseTime(value)
  if (!ms) return ""
  var rel = relativeTime(ms, nowMs)
  return (rel === "just now" ? rel : rel + " ago") + "  \u00b7  " + absoluteTime(ms)
}

function listOf(values, pick) {
  if (!Array.isArray(values)) return ""
  var out = []
  for (var i = 0; i < values.length; i++) {
    var v = pick ? pick(values[i]) : values[i]
    if (v) out.push(String(v))
  }
  return out.join(", ")
}

function firstLine(value) {
  return String(value || "").split("\n")[0]
}

function addField(out, label, value, alarming) {
  var text = plain(value, 400)
  if (text === "") return
  out.push({ label: label, value: text, alarming: !!alarming })
}

// Label/value pairs for one resource row from resourcesOf. Missing values are
// dropped rather than shown as blanks, since the list endpoints leave a lot of
// fields out depending on how the resource was created.
function detailFields(row, state, analytics, nowMs) {
  var out = []
  if (!row) return out
  var raw = row.raw || {}
  if (row.reason) addField(out, "Attention", row.reason, true)

  if (row.kind === "worker") {
    var ws = analytics.perWorker[row.name]
    addField(out, "Live at", row.liveHost)
    if (ws) {
      addField(out, "Requests", formatExact(ws.requests) + " in 24h")
      addField(out, "Errors",
        formatExact(ws.errors) + (ws.requests > 0 ? "  \u00b7  " + ws.errorRate.toFixed(2) + "%" : ""),
        ws.errorRate >= state.errorRateThreshold)
    }
    addField(out, "Routes", listOf(raw.routes, function(r) { return typeof r === "string" ? r : (r && r.pattern) }))
    addField(out, "Deployed", stamp(raw.modified_on, nowMs))
    addField(out, "Deployed via", raw.last_deployed_from)
    addField(out, "Handlers", listOf(raw.handlers))
    addField(out, "Compatibility", raw.compatibility_date)
    addField(out, "Usage model", raw.usage_model)
    addField(out, "Created", stamp(raw.created_on, nowMs))
  } else if (row.kind === "pages") {
    var dep = raw.latest_deployment || {}
    var stage = dep.latest_stage || {}
    var meta = dep.deployment_trigger && dep.deployment_trigger.metadata ? dep.deployment_trigger.metadata : {}
    var src = raw.source && raw.source.config ? raw.source.config : {}
    addField(out, "Live at", row.liveHost)
    addField(out, "Domains", listOf(raw.domains))
    addField(out, "Last build", stage.name ? stage.name + "  \u00b7  " + stage.status : "", row.alarming)
    addField(out, "Deployed", stamp(dep.created_on, nowMs))
    addField(out, "Environment", dep.environment)
    addField(out, "Branch", meta.branch)
    addField(out, "Commit", meta.commit_hash
      ? String(meta.commit_hash).slice(0, 7) + "  " + firstLine(meta.commit_message)
      : firstLine(meta.commit_message))
    addField(out, "Production", raw.production_branch)
    addField(out, "Repository", src.owner && src.repo_name ? src.owner + "/" + src.repo_name : "")
    addField(out, "Created", stamp(raw.created_on, nowMs))
  } else if (row.kind === "r2") {
    var bs = analytics.perBucket[row.name]
    if (bs) {
      addField(out, "Size", formatBytes(bs.bytes))
      addField(out, "Objects", formatExact(bs.objects))
    }
    addField(out, "Location", raw.location)
    addField(out, "Storage class", raw.storage_class)
    addField(out, "Created", stamp(raw.creation_date, nowMs))
  } else if (row.kind === "d1") {
    var ds = analytics.perDatabase[row.id]
    if (ds) {
      addField(out, "Rows read", formatExact(ds.rowsRead) + " in 24h")
      addField(out, "Rows written", formatExact(ds.rowsWritten) + " in 24h")
    }
    addField(out, "Size", raw.file_size ? formatBytes(raw.file_size) : "")
    addField(out, "Version", raw.version)
    addField(out, "Created", stamp(raw.created_at, nowMs))
    addField(out, "ID", row.id)
  } else if (row.kind === "kv") {
    addField(out, "ID", row.id)
  } else if (row.kind === "queue") {
    var script = function(c) { return c && (c.script || c.service || c.script_name) }
    addField(out, "Producers", listOf(raw.producers, script))
    addField(out, "Consumers", listOf(raw.consumers, script) || "none")
    addField(out, "Created", stamp(raw.created_on, nowMs))
    addField(out, "ID", row.id)
  } else if (row.kind === "zone") {
    var zs = analytics.perZone[row.id]
    if (zs) {
      addField(out, "Requests", formatExact(zs.requests) + " in 7d")
      addField(out, "Bandwidth", formatBytes(zs.bytes) + " in 7d")
      addField(out, "Threats", formatExact(zs.threats) + " in 7d")
    }
    addField(out, "Name servers", listOf(raw.name_servers))
    addField(out, "Activated", stamp(raw.activated_on, nowMs))
  }
  return out
}

// ---------------------------------------------------------------- pills

// Pills carry a tone name rather than a colour so the panel keeps the palette:
// good, warn, bad, info, or "" for neutral.
function pill(text, tone) { return { text: String(text || ""), tone: tone || "" } }

// One verdict per probe. Anything that answers over HTTPS counts as up, even a
// 401 or 403: the site is serving, it just wants credentials. Hosts behind
// Access redirect to the team's login page and are labelled as such, and a
// host that forwards to another hostname (www to the apex) is a redirect
// rather than a site of its own.
function classifyHealth(exitCode, httpCode, finalUrl, host) {
  if (exitCode !== 0) {
    var reason = "error " + exitCode
    if (exitCode === 6) reason = "no DNS"
    else if (exitCode === 7) reason = "refused"
    else if (exitCode === 28) reason = "timeout"
    else if (exitCode === 35 || exitCode === 51 || exitCode === 58 || exitCode === 60) reason = "TLS"
    else if (exitCode === 47) reason = "redirects"
    return { state: "down", label: reason }
  }
  if (String(finalUrl || "").indexOf(".cloudflareaccess.com/") >= 0) return { state: "up", label: "access" }
  if (httpCode >= 500 || httpCode === 0) return { state: "down", label: httpCode ? String(httpCode) : "no answer" }
  var finalHost = String(finalUrl || "").replace(/^[a-z]+:\/\//i, "").split(/[/:?#]/)[0].toLowerCase()
  if (host && finalHost && finalHost !== String(host).toLowerCase() && httpCode < 400)
    return { state: "up", label: "redirect", target: finalHost }
  if (httpCode < 400 || httpCode === 401 || httpCode === 403) return { state: "up", label: String(httpCode) }
  return { state: "warn", label: String(httpCode) }
}

function healthPill(entry) {
  if (!entry) return pill("", "")
  if (entry.state === "checking") return pill("\u2026", "")
  if (entry.target) return pill(entry.label, "info")
  return pill(entry.label, entry.state === "up" ? "good" : entry.state === "warn" ? "warn" : "bad")
}

// Columns are fixed per kind so every row of a list has the same number of
// pills and they line up; an empty pill keeps its column's space.
function listPills(row, analytics, health, nowMs) {
  var h = row.liveHost ? healthPill(health[String(row.liveHost).toLowerCase()]) : pill("", "")
  var raw = row.raw || {}
  switch (row.kind) {
  case "worker": {
    var ws = analytics.perWorker[row.name]
    return [
      pill(ws ? formatCount(ws.requests) + " req" : "idle", ""),
      pill(ws && ws.errors > 0 ? formatCount(ws.errors) + " err" : "", row.alarming ? "bad" : "warn"),
      h
    ]
  }
  case "pages": {
    var dep = raw.latest_deployment || {}
    var stage = dep.latest_stage || {}
    var age = relativeTime(parseTime(dep.created_on), nowMs)
    return [
      pill(stage.status || "", row.alarming ? "bad" : stage.status === "success" ? "" : "info"),
      pill(age, ""),
      h
    ]
  }
  case "zone": {
    var zs = analytics.perZone[row.id]
    return [
      pill(zs ? formatCount(zs.requests) + " req" : "", ""),
      pill(zs ? formatBytes(zs.bytes) : "", ""),
      raw.status && raw.status !== "active" ? pill(raw.status, "bad") : h
    ]
  }
  case "r2": {
    var bs = analytics.perBucket[row.name]
    return [pill(bs ? formatBytes(bs.bytes) : "empty", ""), pill(bs ? formatCount(bs.objects) + " obj" : "", "")]
  }
  case "d1": {
    var ds = analytics.perDatabase[row.id]
    return [
      pill(ds ? formatCount(ds.rowsRead) + " reads" : "idle", ""),
      pill(raw.file_size ? formatBytes(raw.file_size) : "", "")
    ]
  }
  case "queue": {
    var consumers = Array.isArray(raw.consumers) ? raw.consumers.length : 0
    return [pill(consumers + (consumers === 1 ? " consumer" : " consumers"), consumers > 0 ? "" : "warn")]
  }
  }
  return []
}

// ---------------------------------------------------------------- zone checks

function hasUnderscoreLabel(name) {
  var labels = String(name || "").split(".")
  for (var i = 0; i < labels.length; i++)
    if (labels[i].charAt(0) === "_" || labels[i] === "*") return true
  return false
}

// Hostnames in a zone that could serve a website: A, AAAA and CNAME records,
// minus DKIM keys, wildcards and other underscore records. Proxied hosts come
// first because those are the ones the panel probes without being asked.
function webHosts(zone, dns) {
  var apex = String(zone && zone.name ? zone.name : "").toLowerCase()
  var seen = {}
  var out = []
  if (apex) { seen[apex] = out.length; out.push({ host: apex, proxied: true }) }
  var records = Array.isArray(dns) ? dns : []
  for (var i = 0; i < records.length; i++) {
    var r = records[i]
    if (r.type !== "A" && r.type !== "AAAA" && r.type !== "CNAME") continue
    var name = String(r.name || "").toLowerCase()
    if (!name || hasUnderscoreLabel(name)) continue
    if (seen[name] !== undefined) {
      if (r.proxied) out[seen[name]].proxied = true
      continue
    }
    seen[name] = out.length
    out.push({ host: name, proxied: !!r.proxied })
  }
  var head = out.slice(0, apex ? 1 : 0)
  var rest = out.slice(head.length)
  rest.sort(function(a, b) {
    if (a.proxied !== b.proxied) return a.proxied ? -1 : 1
    return a.host.localeCompare(b.host)
  })
  return head.concat(rest)
}

function pagesHosts(project) {
  var domains = project && Array.isArray(project.domains) ? project.domains : []
  var out = []
  for (var i = 0; i < domains.length; i++)
    if (domains[i]) out.push({ host: String(domains[i]).toLowerCase(), proxied: true })
  return out
}

function txtRecord(dns, name, prefix) {
  var records = Array.isArray(dns) ? dns : []
  for (var i = 0; i < records.length; i++) {
    var r = records[i]
    if (r.type !== "TXT" || String(r.name || "").toLowerCase() !== name) continue
    var content = String(r.content || "").replace(/^"|"$/g, "").replace(/"\s*"/g, "")
    if (content.toLowerCase().indexOf(prefix) === 0) return content
  }
  return ""
}

// Security posture from the zone's settings, DNSSEC state and email records.
// Each row is a label and one pill; the tone says whether it needs a look.
function securityChecks(zone, info) {
  if (!info) return []
  var s = info.settings || {}
  var out = []
  var apex = String(zone && zone.name ? zone.name : "").toLowerCase()

  if (s.ssl !== undefined) {
    var ssl = String(s.ssl)
    out.push({ label: "SSL mode", pill: pill(ssl === "strict" || ssl === "full_strict" ? "strict" : ssl,
      ssl === "strict" || ssl === "full_strict" ? "good" : ssl === "full" ? "warn" : "bad") })
  }
  if (s.min_tls_version !== undefined) {
    var tls = String(s.min_tls_version)
    out.push({ label: "Min TLS", pill: pill(tls, Number(tls) >= 1.2 ? "good" : "warn") })
  }
  if (s.always_use_https !== undefined)
    out.push({ label: "Always HTTPS", pill: pill(s.always_use_https, s.always_use_https === "on" ? "good" : "bad") })
  if (s.security_header !== undefined) {
    var hsts = s.security_header && s.security_header.strict_transport_security
      ? s.security_header.strict_transport_security : {}
    out.push({ label: "HSTS", pill: hsts.enabled
      ? pill(hsts.max_age >= 15552000 ? "on" : "short", hsts.max_age >= 15552000 ? "good" : "warn")
      : pill("off", "warn") })
  }
  if (info.dnssec) {
    var ds = String(info.dnssec.status || "disabled")
    out.push({ label: "DNSSEC", pill: pill(ds, ds === "active" ? "good" : "warn") })
  }
  if (s.security_level !== undefined)
    out.push({ label: "Security level", pill: pill(String(s.security_level).replace(/_/g, " "), s.security_level === "essentially_off" ? "warn" : "") })
  if (s.browser_check !== undefined)
    out.push({ label: "Browser check", pill: pill(s.browser_check, s.browser_check === "on" ? "good" : "warn") })

  if (apex && Array.isArray(info.dns) && info.dns.length > 0) {
    var spf = txtRecord(info.dns, apex, "v=spf1")
    var all = spf.match(/[-~?+]all\b/)
    out.push({ label: "SPF", pill: !spf ? pill("missing", "warn")
      : all ? pill(all[0], all[0] === "-all" || all[0] === "~all" ? "good" : "bad")
      : pill("no all", "warn") })
    var dmarc = txtRecord(info.dns, "_dmarc." + apex, "v=dmarc1")
    var policy = dmarc.match(/\bp=(\w+)/i)
    var p = policy ? policy[1].toLowerCase() : ""
    out.push({ label: "DMARC", pill: !dmarc ? pill("missing", "warn")
      : pill(p || "no policy", p === "reject" || p === "quarantine" ? "good" : "warn") })
  }
  return out
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
