// Home Assistant helper command builders and response parsing.

function statesCommand(home, configJson) {
    return ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "states", String(configJson || "{}")]
}

function snapshotCommand(home, entityId) {
    return ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "snapshot", String(entityId || "")]
}

function lightCommand(home, entityId, action, brightnessPct) {
    var cmd = ["bash", String(home || "") + "/.local/bin/evo-bar-home-assistant", "light", String(entityId || ""), String(action || "")]
    if (brightnessPct !== undefined && brightnessPct !== null && String(brightnessPct) !== "")
        cmd.push(String(brightnessPct))
    return cmd
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

function fileUrl(path) {
    var p = String(path || "").trim()
    if (p === "")
        return ""
    if (p.indexOf("file://") === 0)
        return p
    return "file://" + p
}
