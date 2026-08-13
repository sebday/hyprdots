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
    readonly property string barScript: Quickshell.env("HOME") + "/.local/bin/evo-shell-layout.sh"
    readonly property string fontScript: Quickshell.env("HOME") + "/.local/bin/evo-font.sh"
    readonly property string resetScript: Quickshell.env("HOME") + "/.local/bin/evo-settings-reset.sh"
    readonly property string cleanupScript: Quickshell.env("HOME") + "/.local/bin/evo-cleanup.sh"
    readonly property string backupScript: Quickshell.env("HOME") + "/.local/bin/evo-backup.sh"
    readonly property string fontStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/evo-shell/font.json"

    property bool roundingOn: false
    property bool gapsOn: false
    property bool animationsOn: false
    property int activeOpacityPercent: 97
    property int inactiveOpacityPercent: 88
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
    readonly property bool settingsBusy: fontBusy || hyprToggleProc.running || hyprSetProc.running
        || barToggleProc.running || resetProc.running || cleanupProc.running || backupProc.running

    function refresh() {
        Theme.reloadLooks()
        if (!loadHyprProc.running) loadHyprProc.running = true
        if (!loadBarProc.running) loadBarProc.running = true
        if (!loadFontProc.running) loadFontProc.running = true
        if (!loadFontListProc.running) loadFontListProc.running = true
    }

    function toggleHypr(key) {
        if (!hyprReady || settingsBusy) return
        hyprToggleProc.target = key
        hyprToggleProc.running = true
    }

    function setHyprOpacity(key, percent) {
        if (!hyprReady || settingsBusy) return
        hyprSetProc.key = key
        hyprSetProc.value = String(percent)
        hyprSetProc.running = true
    }

    function toggleBar() {
        if (!barReady || settingsBusy) return
        barToggleProc.running = true
    }

    function setFont(key, value) {
        if (!fontReady || settingsBusy) return
        fontSetProc.key = key
        fontSetProc.value = String(value)
        fontSetProc.running = true
    }

    function onActivated() {
        refresh()
    }

    function resetDefaults() {
        if (!ready || settingsBusy) return
        resetProc.running = true
    }

    function parseHyprState(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.roundingOn = data.roundingOn === true
            root.gapsOn = data.gapsOn === true
            root.animationsOn = data.animationsOn === true
            root.activeOpacityPercent = Math.round(Number(data.activeOpacity || 0.97) * 100)
            root.inactiveOpacityPercent = Math.round(Number(data.inactiveOpacity || 0.88) * 100)
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
        onExited: Theme.reloadLooks()
    }

    Process {
        id: loadBarProc
        command: ["bash", root.barScript, "bar", "get"]
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
        onExited: Theme.reloadLooks()
    }

    Process {
        id: hyprSetProc
        property string key: ""
        property string value: ""
        command: ["bash", root.hyprScript, "set", hyprSetProc.key, hyprSetProc.value]
        stdout: StdioCollector {
            onStreamFinished: root.parseHyprState(text)
        }
        onExited: Theme.reloadLooks()
    }

    Process {
        id: barToggleProc
        command: ["bash", root.barScript, "bar", "toggle"]
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

    Process {
        id: resetProc
        command: ["bash", root.resetScript]
        onExited: root.refresh()
    }

    Process {
        id: cleanupProc
        command: ["bash", root.cleanupScript]
    }

    Process {
        id: backupProc
        command: ["bash", root.backupScript]
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
                        enabled: root.fontReady && !settingsBusy
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
                        enabled: root.fontReady && !settingsBusy
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
                        enabled: root.fontReady && !settingsBusy
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
                        enabled: root.hyprReady && !settingsBusy
                        onToggled: root.toggleHypr("rounding")
                    }

                    ToggleRow {
                        width: parent.width
                        label: "Window gaps"
                        detail: "On: 10px in 20px out"
                        checked: root.gapsOn
                        enabled: root.hyprReady && !settingsBusy
                        onToggled: root.toggleHypr("gaps")
                    }

                    ToggleRow {
                        width: parent.width
                        label: "Animations"
                        detail: "Bezier sliding"
                        checked: root.animationsOn
                        enabled: root.hyprReady && !settingsBusy
                        onToggled: root.toggleHypr("animations")
                    }

                    SliderSetting {
                        width: parent.width
                        label: "Active opacity"
                        value: root.activeOpacityPercent
                        valueSuffix: "%"
                        minimum: 0
                        maximum: 100
                        step: 1
                        enabled: root.hyprReady && !settingsBusy
                        onValueEdited: function(v) {
                            root.activeOpacityPercent = v
                        }
                        onValueCommitted: function(v) {
                            root.activeOpacityPercent = v
                            root.setHyprOpacity("active", v)
                        }
                    }

                    SliderSetting {
                        width: parent.width
                        label: "Inactive opacity"
                        value: root.inactiveOpacityPercent
                        valueSuffix: "%"
                        minimum: 0
                        maximum: 100
                        step: 1
                        enabled: root.hyprReady && !settingsBusy
                        onValueEdited: function(v) {
                            root.inactiveOpacityPercent = v
                        }
                        onValueCommitted: function(v) {
                            root.inactiveOpacityPercent = v
                            root.setHyprOpacity("inactive", v)
                        }
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
                    enabled: root.barReady && !settingsBusy
                    onToggled: root.toggleBar()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                Layout.topMargin: 2

                Row {
                    anchors.centerIn: parent
                    spacing: 20

                    Item {
                        width: cleanupText.implicitWidth
                        height: 28
                        opacity: !settingsBusy ? 1 : 0.35

                        Text {
                            id: cleanupText
                            anchors.centerIn: parent
                            text: cleanupProc.running ? "Clearing…" : "Clear"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: Theme.fontBold
                            opacity: cleanupMouse.containsMouse ? 1 : 0.72
                        }

                        MouseArea {
                            id: cleanupMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !settingsBusy
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: cleanupProc.running = true
                        }
                    }

                    Item {
                        width: backupText.implicitWidth
                        height: 28
                        opacity: !settingsBusy ? 1 : 0.35

                        Text {
                            id: backupText
                            anchors.centerIn: parent
                            text: backupProc.running ? "Backing up…" : "Backup"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: Theme.fontBold
                            opacity: backupMouse.containsMouse ? 1 : 0.72
                        }

                        MouseArea {
                            id: backupMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !settingsBusy
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: backupProc.running = true
                        }
                    }

                    Item {
                        width: resetText.implicitWidth
                        height: 28
                        opacity: root.ready && !settingsBusy ? 1 : 0.35

                        Text {
                            id: resetText
                            anchors.centerIn: parent
                            text: resetProc.running ? "Resetting…" : "Reset"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: Theme.fontBold
                            opacity: resetMouse.containsMouse ? 1 : 0.72
                        }

                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.ready && !settingsBusy
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.resetDefaults()
                        }
                    }
                }
            }
        }
    }
}
