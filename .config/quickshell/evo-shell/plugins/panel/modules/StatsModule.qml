import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var panel: null
    property var shell: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string shopifyScript: home + "/.local/bin/evo-bar-shopify.sh"
    readonly property string btcScript: home + "/.local/bin/evo-bar-btc.sh"
    readonly property string spcxScript: home + "/.local/bin/evo-bar-spcx.sh"

    property var diyData: ({})
    property var tgsData: ({})
    property var btcData: ({})
    property var spcxData: ({})

    function onActivated() {
        refreshAll()
    }

    function refreshAll() {
        if (!diyProc.running) diyProc.running = true
        if (!tgsProc.running) tgsProc.running = true
        if (!btcProc.running) btcProc.running = true
        if (!spcxProc.running) spcxProc.running = true
    }

    function parseJson(raw) {
        try {
            return JSON.parse(String(raw || "{}").trim() || "{}")
        } catch (e) {
            return ({})
        }
    }

    function formatRevenue(val, symbol) {
        var n = Math.round(parseFloat(val) || 0)
        var s = String(n)
        var out = ""
        for (var i = 0; i < s.length; i++) {
            if (i > 0 && (s.length - i) % 3 === 0) out += ","
            out += s.charAt(i)
        }
        return String(symbol || "£") + out
    }

    function shopifyHeader(data, fallbackName) {
        if (!data || (data.revenue === undefined && !data.label))
            return fallbackName + " …"
        var sym = data.symbol || "£"
        var cos = data.cos || "—"
        var revenue = data.revenue !== undefined
            ? formatRevenue(data.revenue, sym)
            : String(data.label || "").replace(/^[A-Z]\s+/, "")
        var parts = [revenue, cos]
        if (typeof data.orders === "number")
            parts.push(data.orders + " orders")
        return parts.join(" · ")
    }

    function marketHeader(data, fallbackName) {
        if (!data) return fallbackName + " …"
        if (data.detail) return String(data.detail)
        if (data.text) return String(data.text)
        return fallbackName + " …"
    }

    function openUrl(url) {
        if (!url) return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(url)])
    }

    Process {
        id: diyProc
        command: ["bash", root.shopifyScript, "DIY"]
        stdout: StdioCollector {
            onStreamFinished: root.diyData = root.parseJson(text)
        }
    }

    Process {
        id: tgsProc
        command: ["bash", root.shopifyScript, "TGS"]
        stdout: StdioCollector {
            onStreamFinished: root.tgsData = root.parseJson(text)
        }
    }

    Process {
        id: btcProc
        command: ["bash", root.btcScript]
        stdout: StdioCollector {
            onStreamFinished: root.btcData = root.parseJson(text)
        }
    }

    Process {
        id: spcxProc
        command: ["bash", root.spcxScript]
        stdout: StdioCollector {
            onStreamFinished: root.spcxData = root.parseJson(text)
        }
    }

    Timer {
        interval: 300000
        running: root.panel && root.panel.opened && root.panel.activeModule === "stats"
        repeat: true
        onTriggered: {
            if (!diyProc.running) diyProc.running = true
            if (!tgsProc.running) tgsProc.running = true
        }
    }

    Timer {
        interval: 60000
        running: root.panel && root.panel.opened && root.panel.activeModule === "stats"
        repeat: true
        onTriggered: {
            if (!btcProc.running) btcProc.running = true
            if (!spcxProc.running) spcxProc.running = true
        }
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: statsColumn.implicitHeight + 10
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: statsColumn
            width: parent.width
            y: 10
            spacing: 16

            FramedPanel {
                label: "DIY"
                contentFill: true
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                Column {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.shopifyHeader(root.diyData, "DIY")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openUrl("https://admin.shopify.com/store/diy-buildingsupplies/analytics/live")
                        }
                    }

                    SparklineChart {
                        width: parent.width
                        height: 72
                        bars: root.diyData.bars || []
                        valuePrefix: root.diyData.symbol || "£"
                        chartHeight: 54
                    }
                }
            }

            FramedPanel {
                label: "TGS"
                contentFill: true
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                Column {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.shopifyHeader(root.tgsData, "TGS")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openUrl("https://admin.shopify.com/store/thegoodsheet-uk/analytics/live")
                        }
                    }

                    SparklineChart {
                        width: parent.width
                        height: 72
                        bars: root.tgsData.bars || []
                        valuePrefix: root.tgsData.symbol || "£"
                        chartHeight: 54
                    }
                }
            }

            FramedPanel {
                label: "BTC"
                contentFill: true
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                Column {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.marketHeader(root.btcData, "BTC")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openUrl("https://www.tradingview.com/symbols/BTCUSD/")
                        }
                    }

                    SparklineChart {
                        width: parent.width
                        height: 72
                        bars: root.btcData.bars || []
                        valuePrefix: "$"
                        chartHeight: 54
                        style: "line"
                    }
                }
            }

            FramedPanel {
                label: "SPCX"
                contentFill: true
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                Column {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.marketHeader(root.spcxData, "SPCX")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openUrl("https://app.trading212.com/")
                        }
                    }

                    SparklineChart {
                        width: parent.width
                        height: 72
                        bars: root.spcxData.bars || []
                        valuePrefix: "$"
                        chartHeight: 54
                        style: "line"
                    }
                }
            }
        }
    }
}
