import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPanelWidth: 0

    readonly property string cacheKey: shell ? String(shell.hoverPanelId || "") : ""
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property string script: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-bar-steam popup")
    readonly property string steamBin: Util.evoshellScript(Quickshell.env("HOME"), shell, "evo-bar-steam")
    readonly property int hintFont: Theme.fontSizeL
    readonly property int titleFont: Theme.fontSize2xl
    readonly property int recentTitleFont: Theme.fontSizeXl
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
    property int installedCount: 0
    property int libraryTotal: 0
    property int totalPlaytimeMin: 0
    property var playedGames: []
    property var runningGames: []

    implicitHeight: column.implicitHeight

    function formatPlaytime(minutes) {
        var m = Number(minutes) || 0
        if (m <= 0)
            return ""
        var hours = Math.round(m / 60)
        if (hours <= 0)
            return ""
        return String(hours) + "h"
    }

    readonly property string installedCountDisplay: {
        if (root.loading)
            return "…"
        return String(root.installedCount)
    }

    readonly property string libraryTotalDisplay: {
        if (root.loading)
            return "…"
        if (root.libraryTotal <= 0)
            return "—"
        return String(root.libraryTotal)
    }

    readonly property string totalPlayedDisplay: {
        if (root.loading)
            return "…"
        var hours = Math.round(Number(root.totalPlaytimeMin) / 60)
        if (hours <= 0)
            return "—"
        return String(hours) + "h"
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
        return ""
    }

    readonly property color statusPillFill: {
        if (errorText)
            return Theme.fillUrgentSubtle
        if (!steamRunning)
            return Theme.fillNeutralSubtle
        if (runningGames.length > 0)
            return Theme.withOpacity(Theme.accent, 0.16)
        return Theme.fillNeutralSubtle
    }

    readonly property color statusPillTextColor: {
        if (errorText)
            return Theme.urgent
        if (steamRunning && runningGames.length > 0)
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
        installedCount = parseInt(json.installed_count !== undefined
            ? json.installed_count : json.library_count, 10) || 0
        libraryTotal = parseInt(json.library_total, 10) || 0
        totalPlaytimeMin = parseInt(json.total_playtime_min, 10) || 0
        playedGames = root.filterKnownGames(json.played_games).slice(0, maxPlayedGames)
        runningGames = root.filterKnownGames(json.running_games)
        publishCache(json)
    }

    function publishCache(json) {
        if (cacheKey && shell && json)
            Util.hoverPanelCacheWrite(shell, cacheKey, json)
    }

    function bootstrapFromCache() {
        if (!cacheKey || !shell)
            return
        var cached = Util.hoverPanelCacheRead(shell, cacheKey)
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
        width: root.hoverPanelWidth
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            Layout.fillWidth: true
            label: ""
            contentPad: Theme.hoverPanelContentPad

            HoverPanelLabelPill {
                text: "Steam"
                icon: "󰓓"
                fontSize: Theme.fontSizeS
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8

                HoverPanelStatBox {
                    value: root.installedCountDisplay
                    label: "installed"
                    valueFontSize: Theme.fontSize5xl
                }

                HoverPanelStatBox {
                    value: root.libraryTotalDisplay
                    label: "total games"
                    valueFontSize: Theme.fontSize5xl
                }

                HoverPanelStatBox {
                    value: root.totalPlayedDisplay
                    label: "played"
                    valueFontSize: Theme.fontSize5xl
                    special: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS
                visible: root.statusPillText !== ""

                HoverPanelLabelPill {
                    text: root.statusPillText
                    fontSize: Theme.fontSizeS
                    textColor: root.statusPillTextColor
                    fill: root.statusPillFill
                    textOpacity: root.errorText || root.runningGames.length > 0 ? 1 : 0.72
                    fieldsetLegend: false
                }

                Item { Layout.fillWidth: true }
            }
        }

        SectionPanel {
            Layout.fillWidth: true
            label: ""
            sectionSpacing: 8
            contentPad: Theme.hoverPanelContentPad
            visible: root.displayedGames.length > 0

            HoverPanelLabelPill {
                text: "Recent"
                icon: "󰋚"
                fontSize: Theme.fontSizeS
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.displayedGames

                    ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.tileHeight

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
                                    ? Theme.fillAccentSubtle
                                    : (tileMouse.containsMouse
                                        ? Theme.withOpacity(Theme.foreground, 0.07)
                                        : "transparent")
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
                                        visible: gameIcon.source !== "" && status !== Image.Error
                                        source: root.gameArtSource(modelData)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                        mipmap: true
                                        sourceSize: Qt.size(root.tileArtSourceSize, Math.round(root.tileArtSourceSize * root.tileArtHeight / root.tileArtWidth))
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
                                        font.pixelSize: root.recentTitleFont
                                        font.bold: Theme.fontBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingS

                                        HoverPanelLabelPill {
                                            visible: root.formatLastPlayed(modelData.last_played) !== "—"
                                            text: root.formatLastPlayed(modelData.last_played)
                                            fontSize: Theme.fontSizeS
                                        }

                                        HoverPanelLabelPill {
                                            visible: root.formatPlaytime(modelData.playtime_min) !== ""
                                            text: root.formatPlaytime(modelData.playtime_min)
                                            fontSize: Theme.fontSizeS
                                        }
                                    }
                                }

                                Text {
                                    visible: tileMouse.containsMouse && !tileMouse.pressed
                                    text: "󰐊"
                                    color: Theme.accent
                                    opacity: Theme.opacityBodyText
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

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            visible: index < root.displayedGames.length - 1
                            color: Theme.foregroundDivider
                        }
                    }
                }
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
            opacity: Theme.opacityHover
        }
    }
}
