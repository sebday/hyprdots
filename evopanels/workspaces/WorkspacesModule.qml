import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPanelWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string layoutScript: Util.evoshellScript(home, shell, "evo-layout")
    readonly property bool contentReady: root.barReady && root.notificationsReady

    property string barOutput: ""
    property string barPosition: "bottom"
    property string notificationsOutput: ""
    property string notificationsPosition: "bottom"
    property bool barReady: false
    property bool notificationsReady: false
    property bool layoutBusy: false

    implicitHeight: column.implicitHeight

    function onActivated() {
        refreshLayoutState()
    }

    function refreshLayoutState() {
        if (!loadBarProc.running)
            loadBarProc.running = true
        if (!loadNotificationsProc.running)
            loadNotificationsProc.running = true
    }

    function parseBarState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.barOutput = String(data.output || "")
            root.barPosition = String(data.position || "bottom")
            root.barReady = true
        } catch (e) {
            root.barReady = false
        }
    }

    function parseNotificationsState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.notificationsOutput = String(data.output || "")
            root.notificationsPosition = String(data.position || "bottom")
            root.notificationsReady = true
        } catch (e) {
            root.notificationsReady = false
        }
    }

    function setBar(output, position) {
        if (layoutBusy)
            return
        var out = String(output || "")
        var pos = String(position || "")
        if (!out || (pos !== "top" && pos !== "bottom"))
            return
        barSetProc.output = out
        barSetProc.position = pos
        barSetProc.running = true
    }

    function setNotifications(output, position) {
        if (layoutBusy)
            return
        var out = String(output || "")
        var pos = String(position || "")
        if (!out || (pos !== "top" && pos !== "bottom"))
            return
        notificationsSetProc.output = out
        notificationsSetProc.position = pos
        notificationsSetProc.running = true
    }

    function switchWorkspace(workspaceId) {
        if (!isFinite(workspaceId) || workspaceId <= 0)
            return
        Hyprland.dispatch("workspace " + workspaceId)
    }

    onActiveChanged: if (active) refreshLayoutState()

    Process {
        id: loadBarProc
        command: ["bash", root.layoutScript, "bar", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBarState(text)
        }
    }

    Process {
        id: loadNotificationsProc
        command: ["bash", root.layoutScript, "notifications", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseNotificationsState(text)
        }
    }

    Process {
        id: barSetProc
        property string output: ""
        property string position: ""
        command: ["bash", root.layoutScript, "bar", "set", barSetProc.output, barSetProc.position]
        onRunningChanged: root.layoutBusy = running || notificationsSetProc.running
        stdout: StdioCollector {
            onStreamFinished: root.parseBarState(text)
        }
    }

    Process {
        id: notificationsSetProc
        property string output: ""
        property string position: ""
        command: ["bash", root.layoutScript, "notifications", "set", notificationsSetProc.output, notificationsSetProc.position]
        onRunningChanged: root.layoutBusy = running || barSetProc.running
        stdout: StdioCollector {
            onStreamFinished: root.parseNotificationsState(text)
        }
    }

    ColumnLayout {
        id: column
        width: root.hoverPanelWidth
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            label: ""
            Layout.fillWidth: true

            HoverPanelLabelPill {
                text: "Display"
                icon: "󰍹"
                fontSize: Theme.fontSizeS
            }

            MonitorLayoutPicker {
                Layout.fillWidth: true
                barOutput: root.barOutput
                barPosition: root.barPosition
                notificationsOutput: root.notificationsOutput
                notificationsPosition: root.notificationsPosition
                enabled: root.barReady && root.notificationsReady && !root.layoutBusy
                onBarChosen: function(output, position) {
                    root.setBar(output, position)
                }
                onNotificationsChosen: function(output, position) {
                    root.setNotifications(output, position)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingS
                Layout.preferredHeight: workspaceRow.implicitHeight

                Row {
                    id: workspaceRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingS

                    Repeater {
                        model: Hyprland.workspaces

                        delegate: HoverPanelLabelPill {
                            required property var modelData
                            readonly property int workspaceId: modelData ? Number(modelData.id) : 0
                            readonly property bool workspaceVisible: isFinite(workspaceId) && workspaceId > 0
                            readonly property bool focused: Hyprland.focusedWorkspace
                                && modelData
                                && modelData.id === Hyprland.focusedWorkspace.id

                            visible: workspaceVisible
                            text: String(workspaceId)
                            fontSize: Theme.fontSizeS
                            textColor: focused ? Theme.accent : Theme.foreground
                            fill: focused ? Theme.withOpacity(Theme.accent, 0.14) : Theme.foregroundWash
                            textOpacity: 1
                            fieldsetLegend: false
                            clickable: true
                            onClicked: root.switchWorkspace(workspaceId)
                        }
                    }
                }
            }
        }
    }
}
