import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null

    readonly property string hyprScript: Quickshell.env("HOME") + "/.local/bin/evo-hypr-looks.sh"
    readonly property string barScript: Quickshell.env("HOME") + "/.local/bin/evo-bar-layout.sh"
    readonly property string fontScript: Quickshell.env("HOME") + "/.local/bin/evo-font.sh"
    readonly property string fontStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/evo-shell/font.json"

    property bool roundingOn: false
    property bool gapsOn: false
    property bool animationsOn: false
    property bool barOnDp1Top: false
    property string fontFamily: "CaskaydiaMono Nerd Font"
    property int fontScalePercent: 100
    property int fontBaseSize: 13
    property var fontFamilies: []
    property bool hyprReady: false
    property bool barReady: false
    property bool fontReady: false
    readonly property bool ready: hyprReady && barReady && fontReady
    readonly property bool fontBusy: fontSetProc.running

    function refresh() {
        if (!loadHyprProc.running) loadHyprProc.running = true
        if (!loadBarProc.running) loadBarProc.running = true
        if (!loadFontProc.running) loadFontProc.running = true
        if (!loadFontListProc.running) loadFontListProc.running = true
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

    function setFont(key, value) {
        if (!fontReady || fontBusy) return
        fontSetProc.key = key
        fontSetProc.value = String(value)
        fontSetProc.running = true
    }

    function onActivated() {
        refresh()
    }

    function parseHyprState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.roundingOn = data.roundingOn === true
            root.gapsOn = data.gapsOn === true
            root.animationsOn = data.animationsOn === true
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

    function parseFontState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            if (data.family)
                root.fontFamily = String(data.family)
            if (typeof data.baseFontSize === "number")
                root.fontBaseSize = data.baseFontSize
            if (typeof data.scalePercent === "number")
                root.fontScalePercent = data.scalePercent
            else if (typeof data.textSize === "number")
                root.fontScalePercent = 100 + (data.textSize - (root.fontBaseSize - 2)) * 10
            root.fontReady = true
        } catch (e) {
            root.fontReady = false
        }
    }

    function parseFontList(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.fontFamilies = Array.isArray(data.families) ? data.families : []
        } catch (e) {
            root.fontFamilies = []
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
        id: loadFontProc
        command: ["bash", root.fontScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseFontState(text)
        }
    }

    FileView {
        id: fontStateFile
        path: root.fontStatePath
        watchChanges: true
        printErrors: false
        onLoaded: root.parseFontState(fontStateFile.text())
        onFileChanged: reload()
    }

    Process {
        id: loadFontListProc
        command: ["bash", root.fontScript, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parseFontList(text)
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
        id: fontSetProc
        property string key: ""
        property string value: ""
        command: ["bash", root.fontScript, "set", fontSetProc.key, fontSetProc.value]
        stdout: StdioCollector {
            onStreamFinished: root.parseFontState(text)
        }
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        // Extra top pad so FramedPanel labels (y: -7) aren't clipped.
        contentHeight: settingsColumn.implicitHeight + 10
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: settingsColumn
            width: parent.width
            y: 10
            spacing: 16

            FramedPanel {
                label: "Font"
                Layout.fillWidth: true

                Column {
                    width: parent.width
                    spacing: 14

                    FontFamilyPicker {
                        width: parent.width
                        label: "Family"
                        value: root.fontFamily
                        model: root.fontFamilies
                        enabled: root.fontReady && !root.fontBusy
                        onActivated: function(family) {
                            root.fontFamily = family
                            root.setFont("family", family)
                        }
                    }

                    SliderSetting {
                        width: parent.width
                        label: "Base size"
                        value: root.fontBaseSize
                        valueSuffix: "px"
                        minimum: 9
                        maximum: 28
                        step: 1
                        enabled: root.fontReady && !root.fontBusy
                        onValueEdited: function(v) {
                            root.fontBaseSize = v
                        }
                        onValueCommitted: function(v) {
                            root.fontBaseSize = v
                            root.setFont("base", v)
                        }
                    }

                    SliderSetting {
                        width: parent.width
                        label: "Zoom level"
                        value: root.fontScalePercent
                        valueSuffix: "%"
                        minimum: 50
                        maximum: 150
                        step: 10
                        enabled: root.fontReady && !root.fontBusy
                        onValueEdited: function(v) {
                            root.fontScalePercent = v
                        }
                        onValueCommitted: function(v) {
                            root.fontScalePercent = v
                            root.setFont("zoom", v)
                        }
                    }

                }
            }

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
                        detail: "On: 10px in / 20px out"
                        checked: root.gapsOn
                        enabled: root.hyprReady && !hyprToggleProc.running
                        onToggled: root.toggleHypr("gaps")
                    }

                    ToggleRow {
                        width: parent.width
                        label: "Animations"
                        detail: "Window / workspace motion"
                        checked: root.animationsOn
                        enabled: root.hyprReady && !hyprToggleProc.running
                        onToggled: root.toggleHypr("animations")
                    }
                }
            }

            FramedPanel {
                label: "Bar"
                Layout.fillWidth: true

                ToggleRow {
                    width: parent.width
                    label: "Bar position"
                    detail: "On: Main screen"
                    checked: root.barOnDp1Top
                    enabled: root.barReady && !barToggleProc.running
                    onToggled: root.toggleBar()
                }
            }
        }
    }
}
