// Pure request-building and response-parsing helpers. No QML state lives here;
// Service.qml owns everything mutable and calls into this file for strings.

var API = "https://api.cloudflare.com/client/v4"
var DASH = "https://dash.cloudflare.com"

// ---------------------------------------------------------------- transport

// curl config text for `curl -K -`. Only the token travels this way: argv is
// world-readable through /proc/<pid>/cmdline, so anything secret must not go
// there. Request bodies are not secret and ride in argv, which avoids having
// to escape JSON into curl's config quoting rules.
function curlConfig(token, url) {
  // Boolean options are bare words here — curl's config parser rejects
  // `location = false` as trailing garbage. Not following redirects is the
  // default, so the option is simply absent.
  return [
    'silent',
    'show-error',
    'max-time = 25',
    'header = "Authorization: Bearer ' + token + '"',
    'header = "Accept: application/json"',
    'url = "' + url + '"'
  ].join("\n") + "\n"
}

// argv for a GET. The config arrives on stdin; see curlConfig.
function curlGet() {
  return ["curl", "-K", "-"]
}

// argv for a JSON POST.
function curlPost(body) {
  return ["curl", "-K", "-", "-X", "POST", "-H", "Content-Type: application/json", "--data-binary", body]
}

// Cloudflare wraps every REST response in {success, errors, result}. Returns a
// uniform shape so callers never branch on transport vs application failure.
function parseEnvelope(text) {
  var raw = String(text || "").trim()
  if (raw === "") return { ok: false, result: null, error: "empty response" }
  var parsed
  try {
    parsed = JSON.parse(raw)
  } catch (e) {
    return { ok: false, result: null, error: "unparseable response" }
  }
  if (parsed && parsed.success === true) return { ok: true, result: parsed.result, error: "" }
  var message = ""
  if (parsed && Array.isArray(parsed.errors) && parsed.errors.length > 0) {
    message = String(parsed.errors[0].message || "")
    if (parsed.errors[0].code) message += " (" + parsed.errors[0].code + ")"
  }
  return { ok: false, result: null, error: message || "request failed", code: parsed && Array.isArray(parsed.errors) && parsed.errors.length ? parsed.errors[0].code : 0 }
}

// GraphQL answers 200 with a top-level `errors` array instead of the REST
// envelope, so it needs its own unwrap.
function parseGraphql(text) {
  var raw = String(text || "").trim()
  if (raw === "") return { ok: false, data: null, error: "empty response" }
  var parsed
  try {
    parsed = JSON.parse(raw)
  } catch (e) {
    return { ok: false, data: null, error: "unparseable response" }
  }
  if (parsed && Array.isArray(parsed.errors) && parsed.errors.length > 0)
    return { ok: false, data: null, error: String(parsed.errors[0].message || "graphql error") }
  if (!parsed || !parsed.data) return { ok: false, data: null, error: "no data" }
  return { ok: true, data: parsed.data, error: "" }
}

// ---------------------------------------------------------------- endpoints

function accountsUrl() { return API + "/accounts?per_page=50" }
function zonesUrl() { return API + "/zones?per_page=50" }
function workersUrl(acc) { return API + "/accounts/" + acc + "/workers/scripts" }
// The Pages list endpoint rejects `per_page` outright ("Invalid list options
// provided"), unlike every other list endpoint here. It must stay bare.
function pagesUrl(acc) { return API + "/accounts/" + acc + "/pages/projects" }
function r2Url(acc) { return API + "/accounts/" + acc + "/r2/buckets?per_page=100" }
function d1Url(acc) { return API + "/accounts/" + acc + "/d1/database?per_page=100" }
function kvUrl(acc) { return API + "/accounts/" + acc + "/storage/kv/namespaces?per_page=100" }
function queuesUrl(acc) { return API + "/accounts/" + acc + "/queues" }

// Live URLs. Custom domains come back for the whole account in one call, which
// is the cheap half of the problem.
function workersDomainsUrl(acc) { return API + "/accounts/" + acc + "/workers/domains" }
function workersSubdomainUrl(acc) { return API + "/accounts/" + acc + "/workers/subdomain" }
// The expensive half: whether <name>.<subdomain>.workers.dev is actually served
// is per script, with no bulk endpoint. A script with it disabled would
// otherwise be given a link that 404s, so this has to be asked for each one.
function scriptSubdomainUrl(acc, name) {
  return API + "/accounts/" + acc + "/workers/scripts/" + encodeURIComponent(name) + "/subdomain"
}
function graphqlUrl() { return API + "/graphql" }
function purgeUrl(zoneId) { return API + "/zones/" + zoneId + "/purge_cache" }

// ---------------------------------------------------------------- graphql

function isoDay(ms) { return new Date(ms).toISOString().slice(0, 10) }
function isoStamp(ms) { return new Date(ms).toISOString().slice(0, 19) + "Z" }

// One query covering every dataset the panel meters. Batched because each
// GraphQL round trip costs about as much as the whole REST sweep.
//
// `zoneTag` is selected alongside the zone's groups: the zones array comes back
// in an unspecified order, so correlating by position would silently attribute
// one domain's traffic to another.
function usageQuery(accountId, zoneIds, nowMs) {
  var dayAgo = nowMs - 24 * 60 * 60 * 1000
  var weekAgo = nowMs - 7 * 24 * 60 * 60 * 1000
  var q = 'query{viewer{'
  q += 'accounts(filter:{accountTag:"' + accountId + '"}){'
  q += 'workersInvocationsAdaptive(limit:200,filter:{datetime_geq:"' + isoStamp(dayAgo) + '",datetime_leq:"' + isoStamp(nowMs) + '"})'
  q += '{sum{requests errors subrequests}dimensions{scriptName}}'
  q += 'r2StorageAdaptiveGroups(limit:100,filter:{datetime_geq:"' + isoStamp(dayAgo) + '",datetime_leq:"' + isoStamp(nowMs) + '"})'
  q += '{max{payloadSize objectCount}dimensions{bucketName}}'
  q += 'd1AnalyticsAdaptiveGroups(limit:100,filter:{datetime_geq:"' + isoStamp(dayAgo) + '",datetime_leq:"' + isoStamp(nowMs) + '"})'
  q += '{sum{readQueries writeQueries rowsRead rowsWritten}dimensions{databaseId}}'
  q += '}'
  if (zoneIds && zoneIds.length > 0) {
    var tags = zoneIds.map(function(id) { return '"' + id + '"' }).join(",")
    q += 'zones(filter:{zoneTag_in:[' + tags + ']}){zoneTag '
    q += 'httpRequests1dGroups(limit:60,filter:{date_geq:"' + isoDay(weekAgo) + '",date_leq:"' + isoDay(nowMs) + '"})'
    q += '{dimensions{date}sum{requests bytes cachedRequests threats}}'
    q += '}'
  }
  q += '}}'
  return JSON.stringify({ query: q })
}

// ---------------------------------------------------------------- dashboard

// The `?to=/:account/...` form makes the dashboard resolve the account itself,
// so these stay correct even for an account the plugin has not fetched yet.
function dashAccount(path) { return DASH + "/?to=/:account" + path }

function dashUrlFor(row) {
  if (!row) return DASH
  switch (row.kind) {
  case "worker":  return dashAccount("/workers/services/view/" + encodeURIComponent(row.name) + "/production")
  case "pages":   return dashAccount("/pages/view/" + encodeURIComponent(row.name))
  case "r2":      return dashAccount("/r2/default/buckets/" + encodeURIComponent(row.name))
  case "d1":      return dashAccount("/workers/d1/databases/" + encodeURIComponent(row.id))
  case "kv":      return dashAccount("/workers/kv/namespaces/" + encodeURIComponent(row.id))
  case "queue":   return dashAccount("/workers/queues/view/" + encodeURIComponent(row.id))
  case "zone":    return DASH + "/?to=/" + encodeURIComponent(row.name)
  case "token":   return row.url
  case "deploy":  return row.target === "pages"
    ? dashAccount("/pages/view/" + encodeURIComponent(row.name))
    : dashAccount("/workers/services/view/" + encodeURIComponent(row.name) + "/production")
  }
  return DASH
}

// Shortcuts to the pages that mint credentials. Every one of these is buried
// several clicks deep in the dashboard, which is the whole reason they are here.
//
// `kind` and `name` are what the row renderer reads. Leaving them off is why
// these first rendered with the fallback glyph and no subtitle.
function tokenShortcuts() {
  return [
    { kind: "token", id: "account-tokens", name: "Account API tokens", hint: "Workers, R2, D1 — account scoped", url: dashAccount("/api-tokens") },
    { kind: "token", id: "user-tokens",    name: "User API tokens",    hint: "Your personal token, inherits your roles", url: DASH + "/profile/api-tokens" },
    { kind: "token", id: "r2-tokens",      name: "R2 / S3 credentials", hint: "Access Key ID + Secret for S3 clients", url: dashAccount("/r2/api-tokens") },
    { kind: "token", id: "ai-gateway",     name: "AI Gateway",          hint: "Gateway settings and auth tokens", url: dashAccount("/ai/ai-gateway") },
    { kind: "token", id: "turnstile",      name: "Turnstile widgets",   hint: "Site key and secret key", url: dashAccount("/turnstile") }
  ]
}

// ---------------------------------------------------------------- scanning

// Emits `name<TAB>directory` for every wrangler config under $0. Run through
// `bash -c script "$root"` with the root as a positional argument — never
// interpolated into the script text.
var projectScanScript =
  'root="$0"\n' +
  '[ -d "$root" ] || exit 0\n' +
  'find "$root" -maxdepth 3 -type f \\( -name wrangler.toml -o -name wrangler.jsonc -o -name wrangler.json \\) \\\n' +
  '  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | while IFS= read -r f; do\n' +
  '  n=$(sed -n \'s/^[[:space:]]*"\\?name"\\?[[:space:]]*[:=][[:space:]]*"\\([^"]*\\)".*/\\1/p\' "$f" | head -1)\n' +
  '  [ -n "$n" ] && printf "%s\\t%s\\n" "$n" "$(dirname "$f")"\n' +
  'done\n'

function parseProjectScan(text) {
  var map = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split("\t")
    if (parts.length === 2 && parts[0] && parts[1]) map[parts[0]] = parts[1]
  }
  return map
}
