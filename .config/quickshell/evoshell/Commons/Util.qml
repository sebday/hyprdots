pragma Singleton

import Quickshell
import QtQuick
import "."

Singleton {
    function fileUrl(path) {
        var value = String(path || "").trim()
        if (!value) return ""
        if (value.indexOf("file://") === 0) return value
        return "file://" + value
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

    function normalizeIconSource(path) {
        var value = String(path || "").trim()
        if (!value)
            return ""
        return value.indexOf("file://") === 0 ? value : fileUrl(value)
    }

    function themedDesktopIconSource(iconName) {
        var themed = steamThemedIconName(iconName)
        if (!themed)
            return ""
        var home = Quickshell.env("HOME") || ""
        var theme = Theme.iconThemeName
        if (home && theme)
            return fileUrl(home + "/.local/share/icons/" + theme + "/apps/64/" + themed + ".svg")
        var path = Quickshell.iconPath(themed, true)
        return path ? normalizeIconSource(path) : ""
    }

    function iconSourceForName(iconName) {
        var name = String(iconName || "").trim()
        if (!name)
            return ""
        if (name.indexOf("/") !== -1)
            return name.indexOf("file://") === 0 ? name : fileUrl(name)

        var themed = steamThemedIconName(name)
        if (themed) {
            var themedSrc = themedDesktopIconSource(name)
            if (themedSrc)
                return themedSrc
        }

        var path = Quickshell.iconPath(name, true)
        if (path)
            return normalizeIconSource(path)

        path = Quickshell.iconPath(name, "application-x-executable")
        if (path)
            return normalizeIconSource(path)

        return ""
    }
}
