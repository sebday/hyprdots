import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../../Commons"

Scope {
    id: root

    property var shell: null
    property var activePopups: []
    property var popupHeights: ({})

    readonly property int popupGap: 10
    readonly property int popupMarginAboveBar: 14
    readonly property string popupOutput: "HDMI-A-1"
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
            if (item.local && String(item.title) === titleStr) continue
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

    function showVolume(percent, muted) {
        var p = Math.max(0, parseInt(percent, 10) || 0)
        var isMuted = !!muted
        var next = []
        for (var i = 0; i < activePopups.length; i++) {
            var item = activePopups[i]
            if (item.kind === "volume" || (item.local && String(item.title) === "Volume"))
                continue
            next.push(item)
        }
        next.push({
            key: Date.now() + Math.random(),
            local: true,
            kind: "volume",
            title: "Volume",
            body: isMuted ? "Muted" : p + "%",
            percent: p,
            muted: isMuted
        })
        activePopups = next
        scheduleDismiss(root.durationMs)
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
        if (entry.local) return String(entry.title || "")
        if (entry.notification) return String(entry.notification.summary || entry.notification.appName || "")
        return ""
    }

    function popupBody(entry) {
        if (!entry) return ""
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
        var n = entry && entry.notification
        if (!n) return ""
        if (n.image) return imageSource(n.image)
        if (looksLikeImage(n.appIcon)) return imageSource(n.appIcon)
        return ""
    }

    function popupIcon(entry) {
        var title = popupTitle(entry).trim().toLowerCase()
        var body = popupBody(entry).trim().toLowerCase()
        if (isVolume(entry))
            return isMuted(entry) || volumePercent(entry) === 0 ? "󰝟" : "󰕾"
        if (title.indexOf("error") !== -1 || body.indexOf("error") !== -1)
            return "󰅙"
        if (isMedia(entry))
            return "󰎆"
        return "󰂚"
    }

    function isVolume(entry) {
        if (!entry) return false
        if (entry.kind === "volume") return true
        return popupTitle(entry).trim().toLowerCase() === "volume"
    }

    function isMuted(entry) {
        if (!entry) return false
        if (entry.muted === true) return true
        return popupBody(entry).trim().toLowerCase() === "muted"
    }

    function volumePercent(entry) {
        if (!entry) return 0
        if (entry.percent !== undefined && entry.percent !== null)
            return Math.max(0, Number(entry.percent) || 0)
        if (isMuted(entry)) return 0
        return Math.max(0, parseInt(popupBody(entry), 10) || 0)
    }

    function isScrobbler(entry) {
        var title = popupTitle(entry).toLowerCase()
        var app = String(entry && entry.notification && entry.notification.appName || "").toLowerCase()
        return title.indexOf("scrobbler") !== -1 || app.indexOf("scrobbler") !== -1
    }

    function isMedia(entry) {
        if (!entry || entry.local) return false
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
        var lines = bodyLines(entry)
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
        if (isVolume(entry)) return "volume"
        if (isMedia(entry)) return "media"
        return "default"
    }

    function estimatedHeight(entry) {
        var kind = entryKind(entry)
        if (kind === "volume")
            return Theme.notificationVolumeHeight
        if (kind === "media")
            return Theme.notificationArtSize + Theme.notificationMediaPad * 2
        return Theme.notificationPadding * 2 + Theme.notificationTitleSize + 6 + Theme.notificationBodySize
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

    readonly property var stackBottoms: {
        var heights = popupHeights
        var list = activePopups
        var out = []
        var y = Theme.barHeight + popupMarginAboveBar
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

    Instantiator {
        model: root.activePopups
        active: true

        delegate: PanelWindow {
            required property var modelData
            required property int index

            readonly property string kind: root.entryKind(modelData)
            readonly property var media: kind === "media" ? root.mediaFields(modelData) : ({})
            readonly property string art: kind === "media" ? root.popupImage(modelData) : ""
            readonly property int volPercent: kind === "volume" ? root.volumePercent(modelData) : 0
            readonly property bool volMuted: kind === "volume" && root.isMuted(modelData)
            readonly property real volFill: volMuted ? 0 : Math.min(1, volPercent / 100)

            screen: root.popupScreen
            color: "transparent"
            implicitWidth: Theme.notificationWidth
            implicitHeight: card.height

            anchors.bottom: true
            anchors.left: true
            margins.bottom: index < root.stackBottoms.length
                ? root.stackBottoms[index]
                : Theme.barHeight + root.popupMarginAboveBar
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
                height: kind === "volume"
                    ? Theme.notificationVolumeHeight
                    : (kind === "media"
                        ? innerMedia.height + Theme.notificationMediaPad * 2
                        : innerDefault.height + Theme.notificationPadding * 2)
                clip: kind === "volume"

                Rectangle {
                    anchors.fill: parent
                    color: Theme.overlaySurface
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
                    border.width: 1
                    radius: Theme.panelCornerRadius
                }

                // Volume fill
                Rectangle {
                    visible: kind === "volume"
                    width: parent.width * volFill
                    height: parent.height
                    color: Theme.accent
                    opacity: 0.38
                    radius: Theme.panelCornerRadius
                }

                Text {
                    visible: kind === "volume"
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: volMuted ? "MUTE" : (volPercent + "%")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 56
                    font.bold: Theme.fontBold
                    opacity: 0.16
                }

                Row {
                    visible: kind === "volume"
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Text {
                        text: root.popupIcon(modelData)
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 32
                        font.bold: Theme.fontBold
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: volMuted ? "Muted" : "Volume"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.notificationTitleSize
                        font.bold: Theme.fontBold
                    }
                }

                // Media / artwork
                Image {
                    visible: kind === "media" && art !== ""
                    anchors.fill: parent
                    source: art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: 0.18
                }

                Rectangle {
                    visible: kind === "media" && art !== ""
                    anchors.fill: parent
                    color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.55)
                }

                Row {
                    id: innerMedia
                    visible: kind === "media"
                    x: Theme.notificationPadding
                    y: Theme.notificationMediaPad
                    width: parent.width - Theme.notificationPadding * 2
                    height: Math.max(Theme.notificationArtSize, mediaCol.height)
                    spacing: 16

                    Item {
                        width: Theme.notificationArtSize
                        height: Theme.notificationArtSize
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                            radius: Theme.panelCornerRadius
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: art === "" || artImage.status !== Image.Ready
                            text: "󰎆"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 36
                            font.bold: Theme.fontBold
                        }

                        Image {
                            id: artImage
                            anchors.fill: parent
                            visible: art !== ""
                            source: art
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                    }

                    Column {
                        id: mediaCol
                        width: parent.width - Theme.notificationArtSize - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            width: parent.width
                            visible: media.kicker !== ""
                            text: media.kicker
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.popupHintFontPixelSize
                            font.bold: Theme.fontBold
                            font.letterSpacing: 1
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: 0.9
                        }

                        Text {
                            width: parent.width
                            text: media.title || ""
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.notificationTitleSize
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            width: parent.width
                            visible: media.subtitle !== ""
                            text: media.subtitle
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.notificationBodySize
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: 0.82
                        }

                        Text {
                            width: parent.width
                            visible: media.footer !== ""
                            text: media.footer
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.popupHintFontPixelSize
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: 0.55
                        }
                    }
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
                        font.pixelSize: Theme.notificationIconSize
                        font.bold: Theme.fontBold
                    }

                    Column {
                        spacing: 6
                        width: parent.width - iconLine.width - parent.spacing

                        Text {
                            text: root.popupTitle(modelData)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.notificationTitleSize
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
                            font.pixelSize: Theme.notificationBodySize
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
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton && modelData)
                        root.dismissEntry(modelData.key)
                }
            }
        }
    }
}
