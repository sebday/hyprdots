import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true

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

    function shopifyHeader(data, fallbackName) {
        if (!data || (data.revenue === undefined && !data.label))
            return fallbackName + " …"
        var sym = data.symbol || "£"
        var cos = data.cos || "—"
        var revenue = data.revenue !== undefined
            ? Format.formatRevenue(data.revenue, sym)
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

    JsonPollRunner {
        id: diyPoll
        active: root.active
        defaultIntervalSec: 300
        command: ["bash", root.home + "/.local/bin/evo-bar-shopify.sh", "DIY"]
        onPolled: function(json) { root.diyData = json }
    }

    JsonPollRunner {
        id: tgsPoll
        active: root.active
        defaultIntervalSec: 300
        command: ["bash", root.home + "/.local/bin/evo-bar-shopify.sh", "TGS"]
        onPolled: function(json) { root.tgsData = json }
    }

    JsonPollRunner {
        id: btcPoll
        active: root.active
        defaultIntervalSec: 60
        command: ["bash", root.home + "/.local/bin/evo-bar-btc.sh"]
        onPolled: function(json) { root.btcData = json }
    }

    JsonPollRunner {
        id: spcxPoll
        active: root.active
        defaultIntervalSec: 60
        command: ["bash", root.home + "/.local/bin/evo-bar-spcx.sh"]
        onPolled: function(json) { root.spcxData = json }
    }

    GridLayout {
        anchors.fill: parent
        columns: 2
        columnSpacing: 12
        rowSpacing: 12

        FramedPanel {
            label: "DIY"
            contentFill: true
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    width: parent.width
                    text: root.shopifyHeader(root.diyData, "DIY")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelSmallFontPixelSize
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
            Layout.fillHeight: true

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    width: parent.width
                    text: root.shopifyHeader(root.tgsData, "TGS")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelSmallFontPixelSize
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
            Layout.fillHeight: true

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    width: parent.width
                    text: root.marketHeader(root.btcData, "BTC")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelSmallFontPixelSize
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
            Layout.fillHeight: true

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    width: parent.width
                    text: root.marketHeader(root.spcxData, "SPCX")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelSmallFontPixelSize
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
