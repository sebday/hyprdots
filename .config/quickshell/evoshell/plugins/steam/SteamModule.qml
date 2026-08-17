import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: shell ? String(shell.hoverPopupId || "") : ""
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-steam popup"
    readonly property string steamBin: Quickshell.env("HOME") + "/.local/bin/evo-steam"
    readonly property int hintFont: Theme.fontSizeL
    readonly property int titleFont: Theme.fontSize2xl
    readonly property int actionIconFont: Theme.fontSizeL
    readonly property int tileArtWidth: 96
    readonly property int tileArtHeight: 88
    readonly property int tileArtSourceSize: 192
    readonly property int tileHeight: tileArtHeight + 20
    readonly property int maxPlayedGames: 3
    readonly property var displayedGames: root.playedGames.slice(0, root.maxPlayedGames)

    function gameArtSource(game) {
        if (!game || !game.icon_path)
            return ""
        return Util.fileUrl(String(game.icon_path))
    }

    property bool loading: true
    property bool ok: false
    property string errorText: ""
    property bool steamRunning: false
    property real downloadRate: 0
    property int installedCount: 0
    property int libraryTotal: 0
    property var playedGames: []
    property var runningGames: []

    implicitHeight: column.implicitHeight

    function formatRate(bytesPerSec) {
        var n = Number(bytesPerSec) || 0
        if (n < 1024) return Math.round(n) + " B/s"
        if (n < 1048576) return (n / 1024).toFixed(1) + " KB/s"
        if (n < 1048576 * 10) return (n / 1048576).toFixed(1) + " MB/s"
        return (n / 1048576).toFixed(2) + " GB/s"
    }

    function formatPlaytime(minutes) {
        var m = parseInt(minutes, 10) || 0
        if (m <= 0)
            return ""
        return Math.round(m / 60) + "h"
    }

    readonly property string installedDisplay: {
        if (root.libraryTotal > 0)
            return root.installedCount + " / " + root.libraryTotal
        return String(root.installedCount)
    }

    function formatLastPlayed(ts) {
        var n = parseInt(ts, 10) || 0
        if (n <= 0)
            return "—"
        var now = Math.floor(Date.now() / 1000)
        var diff = now - n
        if (diff < 3600)
            return Math.max(1, Math.floor(diff / 60)) + "m ago"
        if (diff < 86400)
            return Math.floor(diff / 3600) + "h ago"
        if (diff < 86400 * 7)
            return Math.floor(diff / 86400) + "d ago"
        var d = new Date(n * 1000)
        return d.getDate() + "/" + (d.getMonth() + 1)
    }

    readonly property string statusPillText: {
        if (loading)
            return "Loading…"
        if (errorText)
            return errorText
        if (!steamRunning)
            return "Not running"
        if (runningGames.length > 0)
            return "Playing · " + String(runningGames[0].name || "")
        if (downloadRate > 0)
            return root.formatRate(downloadRate)
        return ""
    }

    readonly property color statusPillFill: {
        if (errorText)
            return Theme.withOpacity(Theme.urgent, 0.14)
        if (!steamRunning)
            return Theme.withOpacity(Theme.foreground, 0.08)
        if (runningGames.length > 0)
            return Theme.withOpacity(Theme.accent, 0.16)
        if (downloadRate > 0)
            return Theme.withOpacity(Theme.accent, 0.12)
        return Theme.withOpacity(Theme.foreground, 0.08)
    }

    readonly property color statusPillTextColor: {
        if (errorText)
            return Theme.urgent
        if (steamRunning && (runningGames.length > 0 || downloadRate > 0))
            return Theme.accent
        return Theme.foreground
    }

    function isKnownGame(game) {
        var appid = String(game.appid || "").trim()
        var name = String(game.name || "").trim()
        return appid.length > 0 && name.length > 0 && name !== "App " + appid
    }

    function filterKnownGames(games) {
        var out = []
        if (!Array.isArray(games))
            return out
        for (var i = 0; i < games.length; i++) {
            if (root.isKnownGame(games[i]))
                out.push(games[i])
        }
        return out
    }

    function applyPayload(json) {
        if (!json || typeof json !== "object")
            return
        loading = false
        ok = json.ok === true
        errorText = String(json.error || "")
        steamRunning = json.running === true
        downloadRate = parseFloat(json.download_bps || 0) || 0
        installedCount = parseInt(json.installed_count !== undefined
            ? json.installed_count : json.library_count, 10) || 0
        libraryTotal = parseInt(json.library_total, 10) || 0
        playedGames = root.filterKnownGames(json.played_games).slice(0, maxPlayedGames)
        runningGames = root.filterKnownGames(json.running_games)
        publishCache(json)
    }

    function publishCache(json) {
        if (cacheKey && shell && json)
            Util.hoverPopupCacheWrite(shell, cacheKey, json)
    }

    function bootstrapFromCache() {
        if (!cacheKey || !shell)
            return
        var cached = Util.hoverPopupCacheRead(shell, cacheKey)
        if (cached)
            applyPayload(cached)
    }

    function onActivated() {
        loading = playedGames.length === 0 && !steamRunning
        bootstrapFromCache()
        refresh()
        pollTimer.start()
    }

    function onDeactivated() {
        pollTimer.stop()
        if (popupProc.running)
            popupProc.running = false
        if (actionProc.running)
            actionProc.running = false
    }

    function refresh() {
        if (!script || popupProc.running)
            return
        popupProc.running = true
    }

    function launchGame(appid) {
        var id = String(appid || "").trim()
        if (!id || actionProc.running)
            return
        actionProc.command = [root.steamBin, "launch", id]
        actionProc.running = true
    }

    function openSteam() {
        if (actionProc.running)
            return
        actionProc.command = [root.steamBin, "open"]
        actionProc.running = true
    }

    Process {
        id: popupProc
        command: ["bash", "-lc", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(text || "").trim()
                if (!raw) {
                    root.loading = false
                    return
                }
                try {
                    root.applyPayload(JSON.parse(raw))
                } catch (e) {
                    root.loading = false
                    root.errorText = "Parse error"
                }
            }
        }
        onExited: root.loading = false
    }

    Process {
        id: actionProc
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        onTriggered: root.refresh()
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        FramedPanel {
            Layout.fillWidth: true
            label: ""
            contentPad: Theme.hoverPopupContentPad

            Item {
                width: parent.width
                implicitHeight: steamTopCol.implicitHeight

                ColumnLayout {
                    id: steamTopCol
                    width: parent.width
                    spacing: Theme.hoverPopupSectionSpacing

                    HoverPopupHeader {
                        Layout.fillWidth: true
                        iconFallback: "󰓓"
                        titleFont: root.titleFont
                        detailFont: root.hintFont
                        value: "Steam"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root.statusPillText !== ""

                        HoverPopupLabelPill {
                            text: root.statusPillText
                            fontSize: Theme.fontSizeS
                            textColor: root.statusPillTextColor
                            fill: root.statusPillFill
                            textOpacity: root.errorText || root.runningGames.length > 0 || root.downloadRate > 0 ? 1 : 0.72
                        }

                        Item { Layout.fillWidth: true }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        HoverPopupStatBox {
                            value: root.loading ? "…" : root.installedDisplay
                            label: "installed"
                            valueFontSize: Theme.fontSize5xl
                        }

                        HoverPopupStatBox {
                            value: root.loading ? "…" : String(root.displayedGames.length)
                            label: "recent"
                            valueFontSize: Theme.fontSize5xl
                        }
                    }
                }
            }
        }

        SectionPanel {
            Layout.fillWidth: true
            label: "Recent"
            sectionSpacing: 8
            contentPad: Theme.hoverPopupContentPad
            visible: root.displayedGames.length > 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.displayedGames

                    Item {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitWidth: parent.width
                        implicitHeight: root.tileHeight

                        readonly property bool isRunning: {
                            var id = String(modelData.appid || "")
                            for (var i = 0; i < root.runningGames.length; i++) {
                                if (String(root.runningGames[i].appid || "") === id)
                                    return true
                            }
                            return false
                        }

                        scale: tileMouse.pressed ? 0.97 : 1
                        opacity: tileMouse.pressed ? 0.88 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 90
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 90
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.panelCornerRadius
                            color: tileMouse.pressed
                                ? Theme.withOpacity(Theme.accent, 0.14)
                                : (tileMouse.containsMouse
                                    ? Theme.withOpacity(Theme.foreground, 0.07)
                                    : Theme.withOpacity(Theme.mantle, 0.65))
                            border.width: tileMouse.containsMouse || isRunning ? 1 : 0
                            border.color: isRunning ? Theme.accent : Theme.withOpacity(Theme.accent, 0.55)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            Item {
                                Layout.preferredWidth: root.tileArtWidth
                                Layout.preferredHeight: root.tileArtHeight
                                Layout.alignment: Qt.AlignVCenter
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.fieldsetCornerRadius
                                    color: Theme.panelMantle
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: gameIcon.source === "" || gameIcon.status === Image.Error
                                    text: "󰓓"
                                    color: Theme.foreground
                                    opacity: 0.35
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize3xl
                                    font.bold: Theme.fontBold
                                }

                                Image {
                                    id: gameIcon
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    visible: gameIcon.source !== "" && status !== Image.Error
                                    source: root.gameArtSource(modelData)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    mipmap: true
                                    sourceSize: Qt.size(root.tileArtSourceSize, Math.round(root.tileArtSourceSize * root.tileArtHeight / root.tileArtWidth))
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.fieldsetCornerRadius
                                    color: Theme.withOpacity(Theme.accent, 0.08)
                                    visible: tileMouse.containsMouse
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: String(modelData.name || "Game")
                                    color: tileMouse.containsMouse ? Theme.accent : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.titleFont
                                    font.bold: Theme.fontBold
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    HoverPopupLabelPill {
                                        visible: root.formatLastPlayed(modelData.last_played) !== "—"
                                        text: root.formatLastPlayed(modelData.last_played)
                                        fontSize: Theme.fontSizeS
                                    }

                                    HoverPopupLabelPill {
                                        visible: root.formatPlaytime(modelData.playtime_min) !== ""
                                        text: root.formatPlaytime(modelData.playtime_min)
                                        fontSize: Theme.fontSizeS
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: isRunning
                                    text: "Playing now"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    font.bold: Theme.fontBold
                                }
                            }

                            Text {
                                visible: tileMouse.containsMouse && !tileMouse.pressed
                                text: "󰐊"
                                color: Theme.accent
                                opacity: 0.85
                                font.family: Theme.fontFamily
                                font.pixelSize: root.titleFont
                                font.bold: Theme.fontBold
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchGame(modelData.appid)
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: openSteamRow.implicitHeight

            RowLayout {
                id: openSteamRow
                anchors.right: parent.right
                spacing: 6

                Text {
                    text: "󰓓"
                    color: openSteamBtn.containsMouse ? Theme.accent : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.actionIconFont
                    font.bold: Theme.fontBold
                }

                Text {
                    text: "Open"
                    color: openSteamBtn.containsMouse ? Theme.accent : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    font.bold: Theme.fontBold
                }
            }

            MouseArea {
                id: openSteamBtn
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openSteam()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.errorText !== ""
            text: root.errorText
            color: Theme.urgent
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: !root.loading && root.displayedGames.length === 0 && !root.errorText
            text: root.steamRunning ? "No recent play history" : "Steam not running"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            opacity: 0.65
        }
    }
}
