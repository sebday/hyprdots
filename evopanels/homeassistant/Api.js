// Home Assistant helper command builders and response parsing.

function evoshellBin(home, binOverride) {
    if (binOverride && String(binOverride).trim() !== "")
        return String(binOverride).trim()
    return String(home || "") + "/.local/lib/evoshell/bin"
}

function haScript(home, binOverride, name) {
    return evoshellBin(home, binOverride) + "/" + String(name || "")
}

function statesCommand(home, binOverride, configJson, fresh) {
    var cmd = [haScript(home, binOverride, "evo-bar-home-assistant"), "states", String(configJson || "{}")]
    if (fresh === true)
        cmd.push("fresh")
    return cmd
}

function lightCommand(home, binOverride, entityId, action, brightnessPct) {
    var cmd = [haScript(home, binOverride, "evo-bar-home-assistant"), "light", String(entityId || ""), String(action || "")]
    if (brightnessPct !== undefined && brightnessPct !== null && String(brightnessPct) !== "")
        cmd.push(String(brightnessPct))
    return cmd
}

function lightHueCommand(home, binOverride, entityId, hue, brightnessPct, saturationPct) {
    var cmd = [haScript(home, binOverride, "evo-bar-home-assistant"), "light", String(entityId || ""), "hue", String(hue)]
    if (brightnessPct !== undefined && brightnessPct !== null && String(brightnessPct) !== "")
        cmd.push(String(brightnessPct))
    if (saturationPct !== undefined && saturationPct !== null && String(saturationPct) !== "")
        cmd.push(String(saturationPct))
    return cmd
}

function climateTempCommand(home, binOverride, entityId, temperature) {
    return [haScript(home, binOverride, "evo-bar-home-assistant"), "climate", String(entityId || ""), "set-temp", String(temperature)]
}

function climateModeCommand(home, binOverride, entityId, mode) {
    return [haScript(home, binOverride, "evo-bar-home-assistant"), "climate", String(entityId || ""), "set-mode", String(mode || "")]
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
