import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../../Commons"

Scope {
    id: root

    property var shell: null
    property var activePopups: []
    property var popupHeights: ({})

    readonly property int popupGap: 10
    readonly property int popupMarginFromEdge: Theme.barHeight + 20
    readonly property string popupOutput: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        return cfg && cfg.output ? String(cfg.output) : "HDMI-A-1"
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
        if (isHyprshot(entry))
            entry.artRev = Date.now()
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
        next.push({
            key: Date.now() + Math.random(),
            local: true,
            title: titleStr,
            body: String(body || ""),
            art: resolveNamedIcon(titleStr)
        })
        activePopups = next
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
        var appStr = String(o.app || "evo.player")
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

        if (isHyprshot(entry))
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
        if (isHyprshot(entry))
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

    function isPlayerNotification(entry) {
        if (!entry || entry.local) return false
        var app = String(entry.notification && entry.notification.appName || "").toLowerCase()
        return app === "evo.player"
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
        if (!n) return "/tmp/hyprshot.png"

        var candidates = []
        var match = String(n.body || "").match(/<i>([^<]+)<\/i>/)
        if (match) candidates.push(match[1])
        if (n.appIcon) candidates.push(n.appIcon)
        if (n.image) candidates.push(n.image)

        for (var i = 0; i < candidates.length; i++) {
            var p = normalizeLocalPath(candidates[i])
            if (p) return p
        }
        return "/tmp/hyprshot.png"
    }

    function openScreenshotEditor(entry) {
        if (!entry) return
        var home = String(Quickshell.env("HOME") || "")
        var script = home ? home + "/.local/bin/evo-screenshot" : "evo-screenshot"
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
                kicker: "now playing",
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
                kicker: "screenshot",
                title: popupTitle(entry),
                subtitle: lines[0] || shotName,
                footer: ""
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
        if (isHyprshot(entry))
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

    component NotificationArtworkCard: Item {
        id: artworkRoot

        property string coverArt: ""
        property int artRev: 0
        property string fallbackIcon: "󰎆"
        property var fields: ({})
        property int artSize: Theme.notificationArtSize
        property bool blurredBackground: true
        property int imageFillMode: Image.PreserveAspectCrop

        readonly property string artSource: {
            if (!artworkRoot.coverArt)
                return ""
            if (artworkRoot.coverArt.indexOf("data:image/") === 0)
                return artworkRoot.coverArt
            var base = Util.fileUrl(artworkRoot.coverArt)
            if (!artworkRoot.artRev)
                return base
            var sep = base.indexOf("?") >= 0 ? "&" : "?"
            return base + sep + "rev=" + artworkRoot.artRev
        }

        width: Theme.notificationWidth
        implicitHeight: innerRow.height + Theme.notificationMediaPad * 2

        Image {
            visible: artworkRoot.blurredBackground && artworkRoot.artSource !== ""
            anchors.fill: parent
            source: artworkRoot.artSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0.18
        }

        Rectangle {
            visible: artworkRoot.blurredBackground && artworkRoot.artSource !== ""
            anchors.fill: parent
            color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.55)
        }

        Row {
            id: innerRow
            x: Theme.notificationPadding
            y: Theme.notificationMediaPad
            width: parent.width - Theme.notificationPadding * 2
            height: Math.max(artworkRoot.artSize, textCol.height)
            spacing: 16

            Item {
                width: artworkRoot.artSize
                height: artworkRoot.artSize
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                    radius: Theme.panelCornerRadius
                }

                Text {
                    anchors.centerIn: parent
                    visible: artworkRoot.artSource === "" || artImage.status !== Image.Ready
                    text: artworkRoot.fallbackIcon
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(artworkRoot.artSize * 0.45)
                    font.bold: Theme.fontBold
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    visible: artworkRoot.artSource !== "" && status === Image.Ready
                    source: artworkRoot.artSource
                    fillMode: artworkRoot.imageFillMode
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                    sourceSize: Qt.size(artworkRoot.artSize, artworkRoot.artSize)
                    onStatusChanged: {
                        if (status === Image.Error)
                            root.logEvent("artError", { source: artworkRoot.artSource })
                        else if (status === Image.Ready)
                            root.logEvent("artReady", { source: artworkRoot.artSource })
                    }
                }
            }

            Column {
                id: textCol
                width: parent.width - artworkRoot.artSize - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                Text {
                    width: parent.width
                    visible: artworkRoot.fields.kicker !== undefined && artworkRoot.fields.kicker !== ""
                    text: artworkRoot.fields.kicker || ""
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize4xl
                    font.bold: Theme.fontBold
                    font.letterSpacing: 1
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: Theme.opacityEmphasis
                }

                Text {
                    width: parent.width
                    text: artworkRoot.fields.title || ""
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize2xl
                    font.bold: Theme.fontBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    visible: artworkRoot.fields.subtitle !== undefined && artworkRoot.fields.subtitle !== ""
                    text: artworkRoot.fields.subtitle || ""
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeL
                    font.bold: Theme.fontBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: 0.82
                }

                Text {
                    width: parent.width
                    visible: artworkRoot.fields.footer !== undefined && artworkRoot.fields.footer !== ""
                    text: artworkRoot.fields.footer || ""
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize4xl
                    font.bold: Theme.fontBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: Theme.opacityMuted
                }
            }
        }
    }

    Instantiator {
        model: root.activePopups
        active: true

        delegate: PanelWindow {
            required property var modelData
            required property int index

            readonly property var media: root.mediaFields(modelData)
            readonly property string art: root.popupArt(modelData)

            Component.onCompleted: {
                if (modelData)
                    root.setPopupHeight(modelData.key, card.height)
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

            screen: root.popupScreen
            color: "transparent"
            implicitWidth: Theme.notificationWidth
            implicitHeight: card.height

            anchors.top: root.popupOnTop
            anchors.bottom: !root.popupOnTop
            anchors.left: true
            margins.top: root.popupOnTop
                ? (index < root.stackOffsets.length
                    ? root.stackOffsets[index]
                    : root.popupMarginFromEdge)
                : 0
            margins.bottom: root.popupOnTop
                ? 0
                : (index < root.stackOffsets.length
                    ? root.stackOffsets[index]
                    : root.popupMarginFromEdge)
            margins.left: root.popupMarginLeft(screen)

            onImplicitHeightChanged: if (modelData) root.setPopupHeight(modelData.key, implicitHeight)

            WlrLayershell.namespace: "evo-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Item {
                id: card
                width: Theme.notificationWidth
                height: artworkCard.implicitHeight
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.panelCornerRadius
                    color: Theme.overlaySurface
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.panelCornerRadius
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 2
                }

                NotificationArtworkCard {
                    id: artworkCard
                    coverArt: art
                    artRev: modelData.artRev || 0
                    fallbackIcon: root.popupIcon(modelData)
                    fields: media
                    imageFillMode: root.popupArtFillMode(modelData)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root.isHyprshot(modelData) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: function(mouse) {
                    if (!modelData) return
                    if (mouse.button === Qt.RightButton) {
                        root.dismissEntry(modelData.key)
                    } else if (mouse.button === Qt.LeftButton && root.isHyprshot(modelData)) {
                        root.openScreenshotEditor(modelData)
                    }
                }
            }
        }
    }
}
