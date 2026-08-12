import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string label: ""
    property int value: 0
    property int minimum: 0
    property int maximum: 20
    property int step: 1
    property bool enabled: true

    property string valueSuffix: ""

    signal valueEdited(int value)
    signal valueCommitted(int value)

    spacing: 6
    opacity: root.enabled ? 1 : 0.45

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: root.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            font.bold: Theme.fontBold
            elide: Text.ElideRight
        }

        Text {
            text: root.value + root.valueSuffix
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPixelSize
            font.bold: Theme.fontBold
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: 28
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 20

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.maximum === root.minimum ? 0 : ((root.value - root.minimum) / (root.maximum - root.minimum)) * track.width
            height: 4
            radius: 2
            color: Theme.accent
        }

        Rectangle {
            id: handle
            anchors.verticalCenter: parent.verticalCenter
            x: root.maximum === root.minimum ? 0 : ((root.value - root.minimum) / (root.maximum - root.minimum)) * (track.width - width)
            width: 12
            height: 12
            radius: 6
            color: Theme.accent
            border.color: Theme.panelBackground
            border.width: 2
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled
            cursorShape: Qt.SizeHorCursor

            property int dragStartValue: root.value

            function valueAt(mouseX) {
                var ratio = Math.max(0, Math.min(1, mouseX / track.width))
                var raw = root.minimum + ratio * (root.maximum - root.minimum)
                var stepped = Math.round(raw / root.step) * root.step
                return Math.max(root.minimum, Math.min(root.maximum, stepped))
            }

            onPressed: function(mouse) {
                dragStartValue = root.value
                root.valueEdited(valueAt(mouse.x))
            }

            onPositionChanged: function(mouse) {
                if (pressed)
                    root.valueEdited(valueAt(mouse.x))
            }

            onReleased: function(mouse) {
                root.valueCommitted(valueAt(mouse.x))
            }

            onCanceled: {
                root.valueEdited(dragStartValue)
            }
        }
    }
}
