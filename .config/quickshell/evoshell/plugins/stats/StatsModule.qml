import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true
    readonly property int headerFont: Theme.panelTitleFontPixelSize

    property var diyData: ({})
    property var tgsData: ({})
    property var btcData: ({})
    property var spcxData: ({})

    function onActivated() {
        refreshAll()
    }

    function refreshAll() {
        diyPoll.runPoll()
        tgsPoll.runPoll()
        btcPoll.runPoll()
        spcxPoll.runPoll()
    }

    function headerLines(parts, fallback) {
        if (!parts || parts.length === 0)
            return fallback
        if (parts.length === 1)
            return parts[0]
        return parts[0] + "\n" + parts.slice(1).join(" · ")
    }

    function shopifyHeader(data, fallbackName) {
        if (!data || (data.revenue === undefined && !data.label))
            return fallbackName + " …"
        var sym = data.symbol || "£"
        var cos = data.cos || "—"
        var revenue = data.revenue !== undefined
            ? Format.formatRevenue(data.revenue, sym)
            : String(data.label || "").replace(/^[A-Z]\s+/, "")
        var rest = [cos]
        if (typeof data.orders === "number")
            rest.push(data.orders + " orders")
        return headerLines([revenue].concat(rest), fallbackName + " …")
    }

    function marketHeader(data, fallbackName) {
        if (!data) return fallbackName + " …"
        var raw = data.detail ? String(data.detail) : (data.text ? String(data.text) : "")
        if (!raw)
            return fallbackName + " …"
        return headerLines(raw.split(" · "), fallbackName + " …")
    }

    function openUrl(url) {
        if (!url) return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(url)])
    }

    component ChartHeader: Item {
        id: header
        property string value: ""
        property string href: ""

        Layout.fillWidth: true
        implicitHeight: headerCol.implicitHeight
        implicitWidth: headerCol.implicitWidth

        readonly property string primary: {
            var parts = String(header.value).split("\n")
            return parts[0] || ""
        }
        readonly property string secondary: {
            var parts = String(header.value).split("\n")
            return parts.slice(1).join(" · ")
        }

        ColumnLayout {
            id: headerCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: header.primary
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.headerFont
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: header.secondary !== ""
                text: header.secondary
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelHintFontPixelSize
                font.bold: Theme.fontBold
                opacity: 0.72
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openUrl(header.href)
        }
    }

    JsonPollRunner {
        id: diyPoll
        active: root.active
        defaultIntervalSec: 300
        command: ["bash", root.home + "/.local/bin/evo-bar-shopify", "DIY"]
        onPolled: function(json) { root.diyData = json }
    }

    JsonPollRunner {
        id: tgsPoll
        active: root.active
        defaultIntervalSec: 300
        command: ["bash", root.home + "/.local/bin/evo-bar-shopify", "TGS"]
        onPolled: function(json) { root.tgsData = json }
    }

    JsonPollRunner {
        id: btcPoll
        active: root.active
        defaultIntervalSec: 60
        command: ["bash", root.home + "/.local/bin/evo-bar-btc"]
        onPolled: function(json) { root.btcData = json }
    }

    JsonPollRunner {
        id: spcxPoll
        active: root.active
        defaultIntervalSec: 60
        command: ["bash", root.home + "/.local/bin/evo-bar-spcx"]
        onPolled: function(json) { root.spcxData = json }
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: 8
        columns: 2
        columnSpacing: 12
        rowSpacing: 12

        FramedPanel {
            label: "DIY"
            contentFill: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.column: 0
            Layout.row: 0

            ColumnLayout {
                anchors.fill: parent
                spacing: 14

                ChartHeader {
                    value: root.shopifyHeader(root.diyData, "DIY")
                    href: "https://admin.shopify.com/store/diy-buildingsupplies/analytics/live"
                }

                SparklineChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    bars: root.diyData.bars || []
                }
            }
        }

        FramedPanel {
            label: "TGS"
            contentFill: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.column: 1
            Layout.row: 0

            ColumnLayout {
                anchors.fill: parent
                spacing: 14

                ChartHeader {
                    value: root.shopifyHeader(root.tgsData, "TGS")
                    href: "https://admin.shopify.com/store/thegoodsheet-uk/analytics/live"
                }

                SparklineChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    bars: root.tgsData.bars || []
                }
            }
        }

        FramedPanel {
            label: "BTC"
            contentFill: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.column: 0
            Layout.row: 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 14

                ChartHeader {
                    value: root.marketHeader(root.btcData, "BTC")
                    href: "https://www.tradingview.com/symbols/BTCUSD/"
                }

                SparklineChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    bars: root.btcData.bars || []
                    style: "line"
                }
            }
        }

        FramedPanel {
            label: "SPCX"
            contentFill: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.column: 1
            Layout.row: 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 14

                ChartHeader {
                    value: root.marketHeader(root.spcxData, "SPCX")
                    href: "https://app.trading212.com/"
                }

                SparklineChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    bars: root.spcxData.bars || []
                    style: "line"
                }
            }
        }
    }
}
