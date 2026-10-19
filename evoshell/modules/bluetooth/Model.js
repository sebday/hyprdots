.pragma library

function isAddressLike(value) {
  return /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(String(value || "").trim())
}

function isUuidLike(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(value || "").trim())
}

function deviceLabel(device) {
  if (!device)
    return ""
  var alias = String(device.name || "").trim()
  var given = String(device.deviceName || "").trim()
  if (alias && !isAddressLike(alias) && !isUuidLike(alias))
    return alias
  if (given && !isAddressLike(given) && !isUuidLike(given))
    return given
  return alias || given || String(device.address || "")
}

function sameAdapter(device, adapter) {
  if (!adapter || !device)
    return false
  if (!device.adapter)
    return true
  var id = String(device.adapter.adapterId || "")
  var want = String(adapter.adapterId || "")
  if (id && want)
    return id === want
  return device.adapter === adapter
}

function deviceRow(device) {
  if (!device)
    return null
  var battery = Number(device.battery)
  return {
    address: String(device.address || ""),
    name: deviceLabel(device) || "Device",
    connected: device.connected === true,
    paired: device.paired === true || device.bonded === true,
    trusted: device.trusted === true,
    pairing: device.pairing === true,
    state: device.state !== undefined ? device.state : -1,
    batteryAvailable: device.batteryAvailable === true && isFinite(battery),
    battery: isFinite(battery) ? battery : 0
  }
}

function byName(a, b) {
  var left = String(a && a.name || "").toLowerCase()
  var right = String(b && b.name || "").toLowerCase()
  if (left < right)
    return -1
  if (left > right)
    return 1
  return String(a && a.address || "").localeCompare(String(b && b.address || ""))
}

function deviceLists(devices, adapter) {
  var connected = []
  var known = []
  var discovered = []
  var list = devices || []
  var i, row
  for (i = 0; i < list.length; i++) {
    if (!sameAdapter(list[i], adapter))
      continue
    row = deviceRow(list[i])
    if (!row || !row.address)
      continue
    if (row.connected)
      connected.push(row)
    else if (row.paired || row.trusted)
      known.push(row)
    else
      discovered.push(row)
  }
  connected.sort(byName)
  known.sort(byName)
  discovered.sort(byName)
  return { connected: connected, known: known, discovered: discovered }
}

function visibleSections(groups, discovering) {
  var out = []
  if (groups && groups.connected && groups.connected.length)
    out.push("connected")
  if (groups && groups.known && groups.known.length)
    out.push("known")
  if (discovering && groups && groups.discovered && groups.discovered.length)
    out.push("discovered")
  return out
}

function scrollRows(groups, discovering) {
  var rows = []
  var known = groups && groups.known ? groups.known : []
  var found = groups && groups.discovered ? groups.discovered : []
  var i
  for (i = 0; i < known.length; i++)
    rows.push({ dev: known[i], section: "known", indexInSection: i })
  if (discovering) {
    for (i = 0; i < found.length; i++)
      rows.push({ dev: found[i], section: "discovered", indexInSection: i })
  }
  return rows
}

function cloneMap(map) {
  var next = {}
  var key
  if (!map)
    return next
  for (key in map)
    next[key] = map[key]
  return next
}

function withPendingAction(map, address, action) {
  var next = cloneMap(map)
  if (!address)
    return next
  if (action)
    next[address] = action
  else
    delete next[address]
  return next
}

function pendingAction(map, address) {
  if (!map || !address)
    return ""
  return String(map[address] || "")
}
