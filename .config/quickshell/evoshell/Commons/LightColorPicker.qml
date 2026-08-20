import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property int red: 255
    property int green: 180
    property int blue: 80
    property bool enabled: true
    property bool dragging: false
    property bool locked: false

    signal colorEdited(int red, int green, int blue)
    signal colorCommitted(int red, int green, int blue)

    readonly property color currentColor: Qt.rgba(red / 255, green / 255, blue / 255, 1)
    readonly property real thumbHue: pickedHue
    readonly property bool interacting: dragging || locked

    property real pickedHue: 0.12

    Layout.fillWidth: true
    implicitWidth: 188
    implicitHeight: hueField.implicitHeight
    spacing: Theme.spacingM
    opacity: enabled ? 1 : Theme.opacityDisabled

    function setRgb(r, g, b) {
        root.red = Math.max(0, Math.min(255, Math.round(r)))
        root.green = Math.max(0, Math.min(255, Math.round(g)))
        root.blue = Math.max(0, Math.min(255, Math.round(b)))
    }

    function setHue(h) {
        var hue = Math.max(0, Math.min(1, h))
        pickedHue = hue
        var c = Qt.hsv(hue, 0.9, 0.95)
        setRgb(c.r * 255, c.g * 255, c.b * 255)
    }

    function syncFromHs(hue360, sat100) {
        if (interacting)
            return
        var h = parseFloat(hue360)
        if (isNaN(h))
            return
        var s = parseFloat(sat100)
        if (isNaN(s))
            s = 100
        pickedHue = Math.max(0, Math.min(1, h / 360))
        var sat = Math.max(0, Math.min(1, s / 100))
        var c = Qt.hsv(pickedHue, Math.max(0.9, sat), 0.95)
        setRgb(c.r * 255, c.g * 255, c.b * 255)
    }

    function lockAtCurrent() {
        locked = true
    }

    function unlock() {
        locked = false
    }

    function hueFromPoint(x) {
        var w = hueField.width
        if (w <= 0)
            return false
        setHue(x / w)
        return true
    }

    Item {
        id: hueField
        Layout.fillWidth: true
        implicitHeight: 28

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 14
            radius: Theme.radiusS
            clip: true

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: "#ff0000" }
                GradientStop { position: 0.17; color: "#ffff00" }
                GradientStop { position: 0.33; color: "#00ff00" }
                GradientStop { position: 0.50; color: "#00ffff" }
                GradientStop { position: 0.67; color: "#0000ff" }
                GradientStop { position: 0.83; color: "#ff00ff" }
                GradientStop { position: 1.00; color: "#ff0000" }
            }
        }

        Rectangle {
            width: 10
            height: 20
            radius: Theme.radiusS
            x: Math.max(0, Math.min(hueField.width - width, root.pickedHue * hueField.width - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: Theme.foreground
            border.width: 2
            z: 2
        }

        MouseArea {
            id: hueMouse
            anchors.fill: parent
            enabled: root.enabled
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            z: 3

            property int startRed: root.red
            property int startGreen: root.green
            property int startBlue: root.blue
            property real startHue: root.pickedHue
            property bool finishedPress: false

            onPressed: function(mouse) {
                finishedPress = false
                root.unlock()
                startRed = root.red
                startGreen = root.green
                startBlue = root.blue
                startHue = root.pickedHue
                root.dragging = true
                if (!root.hueFromPoint(mouse.x))
                    return
                root.colorEdited(root.red, root.green, root.blue)
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return
                if (!root.hueFromPoint(mouse.x))
                    return
                root.colorEdited(root.red, root.green, root.blue)
            }

            onReleased: function(mouse) {
                finishedPress = true
                root.lockAtCurrent()
                root.colorCommitted(root.red, root.green, root.blue)
                root.dragging = false
            }

            onCanceled: {
                root.dragging = false
                if (finishedPress)
                    return
                root.unlock()
                root.pickedHue = startHue
                root.setRgb(startRed, startGreen, startBlue)
            }
        }
    }
}
