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
            body: String(body || "")
        })
        activePopups = next
        scheduleDismiss(Math.max(500, parseInt(durationMs, 10) || root.durationMs))
    }

    function showMedia(opts) {
        var o = opts || {}
        var titleStr = String(o.title || "Unknown")
        var artistStr = String(o.artist || "")
        var iconPath = notifyIconPath(o.art || "")
        var timeout = Math.max(1000, parseInt(o.durationMs, 10) || root.durationMs)
        var appStr = String(o.app || "evo.player")

        if (publishProc.running)
            return false

        var cmd = ["notify-send", "-a", appStr, "-t", String(timeout)]
        if (iconPath)
            cmd.push("-i", iconPath)
        cmd.push(titleStr)
        if (artistStr)
            cmd.push(artistStr)
        publishProc.command = cmd
        publishProc.running = true
        return true
    }

    function notifyIconPath(art) {
        var s = String(art || "")
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
        dismissAll()
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
        var s = String(path || "")
        if (!s) return ""
        if (s.indexOf("://") !== -1) return s
        if (s.charAt(0) === "/") return "file://" + s
        return s
    }

    function popupImage(entry) {
        if (entry && entry.localMedia && entry.art)
            return imageSource(entry.art)
        var n = entry && entry.notification
        if (!n) return ""
        if (n.image) return imageSource(n.image)
        if (looksLikeImage(n.appIcon)) return imageSource(n.appIcon)
        return ""
    }

    function popupIcon(entry) {
        var title = popupTitle(entry).trim().toLowerCase()
        var body = popupBody(entry).trim().toLowerCase()
        if (title.indexOf("error") !== -1 || body.indexOf("error") !== -1)
            return "󰅙"
        if (isMedia(entry))
            return "󰎆"
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
        return popupImage(entry) !== ""
    }

    function mediaKicker(entry) {
        var title = popupTitle(entry)
        var dot = title.lastIndexOf("•")
        if (dot !== -1)
            return title.slice(dot + 1).trim()
        return String(entry && entry.notification && entry.notification.appName || "")
    }

    function mediaFields(entry) {
        if (entry && entry.localMedia) {
            return {
                kicker: String(entry.app || "evo.player"),
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
        return {
            kicker: mediaKicker(entry) || String(entry && entry.notification && entry.notification.appName || ""),
            title: popupTitle(entry),
            subtitle: lines[0] || "",
            footer: lines.slice(1).join(" · ")
        }
    }

    function entryKind(entry) {
        if (isMedia(entry)) return "media"
        return "default"
    }

    function estimatedHeight(entry) {
        var kind = entryKind(entry)
        if (kind === "media")
            return Theme.notificationArtSize + Theme.notificationMediaPad * 2
        return Theme.notificationPadding * 2 + Theme.fontSize2xl + 6 + Theme.fontSizeL
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
        id: publishProc
    }

    component NotificationArtworkCard: Item {
        id: artworkRoot

        property string art: ""
        property string fallbackIcon: "󰎆"
        property var fields: ({})
        property int artSize: Theme.notificationArtSize
        property bool blurredBackground: true

        width: Theme.notificationWidth
        implicitHeight: innerRow.height + Theme.notificationMediaPad * 2

        Image {
            visible: artworkRoot.blurredBackground && artworkRoot.art !== ""
            anchors.fill: parent
            source: artworkRoot.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: 0.18
        }

        Rectangle {
            visible: artworkRoot.blurredBackground && artworkRoot.art !== ""
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
                    visible: artworkRoot.art === "" || artImage.status !== Image.Ready
                    text: artworkRoot.fallbackIcon
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(artworkRoot.artSize * 0.45)
                    font.bold: Theme.fontBold
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    visible: artworkRoot.art !== ""
                    source: artworkRoot.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
            }

            Column {
                id: textCol
                width: parent.width - artworkRoot.artSize - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

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
                    opacity: 0.9
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
                    opacity: 0.55
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

            readonly property string kind: root.entryKind(modelData)
            readonly property var media: kind === "media" ? root.mediaFields(modelData) : ({})
            readonly property string art: kind === "media" ? root.popupImage(modelData) : ""

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
            Component.onCompleted: if (modelData) root.setPopupHeight(modelData.key, card.height)

            WlrLayershell.namespace: "evo-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Item {
                id: card
                width: Theme.notificationWidth
                height: kind === "media"
                    ? artworkCard.implicitHeight
                    : innerDefault.height + Theme.notificationPadding * 2
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
                    visible: kind === "media"
                    art: art
                    fields: media
                }

                // Default
                Rectangle {
                    visible: kind === "default"
                    width: 5
                    height: parent.height
                    color: Theme.accent
                }

                Row {
                    id: innerDefault
                    visible: kind === "default"
                    x: Theme.notificationPadding + 8
                    y: Theme.notificationPadding
                    width: parent.width - Theme.notificationPadding * 2 - 8
                    spacing: 16

                    Text {
                        id: iconLine
                        text: root.popupIcon(modelData)
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize4xl
                        font.bold: Theme.fontBold
                    }

                    Column {
                        spacing: 6
                        width: parent.width - iconLine.width - parent.spacing

                        Text {
                            text: root.popupTitle(modelData)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize2xl
                            font.bold: Theme.fontBold
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            text: root.stripMarkup(root.popupBody(modelData))
                            color: Theme.foreground
                            opacity: 0.88
                            visible: text.length > 0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeL
                            font.bold: Theme.fontBold
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
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
