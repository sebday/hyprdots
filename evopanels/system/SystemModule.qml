import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPanelWidth: 0

    readonly property string cacheKey: shell ? String(shell.hoverPanelId || "") : ""
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int valueFont: Theme.fontSizeXl
    readonly property int labelWidth: 76
    readonly property int actionIconFont: Theme.fontSize4xl
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string evoshellBin: shell ? shell.evoshellBin : Util.evoshellBinPath(home, shell)
    readonly property var powerActions: [
        { label: "Restart", icon: "󰑐", action: "restart" },
        { label: "Shutdown", icon: "󰐥", action: "shutdown" }
    ]

    property bool loading: false
    property var lines: []
    property string hostName: ""
    property string osName: ""
    property int cpuPercent: 0
    property int memPercent: 0
    property int diskPercent: 0
    property string memWarning: ""
    property var memHogs: []

    implicitHeight: column.implicitHeight

    readonly property var resourcePills: [
        { label: "CPU", percent: root.cpuPercent, color: Format.loadPercentColor(root.cpuPercent) },
        { label: "RAM", percent: root.memPercent, color: Format.usagePercentColor(root.memPercent) },
        { label: "Disk", percent: root.diskPercent, color: Format.usagePercentColor(root.diskPercent) }
    ]

    readonly property var detailLines: {
        var skip = { cpu: true, memory: true, disk: true }
        var out = []
        for (var i = 0; i < lines.length; i++) {
            var label = String(lines[i].label || "")
            if (!skip[label])
                out.push(lines[i])
        }
        return out
    }

    readonly property string headerValue: {
        var parts = []
        if (hostName)
            parts.push(hostName)
        if (osName)
            parts.push(osName)
        return parts.join("\n")
    }

    function onActivated() {
        syncFromBar()
    }

    function bootstrapFromCache() {
        if (!cacheKey || !shell)
            return
        var cached = Util.hoverPanelCacheRead(shell, cacheKey)
        if (cached)
            applyPayload(cached)
    }

    function publishCache(json) {
        if (cacheKey && shell && json && typeof json === "object")
            Util.hoverPanelCacheWrite(shell, cacheKey, json)
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.loading) {
            if (lines.length === 0)
                loading = true
            return
        }
        if (item && item.lastPayload)
            applyPayload(item.lastPayload)
        else {
            var cached = Util.hoverPanelCacheRead(shell, cacheKey)
            if (cached)
                applyPayload(cached)
            else
                applyPayload(null)
        }
    }

    function dismissHost() {
        if (host && typeof host.close === "function")
            host.close()
        else if (shell)
            shell.hide("evo.panels.system")
    }

    function runEvoCommand(args) {
        if (!shell)
            return
        dismissHost()
        Quickshell.execDetached(Util.evoCommand(home, args))
    }

    function openSettings() {
        if (!shell)
            return
        dismissHost()
        shell.summon("evo.sys.settings", "")
    }

    function runPowerAction(action) {
        if (action === "restart")
            runEvoCommand(["system", "restart"])
        else if (action === "shutdown")
            runEvoCommand(["system", "shutdown"])
    }

    function applyPayload(json) {
        loading = false
        if (!json || typeof json !== "object") {
            lines = []
            hostName = ""
            osName = ""
            cpuPercent = 0
            memPercent = 0
            diskPercent = 0
            memWarning = ""
            memHogs = []
            return
        }
        hostName = String(json.host || "")
        osName = String(json.os || "")
        cpuPercent = parseInt(json.cpuPercent, 10) || 0
        memPercent = parseInt(json.memPercent, 10) || 0
        diskPercent = parseInt(json.diskPercent, 10) || 0
        memWarning = String(json.memWarning || "")
        memHogs = Array.isArray(json.memHogs) ? json.memHogs : []
        lines = Array.isArray(json.lines) ? json.lines : []
        publishCache(json)
    }

    onActiveChanged: if (active) syncFromBar()
    onBarSourceChanged: if (active) syncFromBar()

    readonly property var barLastPayload: root.barSource ? root.barSource.lastPayload : null
    readonly property bool barLoading: root.barSource ? !!root.barSource.loading : false

    onBarLastPayloadChanged: if (root.active) root.syncFromBar()
    onBarLoadingChanged: if (root.active) root.syncFromBar()

    ColumnLayout {
        id: column
        width: root.hoverPanelWidth
        spacing: Theme.hoverPanelSectionSpacing

        Text {
            Layout.fillWidth: true
            visible: root.loading
            text: "Loading system info…"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
            font.bold: Theme.fontBold
        }

        SectionPanel {
            label: ""
            visible: !root.loading && root.cpuPercent >= 80

            Text {
                Layout.fillWidth: true
                text: "High CPU load — " + root.cpuPercent + "%"
                color: Theme.urgent
                font.family: Theme.fontFamily
                font.pixelSize: root.bodyFont
                font.bold: Theme.fontBold
                wrapMode: Text.WordWrap
            }
        }

        SectionPanel {
            label: ""
            visible: !root.loading && root.headerValue !== ""

            HoverPanelLabelPill {
                text: "System"
                icon: "󰍛"
                fontSize: Theme.fontSizeS
            }

            HoverPanelHeader {
                Layout.fillWidth: true
                value: root.headerValue
            }
        }

        SectionPanel {
            label: ""
            visible: !root.loading

            HoverPanelLabelPill {
                text: "Resources"
                icon: "󰘚"
                fontSize: Theme.fontSizeS
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Repeater {
                    model: root.resourcePills

                    HoverPanelLabelPill {
                        required property var modelData
                        text: modelData.label + " " + modelData.percent + "%"
                        fontSize: Theme.fontSizeS
                        textColor: modelData.color
                        fill: Theme.withOpacity(modelData.color, 0.14)
                        textOpacity: 1
                        fieldsetLegend: false
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        SectionPanel {
            label: ""
            visible: !root.loading && root.detailLines.length > 0

            HoverPanelLabelPill {
                text: "Details"
                icon: "󰋼"
                fontSize: Theme.fontSizeS
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: root.detailLines

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Text {
                            Layout.preferredWidth: root.labelWidth
                            text: {
                                if (modelData.label === "warning")
                                    return "memory"
                                return String(modelData.label || "")
                            }
                            color: modelData.label === "warning" ? Theme.urgent : Theme.foreground
                            opacity: modelData.label === "warning" ? 1 : 0.55
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: String(modelData.value || "—")
                            color: modelData.label === "warning" ? Theme.urgent : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.valueFont
                            font.bold: Theme.fontBold
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: !root.loading
            implicitHeight: actionRow.implicitHeight

            RowLayout {
                id: actionRow
                anchors.left: parent.left
                spacing: 16

                Item {
                    implicitWidth: settingsIcon.implicitWidth
                    implicitHeight: settingsIcon.implicitHeight

                    Text {
                        id: settingsIcon
                        text: "󰒓"
                        color: settingsBtn.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.actionIconFont
                        font.bold: Theme.fontBold
                    }

                    MouseArea {
                        id: settingsBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSettings()
                    }
                }

                Repeater {
                    model: root.powerActions

                    Item {
                        required property var modelData
                        implicitWidth: powerIcon.implicitWidth
                        implicitHeight: powerIcon.implicitHeight

                        Text {
                            id: powerIcon
                            text: modelData.icon
                            color: powerBtn.containsMouse ? Theme.accent : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.actionIconFont
                            font.bold: Theme.fontBold
                        }

                        MouseArea {
                            id: powerBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runPowerAction(modelData.action)
                        }
                    }
                }
            }
        }
    }
}
