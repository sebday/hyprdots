import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../../Commons"

Scope {
    id: root

    property var shell: null
    property var activePopups: []
    property var popupHeights: ({})

    readonly property int popupGap: 10
    readonly property int popupMarginFromEdge: 20
    readonly property string popupOutput: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        return cfg && cfg.output ? String(cfg.output) : "HDMI-A-1"
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

    function activeMprisPlayer() {
        var players = Mpris.players.values
        if (!players || players.length === 0)
            return null
        for (var i = 0; i < players.length; i++) {
            if (players[i] && players[i].isPlaying)
                return players[i]
        }
        for (var j = 0; j < players.length; j++) {
            if (players[j] && String(players[j].trackTitle || "").trim())
                return players[j]
        }
        return players.length > 0 ? players[0] : null
    }

    function popupImageFromMpris(player) {
        if (!player) return ""
        return imageSource(player.trackArtUrl)
    }

    readonly property int volumeArtSize: 72

    function volumeMediaFields(player, entry) {
        var fields = {
            kicker: "Volume",
            title: isMuted(entry) ? "Muted" : volumePercent(entry) + "%",
            subtitle: "",
            footer: ""
        }
        if (!player)
            return fields

        var track = String(player.trackTitle || "").trim()
        var artist = String(player.trackArtist || "").trim()
        var album = String(player.trackAlbum || "").trim()
        if (track)
            fields.kicker = track
        if (artist)
            fields.subtitle = artist
        if (album)
            fields.footer = album
        return fields
    }

    function estimatedHeight(entry) {
        var kind = entryKind(entry)
        if (kind === "volume")
            return root.volumeArtSize + Theme.notificationMediaPad * 2
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
                    font.pixelSize: Theme.popupHintFontPixelSize
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
                    font.pixelSize: Theme.notificationTitleSize
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
                    font.pixelSize: Theme.notificationBodySize
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
                    font.pixelSize: Theme.popupHintFontPixelSize
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
            readonly property var mprisPlayer: kind === "volume" ? root.activeMprisPlayer() : null
            readonly property var artworkFields: kind === "media"
                ? media
                : (kind === "volume" ? root.volumeMediaFields(mprisPlayer, modelData) : ({}))
            readonly property string artworkSource: kind === "media"
                ? art
                : (kind === "volume" ? root.popupImageFromMpris(mprisPlayer) : "")
            readonly property string artworkIcon: kind === "volume" ? root.popupIcon(modelData) : "󰎆"
            readonly property int volPercent: kind === "volume" ? root.volumePercent(modelData) : 0
            readonly property bool volMuted: kind === "volume" && root.isMuted(modelData)
            readonly property real volFill: volMuted ? 0 : Math.min(1, volPercent / 100)

            screen: root.popupScreen
            color: "transparent"
            implicitWidth: Theme.notificationWidth
            implicitHeight: card.height

            anchors.bottom: true
            anchors.left: true
            margins.bottom: index < root.stackOffsets.length
                ? root.stackOffsets[index]
                : root.popupMarginFromEdge
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
                height: (kind === "media" || kind === "volume")
                    ? artworkCard.implicitHeight
                    : innerDefault.height + Theme.notificationPadding * 2
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.panelCornerRadius
                    color: kind === "volume" ? Theme.mantle : Theme.overlaySurface
                }

                Rectangle {
                    visible: kind === "volume"
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: parent.width * volFill
                    color: Theme.mixColors(Theme.mantle, Theme.accent, 0.38)
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
                    visible: kind === "media" || kind === "volume"
                    art: artworkSource
                    fallbackIcon: artworkIcon
                    fields: artworkFields
                    artSize: kind === "volume" ? root.volumeArtSize : Theme.notificationArtSize
                    blurredBackground: kind !== "volume"
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
