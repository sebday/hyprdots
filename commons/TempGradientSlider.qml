import QtQuick

Item {
    id: root

    property int value: 20
    property int minimum: 12
    property int maximum: 25
    property int step: 1
    property bool enabled: true
    property bool interactive: true
    property bool showTargetMarker: false

    signal valueEdited(int value)
    signal valueCommitted(int value)
    signal dragStarted()
    signal dragEnded()

    readonly property real span: Math.max(1, maximum - minimum)
    property bool dragging: false
    property int dragValue: value
    readonly property int activeValue: dragging ? dragValue : value
    readonly property real fraction: Math.max(0, Math.min(1, (activeValue - minimum) / span))
    readonly property color coldColor: Qt.color("#6ec8ff")
    readonly property color warmColor: Theme.urgent
    readonly property color handleColor: Theme.mixColors(coldColor, warmColor, fraction)

    implicitHeight: sliderHost.height
    implicitWidth: 200
    opacity: enabled ? 1 : Theme.opacityDisabled
    readonly property bool markerVisible: root.interactive || root.showTargetMarker
    readonly property int markerSize: root.interactive ? 22 : 12

    onValueChanged: {
        if (!dragging)
            dragValue = value
    }

    function clampValue(raw) {
        var n = Math.round(raw / step) * step
        return Math.max(minimum, Math.min(maximum, n))
    }

    function valueAt(mouseX, trackWidth) {
        var ratio = Math.max(0, Math.min(1, mouseX / trackWidth))
        return clampValue(minimum + ratio * span)
    }

    function setDragValue(next) {
        if (next === dragValue)
            return
        dragValue = next
        root.valueEdited(next)
    }

    Item {
        id: sliderHost
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 18
            radius: height / 2
            clip: true

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.coldColor }
                GradientStop { position: 1.0; color: root.warmColor }
            }

            opacity: root.markerVisible ? 1 : 0.45
        }

        Text {
            anchors.left: track.left
            anchors.leftMargin: 7
            anchors.verticalCenter: track.verticalCenter
            text: String(root.minimum) + "°"
            color: root.coldColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            font.bold: Theme.fontBold
            z: 1
        }

        Text {
            anchors.right: track.right
            anchors.rightMargin: 7
            anchors.verticalCenter: track.verticalCenter
            text: String(root.maximum) + "°"
            color: root.warmColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            font.bold: Theme.fontBold
            z: 1
        }

        Rectangle {
            id: handle
            anchors.verticalCenter: parent.verticalCenter
            width: root.markerSize
            height: root.markerSize
            radius: width / 2
            x: root.maximum === root.minimum
                ? 0
                : root.fraction * (track.width - width)
            color: root.handleColor
            border.color: Theme.panelBackground
            border.width: root.interactive ? 2 : 1
            visible: root.markerVisible
            z: 2
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled && root.interactive
            cursorShape: Qt.SizeHorCursor
            z: 3

            property int dragStartValue: root.activeValue

            onPressed: function(mouse) {
                dragStartValue = root.activeValue
                root.dragging = true
                root.dragStarted()
                root.setDragValue(root.valueAt(mouse.x, track.width))
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return
                root.setDragValue(root.valueAt(mouse.x, track.width))
            }

            onReleased: function(mouse) {
                root.setDragValue(root.valueAt(mouse.x, track.width))
                root.dragging = false
                root.valueCommitted(root.dragValue)
                root.dragEnded()
            }

            onCanceled: {
                root.dragging = false
                root.setDragValue(dragStartValue)
                root.dragEnded()
            }
        }
    }
}
