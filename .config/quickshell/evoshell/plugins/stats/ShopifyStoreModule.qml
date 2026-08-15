import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property int tooltipWidth: 0
    property string storeKey: "DIY"
    property string title: "DIY"
    property string adminUrl: ""

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null

    property var storeData: ({})

    implicitHeight: body.implicitHeight

    function onActivated() {
        syncFromBar()
        storePoll.runPoll()
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.store === storeKey && item.lastPayload)
            applyPayload(item.lastPayload)
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
        return Format.headerLines([revenue].concat(rest), fallbackName + " …")
    }

    function applyPayload(json) {
        if (!json || typeof json !== "object")
            storeData = ({})
        else
            storeData = json
    }

    onActiveChanged: if (active) syncFromBar()
    onBarSourceChanged: if (active) syncFromBar()

    Connections {
        target: root.barSource
        enabled: root.barSource !== null
        function onLastPayloadChanged() {
            if (root.active) root.syncFromBar()
        }
        function onStoreChanged() {
            if (root.active) root.syncFromBar()
        }
    }

    JsonPollRunner {
        id: storePoll
        active: root.active
        defaultIntervalSec: 300
        command: ["bash", root.home + "/.local/bin/evo-bar-shopify", root.storeKey]
        onPolled: function(json) { root.applyPayload(json) }
    }

    ColumnLayout {
        id: body
        width: root.tooltipWidth
        spacing: 0

        SectionPanel {
            label: root.title

            TooltipHeader {
                Layout.fillWidth: true
                value: root.shopifyHeader(root.storeData, root.title)
                href: root.adminUrl
            }

            SparklineChart {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                Layout.minimumHeight: 80
                bars: root.storeData.bars || []
            }
        }
    }
}
