import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property int tooltipWidth: 0

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true

    property var btcData: ({})
    property var spcxData: ({})

    function onActivated() {
        refreshAll()
    }

    function refreshAll() {
        btcPoll.runPoll()
        spcxPoll.runPoll()
    }

    function marketHeader(data, fallbackName) {
        if (!data) return fallbackName + " …"
        var raw = data.detail ? String(data.detail) : (data.text ? String(data.text) : "")
        if (!raw)
            return fallbackName + " …"
        return Format.headerLines(raw.split(" · "), fallbackName + " …")
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

    ColumnLayout {
        width: root.tooltipWidth
        spacing: Theme.tooltipSectionSpacing

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12

            SectionPanel {
                label: "BTC"
                Layout.fillWidth: true

                TooltipHeader {
                    Layout.fillWidth: true
                    value: root.marketHeader(root.btcData, "BTC")
                    href: "https://www.tradingview.com/symbols/BTCUSD/"
                }

                SparklineChart {
                    Layout.fillWidth: true
                    bars: root.btcData.bars || []
                    style: "line"
                }
            }

            SectionPanel {
                label: "SPCX"
                Layout.fillWidth: true

                TooltipHeader {
                    Layout.fillWidth: true
                    value: root.marketHeader(root.spcxData, "SPCX")
                    href: "https://app.trading212.com/"
                }

                SparklineChart {
                    Layout.fillWidth: true
                    bars: root.spcxData.bars || []
                    style: "line"
                }
            }
        }
    }
}
