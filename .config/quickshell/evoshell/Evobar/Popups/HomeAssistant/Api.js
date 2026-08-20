// Home Assistant helper command builders and response parsing.

function statesCommand(home, configJson, fresh) {
    var cmd = ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "states", String(configJson || "{}")]
    if (fresh === true)
        cmd.push("fresh")
    return cmd
}

function snapshotCommand(home, entityId) {
    return ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "snapshot", String(entityId || "")]
}

function snapshotCacheBatchCommand(home, entityIdsJson) {
    return ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "snapshot-cache-batch", String(entityIdsJson || "[]")]
}

function lightCommand(home, entityId, action, brightnessPct) {
    var cmd = ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "light", String(entityId || ""), String(action || "")]
    if (brightnessPct !== undefined && brightnessPct !== null && String(brightnessPct) !== "")
        cmd.push(String(brightnessPct))
    return cmd
}

function lightColorCommand(home, entityId, red, green, blue, brightnessPct) {
    var cmd = ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "light", String(entityId || ""), "rgb", String(red), String(green), String(blue)]
    if (brightnessPct !== undefined && brightnessPct !== null && String(brightnessPct) !== "")
        cmd.push(String(brightnessPct))
    return cmd
}

function lightHueCommand(home, entityId, hue, brightnessPct) {
    var cmd = ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "light", String(entityId || ""), "hue", String(hue)]
    if (brightnessPct !== undefined && brightnessPct !== null && String(brightnessPct) !== "")
        cmd.push(String(brightnessPct))
    return cmd
}

function climateTempCommand(home, entityId, temperature) {
    return ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "climate", String(entityId || ""), "set-temp", String(temperature)]
}

function climateModeCommand(home, entityId, mode) {
    return ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "climate", String(entityId || ""), "set-mode", String(mode || "")]
}

function parseJson(text) {
    var raw = String(text || "").trim()
    if (raw === "")
        return { ok: false, error: "empty response" }
    try {
        return JSON.parse(raw)
    } catch (e) {
        return { ok: false, error: "unparseable response" }
    }
}

function fileUrl(path, updatedAt) {
    var p = String(path || "").trim()
    if (p === "")
        return ""
    var url = p.indexOf("file://") === 0 ? p : "file://" + p
    if (updatedAt !== undefined && updatedAt !== null && String(updatedAt) !== "")
        url += (url.indexOf("?") >= 0 ? "&" : "?") + "t=" + String(updatedAt)
    return url
}
