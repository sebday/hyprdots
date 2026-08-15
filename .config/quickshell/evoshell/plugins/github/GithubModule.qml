import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property int tooltipWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int titleFont: Theme.tooltipTitleFontPixelSize + 4
    readonly property int heroFont: Theme.tooltipIconFontPixelSize + 6
    readonly property int bodyFont: Theme.tooltipBodyFontPixelSize
    readonly property int hintFont: Theme.tooltipHintFontPixelSize
    readonly property int statFont: Theme.tooltipLabelFontPixelSize
    readonly property int heatmapSpacing: 3
    readonly property var legendColors: [
        "#45475a", "#89b4fa", "#74c7ec", "#89dceb", "#cba6f7"
    ]

    property bool loading: false
    property bool isError: false
    property string statusText: ""
    property int todayCount: 0
    property int total30: 0
    property int streak: 0
    property int bestCount: 0
    property string username: "sebday"
    property string profileUrl: "https://github.com/sebday"
    property var cells: []

    readonly property int heatmapCellSize: {
        if (cells.length === 0 || tooltipWidth <= 0)
            return 12
        var gaps = Math.max(0, cells.length - 1) * heatmapSpacing
        return Math.max(10, Math.min(16, Math.floor((tooltipWidth - gaps) / cells.length)))
    }

    readonly property string todayLine: {
        if (loading)
            return "Loading…"
        if (todayCount === 1)
            return "1 contribution today"
        return todayCount + " contributions today"
    }

    readonly property string summaryLine: {
        var parts = []
        parts.push(total30 + " in 30 days")
        if (streak > 0)
            parts.push(streak + " day streak")
        if (bestCount > 0)
            parts.push("best " + bestCount)
        return parts.join(" · ")
    }

    readonly property var sparkBars: {
        var out = []
        for (var i = 0; i < cells.length; i++) {
            var c = cells[i] || {}
            out.push({
                value: c.count || 0,
                level: Math.max(1, c.level || 1),
                color: c.color || Theme.accent
            })
        }
        return out
    }

    implicitHeight: column.implicitHeight

    function onActivated() {
        syncFromBar()
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.loading) {
            loading = true
            return
        }
        if (item && item.lastPayload)
            applyPayload(item.lastPayload)
        else if (item)
            applyFromWidget(item)
        else
            applyPayload(null)
    }

    function applyFromWidget(item) {
        loading = item.loading === true
        isError = item.isError === true
        statusText = String(item.statusText || "")
        todayCount = parseInt(item.todayCount, 10) || 0
        cells = Array.isArray(item.cells) ? item.cells : []
        total30 = 0
        streak = 0
        bestCount = 0
        for (var i = 0; i < cells.length; i++) {
            var c = parseInt(cells[i].count, 10) || 0
            total30 += c
            if (c > bestCount)
                bestCount = c
        }
        for (var s = cells.length - 1; s >= 0; s--) {
            if ((parseInt(cells[s].count, 10) || 0) > 0)
                streak++
            else
                break
        }
    }

    function applyPayload(json) {
        loading = false
        if (!json || typeof json !== "object") {
            isError = true
            statusText = "No data"
            todayCount = 0
            total30 = 0
            streak = 0
            bestCount = 0
            cells = []
            return
        }
        if (json.class === "error") {
            isError = true
            statusText = String(json.tooltip || json.text || "GitHub error").replace(/<[^>]+>/g, "").trim()
            todayCount = 0
            total30 = 0
            streak = 0
            bestCount = 0
            cells = []
            return
        }
        isError = false
        statusText = ""
        todayCount = parseInt(json.today, 10) || 0
        total30 = parseInt(json.total30, 10) || 0
        streak = parseInt(json.streak, 10) || 0
        bestCount = parseInt(json.best, 10) || 0
        username = String(json.username || "sebday")
        profileUrl = String(json.profileUrl || ("https://github.com/" + username))
        cells = Array.isArray(json.cells) ? json.cells : []

        if (total30 === 0 && cells.length > 0) {
            var sum = 0
            var best = 0
            for (var i = 0; i < cells.length; i++) {
                var c = parseInt(cells[i].count, 10) || 0
                sum += c
                if (c > best)
                    best = c
            }
            total30 = sum
            if (bestCount === 0)
                bestCount = best
        }
        if (streak === 0 && cells.length > 0) {
            for (var j = cells.length - 1; j >= 0; j--) {
                if ((parseInt(cells[j].count, 10) || 0) > 0)
                    streak++
                else
                    break
            }
        }
    }

    function openProfile() {
        if (!profileUrl)
            return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(profileUrl)])
    }

    onActiveChanged: if (active) syncFromBar()
    onBarSourceChanged: if (active) syncFromBar()

    Connections {
        target: root.barSource
        enabled: root.barSource !== null
        function onLastPayloadChanged() {
            if (root.active) root.syncFromBar()
        }
        function onLoadingChanged() {
            if (root.active) root.syncFromBar()
        }
    }

    ColumnLayout {
        id: column
        width: root.tooltipWidth
        spacing: Theme.tooltipSectionSpacing

        Text {
            Layout.fillWidth: true
            visible: root.loading
            text: "Loading contributions…"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
            font.bold: Theme.fontBold
        }

        Text {
            Layout.fillWidth: true
            visible: root.isError
            text: root.statusText
            color: Theme.urgent
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
            font.bold: Theme.fontBold
        }

        SectionPanel {
            label: ""
            visible: !root.loading && !root.isError

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: ""
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.heroFont
                    font.bold: Theme.fontBold
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: "@" + root.username
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.titleFont
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.todayLine
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.bodyFont
                        font.bold: Theme.fontBold
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.summaryLine !== ""
                        text: root.summaryLine
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: 0.72
                        wrapMode: Text.WordWrap
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openProfile()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 10
            rowSpacing: 10
            visible: !root.loading && !root.isError

            Repeater {
                model: [
                    { label: "30 days", value: String(root.total30) },
                    { label: "Streak", value: root.streak > 0
                        ? root.streak + (root.streak === 1 ? " day" : " days")
                        : "—" },
                    { label: "Best day", value: root.bestCount > 0 ? String(root.bestCount) : "—" }
                ]

                SectionPanel {
                    required property var modelData
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: String(modelData.value)
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.statFont + 4
                            font.bold: Theme.fontBold
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.label
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: 0.55
                        }
                    }
                }
            }
        }

        SectionPanel {
            label: "Trend"
            visible: !root.loading && !root.isError && root.sparkBars.length > 0

            SparklineChart {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                chartHeight: 64
                bars: root.sparkBars
            }
        }

        SectionPanel {
            label: "Last 30 days"
            visible: !root.loading && !root.isError

            Item {
                Layout.fillWidth: true
                implicitHeight: heatmapRow.height

                Row {
                    id: heatmapRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.heatmapSpacing
                    height: root.heatmapCellSize

                    Repeater {
                        model: root.cells

                        Rectangle {
                            required property var modelData
                            required property int index
                            width: root.heatmapCellSize
                            height: root.heatmapCellSize
                            radius: 3
                            color: modelData.color || Theme.foreground
                            opacity: (modelData.count || 0) > 0 ? 1 : 0.35
                            border.width: index === root.cells.length - 1 ? 1 : 0
                            border.color: Theme.accent
                        }
                    }
                }
            }

            Text {
                visible: root.cells.length === 0
                text: "No activity data"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.45
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                visible: root.cells.length > 0

                Text {
                    text: "Less"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: 0.45
                }

                Repeater {
                    model: root.legendColors

                    Rectangle {
                        required property string modelData
                        width: 12
                        height: 12
                        radius: 2
                        color: modelData
                    }
                }

                Text {
                    text: "More"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: 0.45
                }
            }
        }
    }
}
