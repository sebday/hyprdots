import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : ""
    readonly property string store: settings.store ? String(settings.store) : ""

    property bool loading: false
    property string storeLabel: ""
    property string currencySymbol: "£"
    property real todayRevenue: 0
    property var lastPayload: null

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: home + "/.local/bin/evo-bar-shopify"
    readonly property string storeIconUrl: {
        if (settings.iconUrl)
            return String(settings.iconUrl)
        if (store === "DIY")
            return "https://diybuildingsupplies.co.uk/cdn/shop/files/diy-square-logo-trans.png?crop=center&height=48&v=1770480698&width=48"
        if (store === "TGS")
            return "https://thegoodsheet.co.uk/cdn/shop/files/logo_osb.png?crop=center&height=48&v=1752889811&width=48"
        return ""
    }
    readonly property int storeIconSize: 18
    readonly property string storeIcon: {
        var label = storeLabel.trim()
        if (label)
            return label.charAt(0)
        if (store === "DIY") return "D"
        if (store === "TGS") return "T"
        return store ? store.charAt(0) : ""
    }
    readonly property string revenueText: {
        if (loading) return "…"
        if (todayRevenue > 0 || lastPayload)
            return Format.formatRevenue(todayRevenue, currencySymbol)
        return "—"
    }

    implicitWidth: contentRow.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    function applyJson(line) {
        loading = false
        var raw = String(line || "").trim()
        if (!raw) {
            lastPayload = null
            return
        }
        try {
            var json = JSON.parse(raw)
            lastPayload = json
            if (root.shell && root.hoverPopupId)
                root.shell.setHoverPopupData(root.hoverPopupId, json)
            if (json.store)
                storeLabel = String(json.store).trim()
            if (json.symbol)
                currencySymbol = String(json.symbol)
            todayRevenue = parseFloat(json.revenue)
            if (!isFinite(todayRevenue))
                todayRevenue = 0
        } catch (e) {
            console.warn("shopify widget parse failed:", store, e)
            lastPayload = null
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

    function setHoverPopup(active) {
        if (!shell || !hoverPopupId) return
        if (active)
            shell.hoverEnter(hoverPopupId, root, barPanel)
        else
            shell.hoverLeave(hoverPopupId)
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: !root.storeIconUrl || favicon.status !== Image.Ready
            text: root.storeIcon
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
            Layout.alignment: Qt.AlignVCenter
            opacity: 0.9
        }

        Item {
            Layout.preferredWidth: root.storeIconSize
            Layout.preferredHeight: root.storeIconSize
            Layout.maximumWidth: root.storeIconSize
            Layout.maximumHeight: root.storeIconSize
            Layout.alignment: Qt.AlignVCenter
            visible: root.storeIconUrl !== "" && favicon.status === Image.Ready
            clip: true

            Image {
                id: favicon
                anchors.fill: parent
                source: root.storeIconUrl
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(root.storeIconSize * 2, root.storeIconSize * 2)
            }
        }

        Text {
            text: root.revenueText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: root.applyJson(text)
        }
        onExited: root.loading = false
    }

    HoverHandler {
        enabled: root.hoverPopupId !== "" && root.shell
        onHoveredChanged: root.setHoverPopup(hovered)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: (root.settings.onClick || root.hoverPopupId) ? Qt.PointingHandCursor : Qt.ArrowCursor
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
