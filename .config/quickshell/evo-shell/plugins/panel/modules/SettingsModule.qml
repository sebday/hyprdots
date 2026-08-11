import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var panel: null
    property var shell: null

    readonly property string hyprScript: Quickshell.env("HOME") + "/.local/bin/evo-hypr-looks.sh"
    readonly property string barScript: Quickshell.env("HOME") + "/.local/bin/evo-bar-layout.sh"
    readonly property string panelScript: Quickshell.env("HOME") + "/.local/bin/evo-panel-layout.sh"

    property bool roundingOn: false
    property bool gapsOn: false
    property bool barOnDp1Top: false
    property bool panelOnRight: false
    property bool hyprReady: false
    property bool barReady: false
    property bool panelReady: false
    readonly property bool ready: hyprReady && barReady && panelReady

    function refresh() {
        if (!loadHyprProc.running) loadHyprProc.running = true
        if (!loadBarProc.running) loadBarProc.running = true
        if (!loadPanelProc.running) loadPanelProc.running = true
    }

    function toggleHypr(key) {
        if (!hyprReady || hyprToggleProc.running) return
        hyprToggleProc.target = key
        hyprToggleProc.running = true
    }

    function toggleBar() {
        if (!barReady || barToggleProc.running) return
        barToggleProc.running = true
    }

    function togglePanelSide() {
        if (!panelReady || panelToggleProc.running) return
        panelToggleProc.running = true
    }

    function onActivated() {
        refresh()
    }

    function parseHyprState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.roundingOn = data.roundingOn === true
            root.gapsOn = data.gapsOn === true
            root.hyprReady = true
        } catch (e) {
            root.hyprReady = false
        }
    }

    function parseBarState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.barOnDp1Top = data.barOnDp1Top === true
            root.barReady = true
        } catch (e) {
            root.barReady = false
        }
    }

    function parsePanelState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.panelOnRight = data.panelOnRight === true
            root.panelReady = true
        } catch (e) {
            root.panelReady = false
        }
    }

    Process {
        id: loadHyprProc
        command: ["bash", root.hyprScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
    }

    Process {
        id: loadBarProc
        command: ["bash", root.barScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBarState(text)
        }
    }

    Process {
        id: loadPanelProc
        command: ["bash", root.panelScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePanelState(text)
        }
    }

    Process {
        id: hyprToggleProc
        property string target: ""
        command: ["bash", root.hyprScript, "toggle", hyprToggleProc.target]
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
    }

    Process {
        id: barToggleProc
        command: ["bash", root.barScript, "toggle"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBarState(text)
        }
    }

    Process {
        id: panelToggleProc
        command: ["bash", root.panelScript, "toggle"]
        stdout: StdioCollector {
            onStreamFinished: root.parsePanelState(text)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        FramedPanel {
            label: "Hyprland"
            Layout.fillWidth: true

            Column {
                width: parent.width
                spacing: 12

                ToggleRow {
                    width: parent.width
                    label: "Border radius"
                    detail: "On: 7px"
                    checked: root.roundingOn
                    enabled: root.hyprReady && !hyprToggleProc.running
                    onToggled: root.toggleHypr("rounding")
                }

                ToggleRow {
                    width: parent.width
                    label: "Window gaps"
                    detail: "On: 10 in / 20 out"
                    checked: root.gapsOn
                    enabled: root.hyprReady && !hyprToggleProc.running
                    onToggled: root.toggleHypr("gaps")
                }
            }
        }

        FramedPanel {
            label: "Panel"
            Layout.fillWidth: true

            ToggleRow {
                width: parent.width
                label: "Panel on right"
                detail: "Off: left side"
                checked: root.panelOnRight
                enabled: root.panelReady && !panelToggleProc.running
                onToggled: root.togglePanelSide()
            }
        }

        FramedPanel {
            label: "Bar"
            Layout.fillWidth: true
            Layout.fillHeight: true

            ToggleRow {
                width: parent.width
                label: "Bar on DP-1 top"
                detail: "Off: HDMI-A-1 bottom"
                checked: root.barOnDp1Top
                enabled: root.barReady && !barToggleProc.running
                onToggled: root.toggleBar()
            }
        }
    }
}
