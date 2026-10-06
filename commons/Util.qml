pragma Singleton

import Quickshell
import QtQuick
import "."

Singleton {
    function fileUrl(path) {
        var value = String(path || "").trim()
        if (!value)
            return ""
        if (value.indexOf("file://") === 0)
            return value
        if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value))
            return value
        var parts = value.split("/")
        var encoded = []
        for (var i = 0; i < parts.length; i++) {
            if (parts[i] === "" && i === 0)
                encoded.push("")
            else if (parts[i] !== "")
                encoded.push(encodeURIComponent(parts[i]))
        }
        return "file://" + encoded.join("/")
    }

    function shellQuote(value) {
        var s = String(value || "")
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function isPlainObject(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value)
    }

    function clamp(value, min, max) {
        var n = Number(value)
        if (!isFinite(n))
            return min
        return Math.max(min, Math.min(max, n))
    }

    function alpha(c, opacity) {
        var a = clamp(opacity, 0, 1)
        if (!c)
            return Qt.rgba(0, 0, 0, a)
        if (typeof c === "string")
            c = Qt.color(c)
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function isVideoPath(path) {
        return /\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(String(path || ""))
    }

    function execDetached(command) {
        Quickshell.execDetached(["bash", "-lc", command])
    }

    // argv stays in positional parameters, so untrusted values are never re-tokenized.
    function execArgv(argv) {
        Quickshell.execDetached(["bash", "-lc", 'exec "$@"', "bash"].concat(argv))
    }

    function cloneJson(value) {
        if (value === undefined)
            return undefined
        return JSON.parse(JSON.stringify(value))
    }

    function localPath(url) {
        return String(url || "").replace(/^file:\/\//, "")
    }

    function deepMerge(base, override) {
        if (!isPlainObject(base))
            return override !== undefined ? override : base
        if (!isPlainObject(override))
            return base
        var out = ({})
        var key
        for (key in base)
            out[key] = base[key]
        for (key in override) {
            if (isPlainObject(base[key]) && isPlainObject(override[key])
                    && !Array.isArray(base[key]) && !Array.isArray(override[key]))
                out[key] = deepMerge(base[key], override[key])
            else
                out[key] = override[key]
        }
        return out
    }

    function stateDir(home) {
        var env = Quickshell.env("EVOSHELL_STATE")
        if (env && String(env).trim() !== "")
            return String(env).trim()
        var xdg = Quickshell.env("XDG_STATE_HOME")
        if (xdg && String(xdg).trim() !== "")
            return String(xdg).trim() + "/evoshell"
        return String(home || Quickshell.env("HOME") || "") + "/.local/state/evoshell"
    }

    function configDir(home) {
        var env = Quickshell.env("EVOSHELL_CONFIG")
        if (env && String(env).trim() !== "")
            return String(env).trim()
        var xdg = Quickshell.env("XDG_CONFIG_HOME")
        if (xdg && String(xdg).trim() !== "")
            return String(xdg).trim() + "/evoshell"
        return String(home || Quickshell.env("HOME") || "") + "/.config/evoshell"
    }

    function cacheDir(home) {
        var env = Quickshell.env("EVOSHELL_CACHE")
        if (env && String(env).trim() !== "")
            return String(env).trim()
        var xdg = Quickshell.env("XDG_CACHE_HOME")
        if (xdg && String(xdg).trim() !== "")
            return String(xdg).trim() + "/evoshell"
        return String(home || Quickshell.env("HOME") || "") + "/.cache/evoshell"
    }

    function statePath(home, relative) {
        return stateDir(home) + "/" + String(relative || "")
    }

    function cachePath(home, relative) {
        return cacheDir(home) + "/" + String(relative || "")
    }

    function configPath(home, relative) {
        return configDir(home) + "/" + String(relative || "")
    }

    function evoBinPath(home) {
        return String(home || Quickshell.env("HOME") || "") + "/.local/bin/evo"
    }

    function evoCommand(home, args) {
        var cmd = [evoBinPath(home)]
        if (Array.isArray(args)) {
            for (var i = 0; i < args.length; i++)
                cmd.push(String(args[i]))
        } else if (args !== undefined && args !== null && String(args) !== "") {
            cmd.push(String(args))
        }
        return cmd
    }

    function evoshellBinPath(home, shell) {
        var env = Quickshell.env("EVOSHELL_BIN")
        if (env && String(env).trim() !== "")
            return String(env).trim()
        if (shell && shell.evoshellBin)
            return String(shell.evoshellBin)
        return String(home || Quickshell.env("HOME") || "") + "/.local/lib/evoshell/bin"
    }

    function evoshellScript(home, shell, name) {
        var script = String(name || "")
        var root = Quickshell.env("EVOSHELL_ROOT") || ""
        if (root && String(root).trim() !== "")
            return String(root).trim() + "/bin/" + script
        return evoshellBinPath(home, shell) + "/" + script
    }

    function evoshellIpcCommand(home, shell, args) {
        var ipcArgs = ["ipc"]
        if (Array.isArray(args)) {
            for (var i = 0; i < args.length; i++)
                ipcArgs.push(String(args[i]))
        } else if (args !== undefined && args !== null && String(args) !== "") {
            ipcArgs.push(String(args))
        }
        return evoCommand(home, ipcArgs)
    }

    function hoverPanelCacheRead(shell, cacheKey) {
        if (!shell || !cacheKey)
            return null
        return shell.hoverPanelDataFor(String(cacheKey))
    }

    function hoverPanelCacheWrite(shell, cacheKey, json) {
        if (!shell || !cacheKey || !isPlainObject(json))
            return
        shell.setHoverPanelData(String(cacheKey), json)
    }

    function pinHoverPanelFromBarIfActive(shell, popupId) {
        if (!shell || !popupId)
            return false
        var id = String(popupId)
        if (shell.hoverPanelId !== id && !shell.isHoverPanelPinned(id))
            return false
        return shell.toggleHoverPanelPinFromBar(id)
    }

    function openBarPanelFromClick(shell, popupId, item, barPanel) {
        if (!shell || !popupId || typeof shell.openBarPanelFromClick !== "function")
            return false
        return shell.openBarPanelFromClick(popupId, item, barPanel) === true
    }

    function dismissHoverPanelFromBar(shell, popupId) {
        if (!shell || !popupId)
            return
        var id = String(popupId)
        shell.hoverLeave(id)
        if (shell.hoverPanelId === id)
            shell.hide(id)
    }

    function screenForOutput(outputName, fallbackOutput) {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null
        var output = String(outputName || "").trim()
        if (!output)
            output = String(fallbackOutput || "").trim()
        if (!output)
            return null
        for (var i = 0; i < screens.length; i++) {
            var screen = screens[i]
            if (screen && String(screen.name) === output)
                return screen
        }
        return null
    }

    function steamThemedIconName(name) {
        var value = String(name || "")
        if (value === "steam_icon_220" || value === "half-life2")
            return "half-life2"
        if (value === "steam_icon_2536520" || value === "diablo-2")
            return "diablo-2"
        return ""
    }

    function iconLookupNames(iconName) {
        var name = String(iconName || "").trim()
        if (name.slice(-8).toLowerCase() === ".desktop")
            name = name.slice(0, -8)
        if (!name)
            return []
        var lower = name.toLowerCase()
        if (lower === "cursor" || lower === "co.anysphere.cursor")
            return ["co.anysphere.cursor", "cursor", "Cursor"]
        if (lower === "evo.panels.player" || lower === "evoplayer")
            return ["audio-player", "multimedia-player", "spotify"]
        var names = [name]
        if (name !== lower)
            names.push(lower)
        return names
    }

    function papirusAppIconSource(iconName) {
        var name = String(iconName || "").trim()
        if (!name || name.indexOf("/") !== -1 || name.indexOf(" ") !== -1)
            return ""
        // Plugin ids (evo.panels.*) are not papirus filenames.
        if (name.indexOf(".") !== -1)
            return ""
        return fileUrl("/usr/share/icons/Papirus-Dark/64x64/apps/" + name + ".svg")
    }

    function normalizeIconSource(path) {
        var value = String(path || "").trim()
        if (!value)
            return ""
        return value.indexOf("file://") === 0 ? value : fileUrl(value)
    }

    function themedAppIconSource(iconName) {
        var name = String(iconName || "").trim()
        if (!name)
            return ""
        var path = Quickshell.iconPath(name, true)
        return path ? normalizeIconSource(path) : ""
    }

    function themedDesktopIconSource(iconName) {
        var themed = steamThemedIconName(iconName)
        if (!themed)
            return ""
        return themedAppIconSource(themed)
    }

    function iconSourceForName(iconName) {
        var name = String(iconName || "").trim()
        if (!name)
            return ""
        if (name.indexOf("/") !== -1)
            return name.indexOf("file://") === 0 ? name : fileUrl(name)

        var names = iconLookupNames(name)
        var i
        for (i = 0; i < names.length; i++) {
            var candidate = names[i]
            var themed = steamThemedIconName(candidate)
            if (themed) {
                var themedSrc = themedDesktopIconSource(candidate)
                if (themedSrc)
                    return themedSrc
            }
            var path = Quickshell.iconPath(candidate, true)
            if (path)
                return normalizeIconSource(path)
        }

        for (i = 0; i < names.length; i++) {
            var papirus = papirusAppIconSource(names[i])
            if (papirus)
                return papirus
        }

        var fallback = Quickshell.iconPath(name, "application-x-executable")
        return fallback ? normalizeIconSource(fallback) : ""
    }

    function execDetachedTui(cmd) {
        var argv = ["systemd-run", "--user", "--scope", "--collect", "--"]
        if (Array.isArray(cmd)) {
            for (var i = 0; i < cmd.length; i++)
                argv.push(String(cmd[i]))
        }
        Quickshell.execDetached(argv)
    }
}
