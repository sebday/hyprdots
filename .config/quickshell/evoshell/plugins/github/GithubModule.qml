import Quickshell
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
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int statFont: Theme.fontSizeXl
    readonly property int todayCountFont: Theme.fontSizeHero
    readonly property int headerIconSize: Math.max(
        root.todayCountFont + 8,
        root.statFont * 2 + 6
    )
    readonly property int headerBlockHeight: root.headerIconSize - 1

    implicitHeight: column.implicitHeight

    readonly property int trendMax: 40
    readonly property int heatmapSpacing: 3
    readonly property var legendColors: {
        var colors = []
        for (var level = 0; level < 5; level++) {
            var found = ""
            for (var i = 0; i < cells.length; i++) {
                if ((parseInt(cells[i].level, 10) || 0) === level && cells[i].color) {
                    found = String(cells[i].color)
                    break
                }
            }
            colors.push(found || Theme.heatmapColors[level])
        }
        return colors
    }

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
        if (cells.length === 0 || hoverPopupWidth <= 0)
            return 12
        var gaps = Math.max(0, cells.length - 1) * heatmapSpacing
        return Math.max(10, Math.min(16, Math.floor((hoverPopupWidth - gaps) / cells.length)))
    }

    readonly property string todayLabel: todayCount === 1
        ? "contribution today"
        : "contributions today"

    function trendLevel(count) {
        var n = parseInt(count, 10) || 0
        if (n <= 0)
            return 0
        return Math.max(1, Math.min(7, Math.ceil(n / trendMax * 7)))
    }

    readonly property var sparkBars: {
        var out = []
        for (var i = 0; i < cells.length; i++) {
            var c = cells[i] || {}
            var count = parseInt(c.count, 10) || 0
            out.push({
                value: count,
                level: root.trendLevel(count),
                color: c.color || Theme.accent
            })
        }
        return out
    }

    function onActivated() {
        syncFromBar()
    }

    function hasDisplayData() {
        return !isError && (cells.length > 0 || todayCount > 0 || total30 > 0)
    }

    function bootstrapFromCache() {
        if (!cacheKey || !shell)
            return
        var cached = Util.hoverPopupCacheRead(shell, cacheKey)
        if (cached)
            applyPayload(cached)
    }

    function publishCache(json) {
        if (cacheKey && shell && json && typeof json === "object")
            Util.hoverPopupCacheWrite(shell, cacheKey, json)
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.loading) {
            if (!hasDisplayData())
                loading = true
            return
        }
        if (item && item.lastPayload)
            applyPayload(item.lastPayload)
        else {
            var cached = Util.hoverPopupCacheRead(shell, cacheKey)
            if (cached)
                applyPayload(cached)
            else if (item)
                applyFromWidget(item)
            else
                applyPayload(null)
        }
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
        publishCache(json)
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
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

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
            contentPad: Theme.panelContentPad
            sectionSpacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.headerBlockHeight
                Layout.topMargin: 2
                Layout.bottomMargin: 1

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 12

                    Item {
                        Layout.preferredWidth: root.headerIconSize
                        Layout.preferredHeight: root.headerIconSize

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: root.loading
                                ? Theme.foreground
                                : Format.contributionColor(root.todayCount)
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(root.headerIconSize * 0.78)
                            font.bold: Theme.fontBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: Theme.opacityEmphasis
                        }
                    }

                    Text {
                        id: todayCountText
                        text: root.loading ? "…" : String(root.todayCount)
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.todayCountFont
                        font.bold: Theme.fontBold
                        lineHeight: root.todayCountFont
                        lineHeightMode: Text.FixedHeight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        HoverPopupLabelPill {
                            id: usernamePill
                            text: "@" + root.username
                            fontSize: Theme.fontSizeS
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.todayLabel
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            font.bold: Theme.fontBold
                            opacity: Theme.opacitySecondary
                            elide: Text.ElideRight
                        }
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
                    label: ""
                    filled: true
                    contentPad: Theme.panelContentPad

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing2

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: String(modelData.value)
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize5xl
                            font.bold: Theme.fontBold
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.label
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            opacity: Theme.opacityMuted
                        }
                    }
                }
            }
        }

        SectionPanel {
            label: ""
            visible: !root.loading && !root.isError && root.sparkBars.length > 0

            HoverPopupLabelPill {
                text: "Trend"
                fontSize: Theme.fontSizeS
            }

            SparklineChart {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                chartHeight: 64
                bars: root.sparkBars
            }
        }

        SectionPanel {
            label: ""
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
                            radius: Theme.radiusM
                            color: modelData.color
                                || Theme.heatmapColors[Math.max(0, Math.min(4, parseInt(modelData.level, 10) || 0))]
                                || Theme.foreground
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
                opacity: Theme.opacityDisabled
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingS
                visible: root.cells.length > 0

                Text {
                    text: "Less"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: Theme.opacityDisabled
                }

                Repeater {
                    model: root.legendColors

                    Rectangle {
                        required property string modelData
                        width: 12
                        height: 12
                        radius: Theme.radiusS
                        color: modelData
                    }
                }

                Text {
                    text: "More"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: Theme.opacityDisabled
                }
            }
        }
    }
}
