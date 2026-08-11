import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root
    property var bar: null
    property var barPanel: null
    property var settings: ({})

    property bool loading: false
    property string mainText: ""
    property var bars: []
    property string storeLabel: ""
    property string currencySymbol: "£"
    property int hoveredBarIndex: -1

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string store: settings.store ? String(settings.store) : ""
    readonly property string script: home + "/.local/bin/evo-bar-shopify.sh"
    readonly property string hoverCaption: {
        if (hoveredBarIndex < 0 || hoveredBarIndex >= bars.length) return "14-day revenue"
        var cell = bars[hoveredBarIndex]
        if (!cell) return "14-day revenue"
        return Format.formatDay(cell.date) + "  " + Format.formatRevenue(cell.value, currencySymbol)
    }

    clip: false
    implicitWidth: contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function applyJson(line) {
        loading = false
        var raw = String(line || "").trim()
        if (!raw) return
        try {
            var json = JSON.parse(raw)
            if (json.label)
                mainText = String(json.label)
            else
                mainText = String(json.text || "").split("<span")[0].trim()

            if (json.store)
                storeLabel = String(json.store).trim()
            if (json.symbol)
                currencySymbol = String(json.symbol)

            bars = Array.isArray(json.bars) ? json.bars : []
        } catch (e) {
            console.warn("shopify widget parse failed:", store, e)
        }
    }

    function poll() {
        if (!script || !store) return
        loading = true
        proc.command = ["bash", "-lc", script + " " + store]
        proc.running = false
        proc.running = true
    }

    function restartPolling() {
        if (!store) return
        intervalTimer.interval = Math.max(1, parseInt(settings.interval, 10) || 300) * 1000
        intervalTimer.stop()
        poll()
        intervalTimer.start()
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: root.applyJson(text)
        }
        onExited: root.loading = false
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.sparklineGap
        clip: false

        Text {
            text: root.loading ? "…" : root.mainText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFontPixelSize
            font.bold: Theme.fontBold
        }

        Item {
            id: chartHost
            visible: !root.loading && root.bars.length > 0
            width: nativeSparkline.width
            height: nativeSparkline.height
            anchors.verticalCenter: parent.verticalCenter
            clip: false

            Row {
                id: nativeSparkline
                spacing: Theme.sparklineBarSpacing
                height: Theme.sparklineHeight
                anchors.centerIn: parent

                Item {
                    width: Theme.sparklineChartMargin
                    height: 1
                }

                Repeater {
                    model: root.bars
                    Item {
                        required property int index
                        required property var modelData
                        width: Theme.sparklineWideBarWidth
                        height: nativeSparkline.height

                        Rectangle {
                            width: Theme.sparklineWideBarWidth
                            height: modelData.level > 0
                                ? Math.max(1, nativeSparkline.height * modelData.level / 7)
                                : 0
                            anchors.bottom: parent.bottom
                            color: modelData.color || Theme.foreground
                            opacity: chartHoverArea.containsMouse && root.hoveredBarIndex === index ? 1 : 0.75
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: root.hoveredBarIndex = index
                            onExited: root.hoveredBarIndex = -1
                        }
                    }
                }
            }

            MouseArea {
                id: chartHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }
    }

    MouseArea {
        z: -1
        anchors.fill: parent
        onClicked: if (root.settings.onClick)
            Quickshell.execDetached(["bash", "-lc", String(root.settings.onClick)])
    }

    Timer {
        id: intervalTimer
        interval: Math.max(1, parseInt(root.settings.interval, 10) || 300) * 1000
        repeat: true
        onTriggered: root.poll()
    }

    onSettingsChanged: restartPolling()
    Component.onCompleted: restartPolling()
}
