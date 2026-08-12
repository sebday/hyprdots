import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true && host.activeModule === "stats"

    property var diyData: ({})
    property var tgsData: ({})

    function onActivated() {
        refreshAll()
    }

    function refreshAll() {
        diyPoll.runPoll()
        tgsPoll.runPoll()
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
            spacing: 14

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
                Layout.preferredHeight: 140

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
        }
    }
}
