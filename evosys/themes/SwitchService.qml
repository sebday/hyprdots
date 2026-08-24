import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../commons"

Item {
    id: root

    property var shell: null

    readonly property int fadeMs: 200
    readonly property int watchdogMs: 45000

    property bool active: false
    property real iconOpacity: 0
    property int switchId: 0
    property int fadeOutId: 0

    function forceDismiss() {
        switchId++
        fadeOutId = switchId
        fadeIn.stop()
        fadeOut.stop()
        watchdogTimer.stop()
        active = false
        iconOpacity = 0
        return "ok"
    }

    function dismiss() {
        return forceDismiss()
    }

    function beginSwitch(payloadJson) {
        fadeIn.stop()
        fadeOut.stop()
        switchId++
        active = true
        iconOpacity = 0
        fadeIn.restart()
        watchdogTimer.restart()
        return "ok"
    }

    function endSwitch() {
        fadeIn.stop()
        if (!active)
            return "ok"
        fadeOutId = switchId
        watchdogTimer.stop()
        fadeOut.restart()
        return "ok"
    }

    Timer {
        id: watchdogTimer
        interval: root.watchdogMs
        repeat: false
        onTriggered: {
            console.warn("evo.sys.themes: switch indicator watchdog dismiss (endSwitch missed?)")
            root.forceDismiss()
        }
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "iconOpacity"
        from: 0
        to: 1
        duration: root.fadeMs
        easing.type: Easing.InOutQuad
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "iconOpacity"
        from: root.iconOpacity
        to: 0
        duration: root.fadeMs
        easing.type: Easing.InOutQuad
        onFinished: {
            if (root.fadeOutId !== root.switchId)
                return
            root.active = false
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

        function dismissSwitch(): string {
            return root.dismiss()
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

            Item {
                anchors.centerIn: parent
                visible: root.iconOpacity > 0
                opacity: root.iconOpacity

                Text {
                    id: switchIcon
                    anchors.centerIn: parent
                    text: "󰸌"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeHero
                    font.bold: Theme.fontBold

                    SequentialAnimation on opacity {
                        running: root.active && root.iconOpacity > 0
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
            }
        }
    }
}
