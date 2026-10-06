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

function contributionLevel(count) {
  var n = parseInt(count, 10) || 0
  if (n >= 30) return 4
  if (n >= 18) return 3
  if (n >= 10) return 2
  if (n >= 1) return 1
  return 0
}

function contributionColor(count, colors) {
  var palette = colors && colors.length ? colors : []
  var level = contributionLevel(count)
  return palette[level] || palette[1] || palette[0] || ""
}

function trendLevel(count, max) {
  var n = parseInt(count, 10) || 0
  var cap = parseInt(max, 10) || 40
  if (n <= 0) return 0
  return Math.max(1, Math.min(7, Math.ceil(n / cap * 7)))
}

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

function enrichCells(cells) {
  var out = []
  var today = new Date()
  today.setHours(0, 0, 0, 0)

  for (var i = 0; i < cells.length; i++) {
    var cell = cells[i] || {}
    var daysAgo = cells.length - 1 - i
    var date = new Date(today)
    date.setDate(date.getDate() - daysAgo)
    var iso = date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())

    out.push({
      level: cell.level,
      count: cell.count,
      color: cell.color,
      date: cell.date || iso
    })
  }

  return out
}

function formatCellTooltip(date, count) {
  var n = parseInt(count, 10) || 0
  var label = n === 1 ? "contribution" : "contributions"
  if (!date) return n + " " + label

  var parts = String(date).split("-")
  if (parts.length !== 3) return n + " " + label

  var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  return months[d.getMonth()] + " " + d.getDate() + " · " + n + " " + label
}

function parsePayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return { ok: false, error: "No data" }

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "Invalid response" }
  }

  if (json.class === "error") {
    return {
      ok: false,
      error: String(json.tooltip || json.text || "GitHub error").replace(/<[^>]+>/g, "").trim()
    }
  }

  var cells = Array.isArray(json.cells) ? json.cells : []
  var total30 = parseInt(json.total30, 10) || 0
  var streak = parseInt(json.streak, 10) || 0
  var best = parseInt(json.best, 10) || 0

  if (total30 === 0 && cells.length > 0) {
    var sum = 0
    var bestDay = 0
    for (var i = 0; i < cells.length; i++) {
      var c = parseInt(cells[i].count, 10) || 0
      sum += c
      if (c > bestDay) bestDay = c
    }
    total30 = sum
    if (best === 0) best = bestDay
  }

  if (streak === 0 && cells.length > 0) {
    for (var s = cells.length - 1; s >= 0; s--) {
      if ((parseInt(cells[s].count, 10) || 0) > 0) streak++
      else break
    }
  }

  return {
    ok: true,
    today: parseInt(json.today, 10) || 0,
    total30: total30,
    streak: streak,
    best: best,
    username: String(json.username || ""),
    profileUrl: String(json.profileUrl || (json.username ? ("https://github.com/" + json.username) : "https://github.com/")),
    cells: enrichCells(cells)
  }
}

function sparkBars(cells, colors, trendMax) {
  var out = []
  var max = parseInt(trendMax, 10) || 40
  for (var i = 0; i < cells.length; i++) {
    var cell = cells[i] || {}
    var count = parseInt(cell.count, 10) || 0
    out.push({
      value: count,
      level: trendLevel(count, max),
      color: cell.color || contributionColor(count, colors)
    })
  }
  return out
}

function parseRepoPayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return { ok: false, error: "No data", repos: [], unconfigured: false, repoRoots: [] }

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "Invalid response", repos: [], unconfigured: false, repoRoots: [] }
  }

  if (json.ok !== true) {
    return {
      ok: false,
      error: String(json.error || "Scan failed"),
      repos: [],
      unconfigured: false,
      repoRoots: []
    }
  }

  var repos = Array.isArray(json.repos) ? json.repos : []
  var repoRoots = Array.isArray(json.repoRoots) ? json.repoRoots : []
  return {
    ok: true,
    repos: repos,
    error: "",
    unconfigured: json.unconfigured === true,
    repoRoots: repoRoots
  }
}

function parseRepoDetectPayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return { ok: false, error: "No data", candidates: [] }

  try {
    var json = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "Invalid response", candidates: [] }
  }

  if (json.ok !== true) {
    return {
      ok: false,
      error: String(json.error || "Detect failed"),
      candidates: []
    }
  }

  var candidates = Array.isArray(json.candidates) ? json.candidates : []
  var out = []
  for (var i = 0; i < candidates.length; i++) {
    var item = candidates[i] || {}
    if (item.exists !== true) continue
    out.push({
      path: String(item.path || ""),
      label: String(item.label || ""),
      exists: true,
      selected: true
    })
  }
  return { ok: true, candidates: out, error: "" }
}

function repoRootLabels(roots) {
  if (!roots || !(roots instanceof Array)) return []
  var labels = []
  for (var i = 0; i < roots.length; i++) {
    var root = roots[i]
    if (!root) continue
    var label = String(root.label || "").trim()
    if (!label && root.path) {
      var parts = String(root.path).split("/")
      label = parts[parts.length - 1] || ""
    }
    if (label) labels.push(label)
  }
  return labels
}

function repoCleanMessage(roots) {
  var labels = repoRootLabels(roots)
  if (labels.length === 0)
    return "No repo folders configured"
  return "All clean in ~/" + labels.join(", ~/")
}

function repoStatusLabel(repo) {
  if (!repo) return ""
  if (repo.status) return String(repo.status)
  var parts = []
  if (repo.unstaged) parts.push("dirty")
  var unpushed = parseInt(repo.unpushed, 10) || 0
  if (unpushed > 0) parts.push(unpushed + " unpushed")
  return parts.join(" · ")
}

function repoTotals(repos) {
  var dirtyRepos = 0
  var unpushedRepos = 0
  if (!repos || !(repos instanceof Array)) {
    return { dirtyRepos: 0, unpushedRepos: 0 }
  }
  for (var i = 0; i < repos.length; i++) {
    var r = repos[i]
    if (!r) continue
    if (r.unstaged) dirtyRepos++
    if ((parseInt(r.unpushed, 10) || 0) > 0) unpushedRepos++
  }
  return { dirtyRepos: dirtyRepos, unpushedRepos: unpushedRepos }
}

function unstagedPillLabel(count) {
  var n = parseInt(count, 10) || 0
  return n + (n === 1 ? " unstaged" : " unstaged")
}

function unpushedPillLabel(count) {
  var n = parseInt(count, 10) || 0
  return n + (n === 1 ? " push" : " pushes")
}

function shortRemote(url) {
  var value = String(url || "").trim()
  if (!value) return ""
  return value
    .replace(/^git@github\.com:/, "")
    .replace(/^https?:\/\/github\.com\//, "")
    .replace(/\.git$/, "")
}

function repoDetailItems(repo) {
  if (!repo) return []

  var items = []
  if (repo.branch) items.push({ label: "Branch", value: String(repo.branch) })
  var remote = shortRemote(repo.remote)
  if (remote) items.push({ label: "Remote", value: remote })
  if (repo.lastCommit) items.push({ label: "Last commit", value: String(repo.lastCommit) })
  if (repo.path) items.push({ label: "Path", value: String(repo.path) })
  return items
}
