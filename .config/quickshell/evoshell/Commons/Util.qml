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

    function hoverPopupCacheRead(shell, cacheKey) {
        if (!shell || !cacheKey)
            return null
        return shell.hoverPopupDataFor(String(cacheKey))
    }

    function hoverPopupCacheWrite(shell, cacheKey, json) {
        if (!shell || !cacheKey || !isPlainObject(json))
            return
        shell.setHoverPopupData(String(cacheKey), json)
    }

    function pinHoverPopupFromBarIfActive(shell, popupId) {
        if (!shell || !popupId)
            return false
        var id = String(popupId)
        if (shell.hoverPopupId !== id && !shell.isHoverPopupPinned(id))
            return false
        return shell.toggleHoverPopupPinFromBar(id)
    }

    function dismissHoverPopupFromBar(shell, popupId) {
        if (!shell || !popupId)
            return
        var id = String(popupId)
        shell.hoverLeave(id)
        if (shell.hoverPopupId === id)
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

    function barOutputName(shell, fallbackOutput) {
        if (shell && shell.barConfig && shell.barConfig.output)
            return String(shell.barConfig.output).trim()
        return String(fallbackOutput || "").trim()
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
        var names = [name]
        if (name !== lower)
            names.push(lower)
        return names
    }

    function papirusAppIconSource(iconName) {
        var name = String(iconName || "").trim()
        if (!name || name.indexOf("/") !== -1 || name.indexOf(" ") !== -1)
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
}
