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
    property var sparkline: []
    property var bars: []
    property string storeLabel: ""
    property string currencySymbol: "£"
    property int hoveredBarIndex: -1

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string store: {
        if (settings.store) return String(settings.store)
        var id = String(settings.id || "")
        if (id === "shopify_diy") return "DIY"
        if (id === "shopify_tgs") return "TGS"
        return ""
    }
    readonly property string script: home + "/.local/bin/evo-bar-shopify.sh"
    readonly property bool useNativeBars: bars.length > 0
    readonly property string hoverCaption: {
        if (hoveredBarIndex < 0 || hoveredBarIndex >= bars.length) return "14-day revenue"
        var cell = bars[hoveredBarIndex]
        if (!cell) return "14-day revenue"
        return formatDay(cell.date) + "  " + formatRevenue(cell.value)
    }

    clip: false
    implicitWidth: contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function formatDay(iso) {
        if (!iso) return ""
        var parts = String(iso).split("-")
        if (parts.length < 3) return String(iso)
        var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[d.getDay()] + " " + d.getDate()
    }

    function formatRevenue(val) {
        var n = Math.round(parseFloat(val) || 0)
        var s = String(n)
        var out = ""
        for (var i = 0; i < s.length; i++) {
            if (i > 0 && (s.length - i) % 3 === 0) out += ","
            out += s.charAt(i)
        }
        return currencySymbol + out
    }

    function parseSpans(text) {
        var spans = []
        var re = /<span foreground='([^']+)'>([^<]*)<\/span>/g
        var m
        var s = String(text || "")
        while ((m = re.exec(s)) !== null) {
            spans.push({ color: m[1], char: m[2] || "▂" })
        }
        return spans
    }

    function applyJson(line) {
        loading = false
        var raw = String(line || "").trim()
        if (!raw) return
        try {
            var json = JSON.parse(raw)
            var text = String(json.text || "")

            if (json.label)
                mainText = String(json.label)
            else
                mainText = text.split("<span")[0].trim()

            if (json.store)
                storeLabel = String(json.store).trim()
            if (json.symbol)
                currencySymbol = String(json.symbol)

            if (Array.isArray(json.bars) && json.bars.length > 0) {
                bars = json.bars
                sparkline = []
            } else {
                bars = []
                sparkline = parseSpans(text)
            }
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
            font.pixelSize: Theme.fontPixelSize
            font.bold: Theme.fontBold
        }

        Item {
            id: chartHost
            visible: !root.loading && root.useNativeBars
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

        Row {
            spacing: 0
            visible: !root.loading && !root.useNativeBars && root.sparkline.length > 0
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: Theme.sparklineChartMargin
                height: 1
            }

            Repeater {
                model: root.sparkline
                Text {
                    required property var modelData
                    text: modelData.char
                    color: modelData.color
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
                    font.bold: Theme.fontBold
                }
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
