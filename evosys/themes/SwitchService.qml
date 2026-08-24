import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../commons"

Item {
    id: root

    property var shell: null

    readonly property int fadeMs: 200

    property bool active: false
    property real fadeOpacity: 0
    property color fillColor: Theme.background

    function parseBackground(payloadJson) {
        var text = String(payloadJson || "").trim()
        if (!text)
            return ""
        try {
            var data = JSON.parse(text)
            return String(data.background || "").trim()
        } catch (e) {
            return ""
        }
    }

    function beginSwitch(payloadJson) {
        var bg = parseBackground(payloadJson)
        fillColor = bg ? bg : Theme.background
        fadeOut.stop()
        fadeIn.stop()
        active = true
        // Snap on — compositor may stall during GTK reload before a fade-in paints.
        fadeOpacity = 1
        return "ok"
    }

    function endSwitch() {
        fadeIn.stop()
        if (!active)
            return "ok"
        fadeOut.restart()
        return "ok"
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "fadeOpacity"
        from: 0
        to: 1
        duration: root.fadeMs
        easing.type: Easing.InOutQuad
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "fadeOpacity"
        from: root.fadeOpacity
        to: 0
        duration: root.fadeMs
        easing.type: Easing.InOutQuad
        onFinished: root.active = false
    }

    component SwitchChrome: Column {
        spacing: Theme.spacingL

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰸌"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeHero
            font.bold: Theme.fontBold

            SequentialAnimation on opacity {
                running: root.active && root.fadeOpacity > 0
                loops: Animation.Infinite
                NumberAnimation {
                    from: Theme.barIconPulseMin
                    to: Theme.barIconPulseMax
                    duration: Theme.barIconPulseDuration
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: Theme.barIconPulseMax
                    to: Theme.barIconPulseMin
                    duration: Theme.barIconPulseDuration
                    easing.type: Easing.InOutSine
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Switching theme…"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.bold: Theme.fontBold
            opacity: Theme.opacitySecondary
        }
    }

    IpcHandler {
        target: "evo.sys.themes"

        function beginSwitch(payloadJson: string): string {
            return root.beginSwitch(payloadJson)
        }

        function endSwitch(): string {
            return root.endSwitch()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: root.active
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            WlrLayershell.namespace: "evo-sys-themes-switch"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Rectangle {
                anchors.fill: parent
                color: root.fillColor
                opacity: root.fadeOpacity
            }

            SwitchChrome {
                anchors.centerIn: parent
                visible: root.fadeOpacity > 0
                opacity: root.fadeOpacity
            }
        }
    }
}
