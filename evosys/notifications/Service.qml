import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../../commons"
import "../../evopanels/notifications"

Scope {
    id: root

    property var shell: null
    property var activePopups: []
    property var popupHeights: ({})

    readonly property int popupGap: 10
    readonly property int popupMarginFromEdge: Theme.barHeight + 20
    readonly property string popupOutput: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        if (cfg && cfg.output)
            return String(cfg.output)
        var bar = shell && shell.shellConfig && shell.shellConfig.bar
        if (bar && bar.output)
            return String(bar.output)
        var screens = Quickshell.screens
        if (screens && screens.length > 0 && screens[0])
            return String(screens[0].name)
        return ""
    }
    readonly property bool popupOnTop: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        return cfg && String(cfg.position || "bottom") === "top"
    }
    readonly property var popupScreen: {
        var screens = Quickshell.screens
        if (!screens) return null
        for (var i = 0; i < screens.length; i++) {
            if (screens[i] && String(screens[i].name) === popupOutput)
                return screens[i]
        }
        return null
    }
    readonly property int durationMs: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        return Math.max(500, parseInt(cfg && cfg.durationMs, 10) || 3000)
    }

    readonly property bool shellLogsEnabled: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        var logs = cfg && cfg.shellLogs
        return !logs || logs.enabled !== false
    }
    readonly property int shellLogsPollMs: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        var logs = cfg && cfg.shellLogs
        return Math.max(2000, parseInt(logs && logs.pollIntervalMs, 10) || 5000)
    }
    readonly property int shellLogsDedupeSec: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        var logs = cfg && cfg.shellLogs
        return Math.max(30, parseInt(logs && logs.dedupeWindowSec, 10) || 300)
    }
    readonly property bool userJournalLogsEnabled: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        var logs = cfg && cfg.shellLogs
        return !logs || logs.userJournal !== false
    }

    property var shellLogFingerprints: ({})

    readonly property int historyMax: 50
    readonly property string historyPath: Util.statePath(Quickshell.env("HOME") || "", "notification-history.json")

    property var historyEntries: []
    property var hiddenSources: []
    property var hiddenIdentities: []
    property int unreadCount: 0

    FileView {
        id: historyFile
        path: root.historyPath
        watchChanges: false
        printErrors: false
        onLoaded: root.loadHistoryFromFile()
        onLoadFailed: {
            root.historyEntries = []
            root.hiddenSources = []
            root.hiddenIdentities = []
        }
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        onNotification: function(notification) {
            notification.tracked = true
            root.enqueuePopup(notification)
        }
    }

    function enqueuePopup(notification) {
        var entry = { notification: notification, key: Date.now() + Math.random() }
        if (isHyprshot(entry) || isEvoScreenshot(entry))
            entry.artRev = Date.now()

        var source = classifyNotification(entry)
        if (source)
            pushHistory(snapshotHistoryEntry(entry, source))

        activePopups = activePopups.concat([entry])
        scheduleDismiss(root.durationMs)
    }

    function showBrief(title, body, durationMs) {
        var titleStr = String(title || "")
        var next = []
        for (var i = 0; i < activePopups.length; i++) {
            var item = activePopups[i]
            if (item.local && !item.localMedia && String(item.title) === titleStr) continue
            next.push(item)
        }
        var briefEntry = {
            key: Date.now() + Math.random(),
            local: true,
            title: titleStr,
            body: String(body || ""),
            art: resolveNamedIcon(titleStr)
        }
        next.push(briefEntry)
        activePopups = next
        pushHistory(snapshotHistoryEntry(briefEntry, "system"))
        scheduleDismiss(Math.max(500, parseInt(durationMs, 10) || root.durationMs))
    }

    readonly property string logPath: (Quickshell.env("XDG_STATE_HOME")
        || ((Quickshell.env("HOME") || "") + "/.local/state")) + "/evoshell/notification-log.jsonl"

    function logEvent(event, detail) {
        var payload = {
            at: new Date().toISOString(),
            event: String(event || ""),
            detail: detail || {}
        }
        var line = JSON.stringify(payload)
        logProc.command = [
            "bash", "-lc",
            "mkdir -p $(dirname " + Util.shellQuote(logPath) + ") && printf '%s\\n' "
                + Util.shellQuote(line) + " >> " + Util.shellQuote(logPath)
        ]
        logProc.running = true
    }

    function mediaArtPath(path) {
        return notifyIconPath(path)
    }

    function showMedia(opts) {
        var o = opts || {}
        var titleStr = String(o.title || "Unknown")
        var artistStr = String(o.artist || "")
        var artPath = mediaArtPath(o.art || "")
        var timeout = Math.max(1000, parseInt(o.durationMs, 10) || root.durationMs)
        var appStr = String(o.app || "evo.panels.player")
        var trackPath = String(o.path || "")

        for (var j = 0; j < activePopups.length; j++) {
            var existing = activePopups[j]
            if (!existing || !existing.localMedia || String(existing.app || "") !== appStr)
                continue
            if (String(existing.path || "") === trackPath
                    && String(existing.title || "") === titleStr
                    && String(existing.body || "") === artistStr
                    && String(existing.art || "") === artPath)
                return false
        }

        var next = []
        var updated = false
        for (var i = 0; i < activePopups.length; i++) {
            var item = activePopups[i]
            if (item.localMedia && String(item.app || "") === appStr) {
                updated = true
                next.push({
                    key: item.key,
                    localMedia: true,
                    app: appStr,
                    title: titleStr,
                    body: artistStr,
                    art: artPath,
                    artRev: Date.now(),
                    path: trackPath
                })
                continue
            }
            next.push(item)
        }
        if (!updated) {
            next.push({
                key: appStr + ":" + Date.now(),
                localMedia: true,
                app: appStr,
                title: titleStr,
                body: artistStr,
                art: artPath,
                artRev: Date.now(),
                path: trackPath
            })
        }
        activePopups = next
        scheduleDismiss(timeout)
        logEvent("showMedia", {
            app: appStr,
            title: titleStr,
            artist: artistStr,
            art: artPath.indexOf("data:image/") === 0 ? ("data-url:" + artPath.length) : artPath,
            path: trackPath,
            updated: updated
        })
        return true
    }

    function notifyIconPath(art) {
        var s = String(art || "")
        if (s.indexOf("data:image/") === 0)
            return s
        if (s.indexOf("file://") === 0) {
            try {
                s = decodeURIComponent(s.slice(7))
            } catch (e) {
                s = s.slice(7)
            }
        }
        if (s.charAt(0) === "/")
            return s
        return ""
    }

    function scheduleDismiss(intervalMs) {
        dismissTimer.interval = intervalMs
        dismissTimer.restart()
    }

    function dismissAll() {
        for (var i = 0; i < activePopups.length; i++) {
            var item = activePopups[i]
            if (item.notification) item.notification.dismiss()
        }
        activePopups = []
    }

    function dismissEntry(key) {
        var next = []
        for (var i = 0; i < activePopups.length; i++) {
            var item = activePopups[i]
            if (item.key !== key) next.push(item)
            else if (item.notification) item.notification.dismiss()
        }
        activePopups = next
    }

    function dismissOldest() {
        if (activePopups.length === 0)
            return
        dismissEntry(activePopups[0].key)
        if (activePopups.length > 0)
            scheduleDismiss(root.durationMs)
    }

    function loadHistoryFromFile() {
        var text = historyFile.text() || ""
        if (!text.trim()) {
            historyEntries = []
            hiddenSources = []
            hiddenIdentities = []
            unreadCount = 0
            return
        }
        try {
            var parsed = JSON.parse(text)
            var list = Array.isArray(parsed) ? parsed : (Array.isArray(parsed.entries) ? parsed.entries : [])
            historyEntries = list.slice(0, historyMax)
            hiddenSources = Array.isArray(parsed.hiddenSources) ? parsed.hiddenSources.slice() : []
            hiddenIdentities = Array.isArray(parsed.hiddenIdentities) ? parsed.hiddenIdentities.slice() : []
            for (var i = 0; i < historyEntries.length; i++) {
                var hiddenItem = historyEntries[i]
                if (hiddenItem && hiddenItem.hidden === true)
                    addHiddenIdentity(hiddenItem)
            }
            unreadCount = countUnread()
        } catch (e) {
            historyEntries = []
            hiddenSources = []
            hiddenIdentities = []
            unreadCount = 0
        }
    }

    function saveHistory() {
        var payload = JSON.stringify({
            version: 1,
            entries: historyEntries,
            hiddenSources: hiddenSources,
            hiddenIdentities: hiddenIdentities
        })
        saveProc.command = [
            "bash", "-lc",
            "mkdir -p $(dirname " + Util.shellQuote(historyPath) + ") && printf '%s' "
                + Util.shellQuote(payload) + " > " + Util.shellQuote(historyPath)
        ]
        saveProc.running = true
    }

    function countUnread() {
        var n = 0
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (!item || item.hidden === true || item.read === true)
                continue
            n++
        }
        return n
    }

    function pushHistory(item) {
        if (!item)
            return
        if (!item.hidden && shouldHideHistoryItem(item, item.source))
            item.hidden = true
        var next = [item]
        for (var i = 0; i < historyEntries.length; i++) {
            var existing = historyEntries[i]
            if (!existing || existing.key === item.key)
                continue
            next.push(existing)
            if (next.length >= historyMax)
                break
        }
        historyEntries = next
        unreadCount = countUnread()
        saveHistory()
    }

    function markAllRead() {
        if (historyEntries.length === 0)
            return
        var next = []
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (!item)
                continue
            var copy = ({})
            for (var k in item)
                copy[k] = item[k]
            copy.read = true
            next.push(copy)
        }
        historyEntries = next
        unreadCount = 0
        saveHistory()
    }

    function markEntryRead(key) {
        var id = String(key || "")
        if (!id)
            return
        var changed = false
        var next = []
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (!item) continue
            if (String(item.key) === id && item.read !== true) {
                var copy = ({})
                for (var k in item)
                    copy[k] = item[k]
                copy.read = true
                next.push(copy)
                changed = true
                continue
            }
            next.push(item)
        }
        if (!changed)
            return
        historyEntries = next
        unreadCount = countUnread()
        saveHistory()
    }

    function removeHistoryEntry(key) {
        var id = String(key || "")
        if (!id)
            return
        var next = []
        for (var i = 0; i < historyEntries.length; i++) {
            if (historyEntries[i] && String(historyEntries[i].key) !== id)
                next.push(historyEntries[i])
        }
        historyEntries = next
        unreadCount = countUnread()
        saveHistory()
    }

    function setHistoryEntryHidden(key, hidden) {
        var id = String(key || "")
        if (!id)
            return
        var wantHidden = hidden === true
        var changed = false
        var next = []
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (!item)
                continue
            if (String(item.key) !== id) {
                next.push(item)
                continue
            }
            if ((item.hidden === true) === wantHidden) {
                next.push(item)
                continue
            }
            var copy = ({})
            for (var k in item)
                copy[k] = item[k]
            copy.hidden = wantHidden
            if (wantHidden)
                copy.read = true
            next.push(copy)
            changed = true
        }
        if (!changed)
            return
        historyEntries = next
        unreadCount = countUnread()
        saveHistory()
    }

    function historyEntryForKey(key) {
        var id = String(key || "")
        if (!id)
            return null
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (item && String(item.key) === id)
                return item
        }
        return null
    }

    function historySourceForKey(key) {
        var item = historyEntryForKey(key)
        return item ? String(item.source || "") : ""
    }

    function entryIdentity(item) {
        if (!item)
            return ""
        var title = String(item.title || "").trim().toLowerCase()
        var app = String(item.appName || "").trim().toLowerCase()
        var desktop = String(item.desktopEntry || "").trim().toLowerCase()
        var appKey = app || desktop
        if (title && appKey)
            return title + "\x1f" + appKey
        if (title)
            return title
        if (appKey)
            return appKey
        return ""
    }

    function isIdentityHidden(item) {
        var id = entryIdentity(item)
        if (!id)
            return false
        for (var i = 0; i < hiddenIdentities.length; i++) {
            if (String(hiddenIdentities[i]) === id)
                return true
        }
        return false
    }

    function addHiddenIdentity(item) {
        var id = entryIdentity(item)
        if (!id)
            return false
        for (var i = 0; i < hiddenIdentities.length; i++) {
            if (String(hiddenIdentities[i]) === id)
                return false
        }
        hiddenIdentities = hiddenIdentities.concat([id])
        return true
    }

    function removeHiddenIdentity(item) {
        var id = entryIdentity(item)
        if (!id)
            return false
        var next = []
        var changed = false
        for (var i = 0; i < hiddenIdentities.length; i++) {
            if (String(hiddenIdentities[i]) === id) {
                changed = true
                continue
            }
            next.push(hiddenIdentities[i])
        }
        if (!changed)
            return false
        hiddenIdentities = next
        return true
    }

    function isSourceHidden(source) {
        var id = String(source || "")
        if (!id)
            return false
        for (var i = 0; i < hiddenSources.length; i++) {
            if (String(hiddenSources[i]) === id)
                return true
        }
        return false
    }

    function addHiddenSource(source) {
        var id = String(source || "")
        if (!id)
            return false
        for (var i = 0; i < hiddenSources.length; i++) {
            if (String(hiddenSources[i]) === id)
                return false
        }
        hiddenSources = hiddenSources.concat([id])
        return true
    }

    function removeHiddenSource(source) {
        var id = String(source || "")
        if (!id)
            return false
        var next = []
        var changed = false
        for (var i = 0; i < hiddenSources.length; i++) {
            if (String(hiddenSources[i]) === id) {
                changed = true
                continue
            }
            next.push(hiddenSources[i])
        }
        if (!changed)
            return false
        hiddenSources = next
        return true
    }

    function shouldHideHistoryItem(item, source) {
        if (isSourceHidden(source))
            return true
        return isIdentityHidden(item)
    }

    function isMessageSource(source) {
        var s = String(source || "")
        return s === "telegram" || s === "android"
    }

    function hideHistoryEntry(key) {
        var item = historyEntryForKey(key)
        if (item) {
            addHiddenIdentity(item)
            var source = String(item.source || "")
            if (isMessageSource(source)) {
                addHiddenSource("telegram")
                addHiddenSource("android")
            }
        }
        setHistoryEntryHidden(key, true)
    }

    function unhideHistoryEntry(key) {
        var item = historyEntryForKey(key)
        if (item) {
            removeHiddenIdentity(item)
            var source = String(item.source || "")
            if (isMessageSource(source)) {
                removeHiddenSource("telegram")
                removeHiddenSource("android")
            }
        }
        setHistoryEntryHidden(key, false)
    }

    function clearHistory() {
        var next = []
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (item && item.hidden === true)
                next.push(item)
        }
        historyEntries = next
        unreadCount = countUnread()
        saveHistory()
    }

    function isBraveNotification(n) {
        if (!n)
            return false
        var app = String(n.appName || "").toLowerCase()
        var entry = String(n.desktopEntry || "").toLowerCase()
        if (app.indexOf("brave") >= 0 || entry.indexOf("brave") >= 0)
            return true
        if (entry.indexOf("chrome-") === 0 || entry.indexOf("chromium") >= 0)
            return true
        return false
    }

    function webHostnameFromDesktopEntry(desktop) {
        var d = String(desktop || "").toLowerCase()
        var m = d.match(/^brave-([a-z0-9.-]+)__/)
        if (m && m[1])
            return m[1]
        m = d.match(/chrome-https\\172\\054([^\\]+)\\057/)
        if (m && m[1])
            return m[1].replace(/\\056/g, ".").replace(/\\054/g, ",")
        return ""
    }

    function webHostnameFromText(text) {
        var raw = String(text || "")
        var m = raw.match(/\b((?:[a-z0-9][-a-z0-9]*\.)+[a-z]{2,})\b/i)
        if (!m || !m[1])
            return ""
        var host = String(m[1]).toLowerCase()
        if (host === "brave.com" || host === "chromium.org")
            return ""
        return host
    }

    function webOpenUrlFromNotification(n) {
        if (!n)
            return ""
        var hints = n.hints
        if (hints) {
            var canonical = hints["x-canonical-uri"] || hints.xCanonicalUri || hints.canonical_uri
            if (canonical)
                return String(canonical)
        }
        var host = webHostnameFromDesktopEntry(n.desktopEntry)
        if (!host)
            host = webHostnameFromText(n.summary)
        if (!host)
            host = webHostnameFromText(n.body)
        if (!host)
            return ""
        if (host.indexOf("://") >= 0)
            return host
        return "https://" + host
    }

    function webWmClassFromUrl(url) {
        var raw = String(url || "").toLowerCase()
        if (!raw)
            return "brave-web"
        var host = raw.replace(/^https?:\/\//, "").replace(/\/.*$/, "")
        host = host.replace(/^www\./, "")
        host = host.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
        if (!host)
            return "brave-web"
        return "brave-" + host
    }

    function originSourceFromText(text) {
        var raw = String(text || "").toLowerCase()
        if (raw.indexOf("web.telegram.org") >= 0)
            return "telegram"
        if (raw.indexOf("messages.google.com") >= 0)
            return "android"
        return ""
    }

    function classifyNotification(entry) {
        if (!entry)
            return ""
        if (entry.localMedia)
            return ""
        if (entry.local)
            return "system"
        var n = entry.notification
        if (!n)
            return "system"

        var fromBody = originSourceFromText(stripMarkup(String(n.body || "")))
        if (fromBody)
            return fromBody

        var host = webHostnameFromDesktopEntry(n.desktopEntry)
        if (host.indexOf("telegram.org") >= 0)
            return "telegram"
        if (host.indexOf("messages.google.com") >= 0)
            return "android"

        var app = String(n.appName || "").toLowerCase()
        var desktop = String(n.desktopEntry || "").toLowerCase()
        if (app.indexOf("telegram") >= 0 || desktop.indexOf("telegram") >= 0)
            return "telegram"

        if (isBraveNotification(n))
            return "web"

        return "system"
    }

    function historyArtPath(entry) {
        var art = popupArt(entry)
        if (!art || String(art).indexOf("data:image/") === 0)
            return ""
        var path = notifyIconPath(art)
        return path || (String(art).charAt(0) === "/" ? String(art) : "")
    }

    function historyBodyText(entry, source) {
        var raw = stripMarkup(popupBody(entry)).replace(/\r/g, "")
        var parts = raw.split("\n")
        var lines = []
        for (var i = 0; i < parts.length; i++) {
            var line = parts[i].trim()
            if (line)
                lines.push(line)
        }
        if (isMessageSource(source) && lines.length > 1) {
            if (originSourceFromText(lines[0]))
                lines = lines.slice(1)
        }
        if (source === "web" && lines.length > 1) {
            if (webHostnameFromText(lines[0]))
                lines = lines.slice(1)
        }
        return lines.join("\n")
    }

    function snapshotHistoryEntry(entry, source) {
        if (!entry || !source)
            return null
        var n = entry.notification
        var openUrl = ""
        if (source === "telegram")
            openUrl = "https://web.telegram.org/"
        else if (source === "android")
            openUrl = "https://messages.google.com/web/"
        else if (source === "web")
            openUrl = webOpenUrlFromNotification(n)

        return {
            key: String(entry.key || (Date.now() + Math.random())),
            at: new Date().toISOString(),
            source: source,
            title: popupTitle(entry),
            body: historyBodyText(entry, source),
            appName: n ? String(n.appName || "") : String(entry.app || entry.title || ""),
            appIcon: n ? String(n.appIcon || "") : "",
            desktopEntry: n ? String(n.desktopEntry || "") : "",
            art: historyArtPath(entry),
            read: false,
            hidden: root.shouldHideHistoryItem({
                title: popupTitle(entry),
                appName: n ? String(n.appName || "") : String(entry.app || entry.title || ""),
                desktopEntry: n ? String(n.desktopEntry || "") : ""
            }, source),
            openUrl: openUrl
        }
    }

    function sourceLabel(source) {
        if (String(source || "") === "shell")
            return "Shell"
        if (String(source || "") === "journal")
            return "System"
        if (isMessageSource(source))
            return "Messages"
        if (String(source || "") === "web")
            return "Web"
        return "System"
    }

    function sourceIcon(source) {
        if (String(source || "") === "shell")
            return "󰒓"
        if (String(source || "") === "journal")
            return "󰍛"
        if (isMessageSource(source))
            return "󰍳"
        if (String(source || "") === "web")
            return "󰖟"
        return "󰂚"
    }

    function openHistoryEntry(item) {
        if (!item)
            return
        markEntryRead(item.key)
        var url = String(item.openUrl || "")
        if (!url)
            return
        var home = String(Quickshell.env("HOME") || "")
        var wm = "brave-web"
        if (item.source === "telegram")
            wm = "brave-telegram"
        else if (item.source === "android")
            wm = "brave-messages"
        else if (item.source === "web")
            wm = webWmClassFromUrl(url)
        var script = Util.evoshellScript(home, shell, "evo-bar-brave")
        Quickshell.execDetached(["bash", "-lc", script + " open " + wm + " " + Util.shellQuote(url)])
    }

    function shouldDedupeShellLog(fingerprint) {
        var fp = String(fingerprint || "")
        if (!fp)
            return false
        var now = Date.now()
        var seen = shellLogFingerprints[fp]
        if (typeof seen === "number" && (now - seen) < shellLogsDedupeSec * 1000)
            return true
        var next = ({})
        for (var k in shellLogFingerprints)
            next[k] = shellLogFingerprints[k]
        next[fp] = now
        shellLogFingerprints = next
        return false
    }

    function pushLogEntry(entry) {
        if (!entry)
            return
        var fp = String(entry.fingerprint || "")
        if (shouldDedupeShellLog(fp))
            return
        var source = String(entry.source || "shell")
        if (source !== "shell" && source !== "journal")
            source = "shell"
        pushHistory({
            key: source + ":" + fp + ":" + Date.now(),
            at: String(entry.at || new Date().toISOString()),
            source: source,
            title: String(entry.title || (source === "journal" ? "System warning" : "Shell warning")),
            body: String(entry.body || entry.message || ""),
            appName: source === "journal" ? "journal" : "evoshell",
            level: String(entry.level || "warning"),
            fingerprint: fp,
            read: false,
            hidden: false,
            openUrl: ""
        })
    }

    function pushShellLog(entry) {
        if (!entry)
            return
        entry.source = "shell"
        pushLogEntry(entry)
    }

    function pushJournalLog(entry) {
        if (!entry)
            return
        entry.source = "journal"
        pushLogEntry(entry)
    }

    function parseShellLogLines(text) {
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line)
                continue
            try {
                var parsed = JSON.parse(line)
                if (String(parsed.source || "") === "journal")
                    pushJournalLog(parsed)
                else
                    pushShellLog(parsed)
            } catch (e) {}
        }
    }

    function pollShellLogs() {
        if (!shellLogsEnabled || shellLogPoll.running)
            return
        var script = Util.evoshellScript(Quickshell.env("HOME") || "", shell, "evo-shell-log-watch")
        var prefix = userJournalLogsEnabled ? "" : "EVOSHELL_LOG_USER_JOURNAL=0 "
        shellLogPoll.command = ["bash", "-lc", prefix + Util.shellQuote(script) + " poll"]
        shellLogPoll.running = true
    }

    function popupTitle(entry) {
        if (!entry) return ""
        if (entry.localMedia) return String(entry.title || "")
        if (entry.local) return String(entry.title || "")
        if (entry.notification) return String(entry.notification.summary || entry.notification.appName || "")
        return ""
    }

    function popupBody(entry) {
        if (!entry) return ""
        if (entry.localMedia) return String(entry.body || "")
        if (entry.local) return String(entry.body || "")
        if (entry.notification) return String(entry.notification.body || "")
        return ""
    }

    function stripMarkup(text) {
        return String(text || "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<\/p>/gi, "\n")
            .replace(/<[^>]+>/g, "")
            .replace(/&nbsp;/g, " ")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;/g, "'")
    }

    function bodyLines(entry) {
        var raw = stripMarkup(popupBody(entry)).replace(/\r/g, "")
        var parts = raw.split("\n")
        var out = []
        for (var i = 0; i < parts.length; i++) {
            var line = parts[i].trim()
            if (line) out.push(line)
        }
        return out
    }

    function looksLikeImage(path) {
        var s = String(path || "")
        if (!s) return false
        if (s.indexOf("://") !== -1) return true
        if (s.charAt(0) === "/") return true
        return false
    }

    function imageSource(path) {
        return Util.fileUrl(path)
    }

    function resolveNamedIcon(name) {
        return Util.iconSourceForName(name)
    }

    function resolveNotificationIcon(entry) {
        if (!entry)
            return ""
        if (entry.art)
            return notifyIconPath(entry.art) || resolveNamedIcon(entry.art)
        var names = []
        var n = entry.notification
        if (n) {
            if (n.appIcon)
                names.push(n.appIcon)
            if (n.desktopEntry)
                names.push(n.desktopEntry)
            if (n.appName)
                names.push(n.appName)
        }
        if (entry.app)
            names.push(entry.app)
        var title = popupTitle(entry)
        if (title)
            names.push(title)
        for (var i = 0; i < names.length; i++) {
            var src = resolveNamedIcon(names[i])
            if (src)
                return src
        }
        return ""
    }

    function popupArt(entry) {
        if (entry && entry.localMedia && entry.art)
            return entry.art

        if (isHyprshot(entry) || isEvoScreenshot(entry))
            return screenshotPath(entry)

        var n = entry && entry.notification
        if (n && n.image) {
            var imagePath = notifyIconPath(n.image)
            if (imagePath) return imagePath
            if (looksLikeImage(n.image)) return String(n.image)
        }

        if (n && n.appIcon && looksLikeImage(n.appIcon)) {
            var iconPath = notifyIconPath(n.appIcon)
            if (iconPath) return iconPath
            return imageSource(n.appIcon)
        }

        if (entry && entry.local && entry.art) {
            var localArt = notifyIconPath(entry.art)
            if (localArt) return localArt
        }

        return resolveNotificationIcon(entry)
    }

    function popupImage(entry) {
        return popupArt(entry)
    }

    function popupIcon(entry) {
        var title = popupTitle(entry).trim().toLowerCase()
        var body = popupBody(entry).trim().toLowerCase()
        if (title.indexOf("error") !== -1 || body.indexOf("error") !== -1)
            return "󰅙"
        if (entry && entry.localMedia)
            return "󰎆"
        if (isPlayerNotification(entry) || isScrobbler(entry))
            return "󰎆"
        if (isHyprshot(entry) || isEvoScreenshot(entry))
            return "󰹑"
        return "󰂚"
    }

    function isScrobbler(entry) {
        var title = popupTitle(entry).toLowerCase()
        var app = String(entry && entry.notification && entry.notification.appName || "").toLowerCase()
        return title.indexOf("scrobbler") !== -1 || app.indexOf("scrobbler") !== -1
    }

    function isHyprshot(entry) {
        if (!entry || entry.local) return false
        var app = String(entry.notification && entry.notification.appName || "").toLowerCase()
        return app === "hyprshot"
    }

    function isEvoScreenshot(entry) {
        if (!entry || entry.local) return false
        var app = String(entry.notification && entry.notification.appName || "").toLowerCase()
        if (app !== "evoshell") return false
        var summary = popupTitle(entry).trim().toLowerCase()
        if (summary === "screenshot") return true
        if (summary.indexOf("screenshot") !== -1) return true
        if (summary.indexOf("capturing monitor") !== -1) return true
        if (summary.indexOf("no capture") !== -1) return true
        return false
    }

    function isPlayerNotification(entry) {
        if (!entry || entry.local) return false
        var app = String(entry.notification && entry.notification.appName || "").toLowerCase()
        return app === "evo.panels.player"
    }

    function normalizeLocalPath(path) {
        var s = String(path || "").trim()
        if (!s) return ""
        if (s.indexOf("file://") === 0) {
            try {
                s = decodeURIComponent(s.slice(7))
            } catch (e) {
                s = s.slice(7)
            }
        }
        if (s.charAt(0) !== "/") return ""
        return s
    }

    function screenshotPath(entry) {
        var n = entry && entry.notification
        if (!n) return "/tmp/evo-screenshot.png"

        var candidates = []
        var body = stripMarkup(String(n.body || "")).trim()
        var match = String(n.body || "").match(/<i>([^<]+)<\/i>/)
        if (match) candidates.push(match[1])
        if (body.charAt(0) === "/") candidates.push(body)
        if (n.image) candidates.push(n.image)
        if (n.appIcon) candidates.push(n.appIcon)
        var hints = n.hints
        if (hints) {
            var hintPath = hints["image-path"] || hints.imagePath
            if (hintPath) candidates.push(hintPath)
        }

        for (var i = 0; i < candidates.length; i++) {
            var p = normalizeLocalPath(candidates[i])
            if (p) return p
        }
        return "/tmp/evo-screenshot.png"
    }

    function openScreenshotEditor(entry) {
        if (!entry) return
        var home = String(Quickshell.env("HOME") || "")
        var script = home ? Util.evoshellScript(home, shell, "evo-screenshot") : "evo-screenshot"
        Quickshell.execDetached([script, "edit", screenshotPath(entry)])
        dismissEntry(entry.key)
    }

    function isMedia(entry) {
        if (!entry) return false
        if (entry.localMedia) return true
        if (entry.local) return false
        if (isPlayerNotification(entry)) return true
        if (isScrobbler(entry)) return true
        if (isHyprshot(entry)) return true
        if (isEvoScreenshot(entry)) return true
        return popupArt(entry) !== ""
    }

    function mediaKicker(entry) {
        var title = popupTitle(entry)
        var dot = title.lastIndexOf("•")
        if (dot !== -1)
            return title.slice(dot + 1).trim()
        return String(entry && entry.notification && entry.notification.appName || "")
    }

    function mediaFields(entry) {
        if (entry && (entry.localMedia || entry.local)) {
            return {
                kicker: "",
                title: String(entry.title || ""),
                subtitle: String(entry.body || ""),
                footer: ""
            }
        }
        var lines = bodyLines(entry)
        if (isPlayerNotification(entry)) {
            return {
                kicker: "Now playing",
                title: popupTitle(entry),
                subtitle: lines[0] || "",
                footer: ""
            }
        }
        if (isScrobbler(entry) && lines.length >= 2) {
            return {
                kicker: mediaKicker(entry),
                title: lines[1],
                subtitle: lines[0],
                footer: lines.slice(2).join(" · ")
            }
        }
        if (isHyprshot(entry)) {
            var shotPath = screenshotPath(entry)
            var shotName = shotPath.split("/").pop() || shotPath
            return {
                kicker: "",
                title: popupTitle(entry),
                subtitle: lines[0] || shotName,
                footer: ""
            }
        }
        if (isEvoScreenshot(entry)) {
            return {
                kicker: "",
                title: lines[0] || popupTitle(entry),
                subtitle: "",
                footer: ""
            }
        }
        var source = classifyNotification(entry)
        if (isMessageSource(source)) {
            var msgLines = bodyLines(entry)
            if (msgLines.length > 1 && originSourceFromText(msgLines[0]))
                msgLines = msgLines.slice(1)
            return {
                kicker: "",
                title: popupTitle(entry),
                subtitle: msgLines[0] || "",
                footer: "",
                subtitleFontSize: Theme.fontSizeM,
                subtitleOpacity: Theme.opacitySecondary
            }
        }
        var appName = String(entry && entry.notification && entry.notification.appName || "")
        var title = popupTitle(entry)
        return {
            kicker: (appName && appName !== title) ? appName : "",
            title: title,
            subtitle: lines[0] || "",
            footer: lines.slice(1).join(" · ")
        }
    }

    function entryKind(entry) {
        return "media"
    }

    function popupArtFillMode(entry) {
        if (isHyprshot(entry) || isEvoScreenshot(entry))
            return Image.PreserveAspectFit
        if (entry && entry.localMedia)
            return Image.PreserveAspectCrop
        if (isPlayerNotification(entry) || isScrobbler(entry))
            return Image.PreserveAspectCrop
        return Image.PreserveAspectFit
    }

    function estimatedHeight(entry) {
        return Theme.notificationArtSize + Theme.notificationMediaPad * 2
    }

    function measuredHeight(entry) {
        if (entry && typeof popupHeights[entry.key] === "number" && popupHeights[entry.key] > 0)
            return popupHeights[entry.key]
        return estimatedHeight(entry)
    }

    function setPopupHeight(key, height) {
        var h = Math.round(height)
        if (!key || popupHeights[key] === h)
            return
        var next = ({})
        for (var k in popupHeights)
            next[k] = popupHeights[k]
        next[key] = h
        popupHeights = next
    }

    readonly property var stackOffsets: {
        var list = activePopups
        var out = []
        var y = popupMarginFromEdge
        for (var i = 0; i < list.length; i++) {
            out.push(y)
            y += measuredHeight(list[i]) + popupGap
        }
        return out
    }

    function popupMarginLeft(screen) {
        if (!screen) return 0
        return Math.max(0, Math.round((screen.width - Theme.notificationWidth) / 2))
    }

    Timer {
        id: dismissTimer
        interval: root.durationMs
        repeat: false
        onTriggered: root.dismissOldest()
    }

    Process {
        id: logProc
    }

    Process {
        id: saveProc
    }

    Process {
        id: shellLogPoll
        stdout: StdioCollector {
            onStreamFinished: root.parseShellLogLines(text)
        }
    }

    Timer {
        id: shellLogTimer
        interval: root.shellLogsPollMs
        repeat: true
        running: root.shellLogsEnabled
        onTriggered: root.pollShellLogs()
        Component.onCompleted: Qt.callLater(root.pollShellLogs)
    }

    Component.onCompleted: historyFile.reload()

    Instantiator {
        model: root.activePopups
        active: true

        delegate: NotificationsToast {
            required property var modelData
            required property int index

            readonly property var media: root.mediaFields(modelData)
            readonly property string art: root.popupArt(modelData)

            entry: modelData
            stackIndex: index
            fields: media
            coverArt: art
            artRev: modelData ? (modelData.artRev || 0) : 0
            fallbackIcon: root.popupIcon(modelData)
            imageFillMode: root.popupArtFillMode(modelData)
            hyprshot: root.isHyprshot(modelData) || root.isEvoScreenshot(modelData)
            popupScreen: root.popupScreen
            popupOnTop: root.popupOnTop
            stackOffsets: root.stackOffsets
            popupMarginFromEdge: root.popupMarginFromEdge
            popupMarginLeft: root.popupMarginLeft(screen)

            onOpened: {
                if (modelData)
                    root.setPopupHeight(modelData.key, implicitHeight)
                var n = modelData && modelData.notification
                root.logEvent("popupOpen", {
                    art: art.indexOf("data:image/") === 0 ? ("data-url:" + art.length) : art,
                    artRev: modelData.artRev || 0,
                    title: media.title || "",
                    appName: n ? String(n.appName || "") : String(modelData.app || modelData.title || ""),
                    appIcon: n ? String(n.appIcon || "") : "",
                    desktopEntry: n ? String(n.desktopEntry || "") : ""
                })
            }

            onImplicitHeightChanged: if (modelData) root.setPopupHeight(modelData.key, implicitHeight)
            onDismissed: if (modelData) root.dismissEntry(modelData.key)
            onOpenScreenshot: if (modelData) root.openScreenshotEditor(modelData)
            onArtError: function(source) { root.logEvent("artError", { source: source }) }
            onArtReady: function(source) { root.logEvent("artReady", { source: source }) }
        }
    }
}
