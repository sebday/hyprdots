import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property int tooltipWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int bodyFont: Theme.tooltipBodyFontPixelSize
    readonly property int hintFont: Theme.tooltipHintFontPixelSize
    readonly property int heatmapCellSize: 10
    readonly property int heatmapSpacing: 2
    readonly property int heatmapWidth: root.cells.length > 0
        ? root.cells.length * root.heatmapCellSize + Math.max(0, root.cells.length - 1) * root.heatmapSpacing
        : 0

    property bool loading: false
    property bool isError: false
    property string statusText: ""
    property int todayCount: 0
    property var cells: []

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
    }

    function applyPayload(json) {
        loading = false
        if (!json || typeof json !== "object") {
            isError = true
            statusText = "No data"
            todayCount = 0
            cells = []
            return
        }
        if (json.class === "error") {
            isError = true
            statusText = String(json.tooltip || json.text || "GitHub error").replace(/<[^>]+>/g, "").trim()
            todayCount = 0
            cells = []
            return
        }
        isError = false
        statusText = ""
        todayCount = parseInt(json.today, 10) || 0
        cells = Array.isArray(json.cells) ? json.cells : []
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
            label: "Today"
            visible: !root.loading && !root.isError

            Text {
                text: root.todayCount === 1
                    ? "1 contribution"
                    : root.todayCount + " contributions"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.bodyFont
                font.bold: Theme.fontBold
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
                            width: root.heatmapCellSize
                            height: root.heatmapCellSize
                            color: modelData.color || Theme.foreground
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
        }
    }
}
