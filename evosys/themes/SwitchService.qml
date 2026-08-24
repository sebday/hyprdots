import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../commons"

Item {
    id: root

    property var shell: null

    readonly property int fadeInMs: 140
    readonly property int fadeOutMs: 140
    readonly property int watchdogMs: 45000
    readonly property real peakAlpha: 0.55

    property bool active: false
    property color fromColor: Theme.background
    property color toColor: Theme.background
    property real overlayOpacity: 0
    property real colorBlend: 0
    property int switchId: 0
    property int fadeOutId: 0

    function parseColor(value, fallback) {
        var text = String(value || "").trim()
        if (!text)
            return fallback
        var parsed = Qt.color(text)
        return parsed.a > 0 ? parsed : fallback
    }

    function parsePayload(payloadJson) {
        var text = String(payloadJson || "").trim()
        if (!text)
            return { from: "", to: "" }
        try {
            var data = JSON.parse(text)
            return {
                from: String(data.fromBackground || data.background || "").trim(),
                to: String(data.toBackground || data.background || "").trim()
            }
        } catch (e) {
            return { from: "", to: "" }
        }
    }

    function forceDismiss() {
        switchId++
        fadeOutId = switchId
        fadeInAnim.stop()
        fadeOutAnim.stop()
        colorBlendAnim.stop()
        watchdogTimer.stop()
        active = false
        overlayOpacity = 0
        colorBlend = 0
        return "ok"
    }

    function dismiss() {
        return forceDismiss()
    }

    function beginSwitch(payloadJson) {
        var colors = parsePayload(payloadJson)
        fromColor = parseColor(colors.from, Theme.background)
        toColor = parseColor(colors.to, Theme.background)
        fadeInAnim.stop()
        fadeOutAnim.stop()
        colorBlendAnim.stop()
        switchId++
        active = true
        overlayOpacity = 0
        colorBlend = 0
        fadeInAnim.restart()
        colorBlendAnim.restart()
        watchdogTimer.restart()
        return "ok"
    }

    function endSwitch() {
        fadeInAnim.stop()
        colorBlendAnim.stop()
        if (!active)
            return "ok"
        fadeOutId = switchId
        watchdogTimer.stop()
        colorBlend = 1
        fadeOutAnim.restart()
        return "ok"
    }

    Timer {
        id: watchdogTimer
        interval: root.watchdogMs
        repeat: false
        onTriggered: {
            console.warn("evo.sys.themes: switch fade watchdog dismiss (endSwitch missed?)")
            root.forceDismiss()
        }
    }

    ParallelAnimation {
        id: fadeInAnim
        NumberAnimation {
            target: root
            property: "overlayOpacity"
            from: 0
            to: 1
            duration: root.fadeInMs
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            id: colorBlendAnim
            target: root
            property: "colorBlend"
            from: 0
            to: 1
            duration: root.fadeInMs
            easing.type: Easing.InOutQuad
        }
    }

    NumberAnimation {
        id: fadeOutAnim
        target: root
        property: "overlayOpacity"
        from: root.overlayOpacity
        to: 0
        duration: root.fadeOutMs
        easing.type: Easing.InOutQuad
        onFinished: {
            if (root.fadeOutId !== root.switchId)
                return
            root.active = false
            root.colorBlend = 0
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
                anchors.fill: parent
                opacity: root.overlayOpacity * root.peakAlpha
                visible: root.active

                Rectangle {
                    anchors.fill: parent
                    color: root.fromColor
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.toColor
                    opacity: root.colorBlend
                }
            }
        }
    }
}
