import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string label: ""
    property bool showHeader: true
    property int value: 0
    property int minimum: 0
    property int maximum: 20
    property int step: 1
    property bool enabled: true
    property bool dragging: false

    property string valueSuffix: ""

    signal valueEdited(int value)
    signal valueCommitted(int value)

    readonly property int activeValue: dragging ? dragValue : value

    property int dragValue: value

    onValueChanged: {
        if (!dragging)
            dragValue = value
    }

    spacing: Theme.spacingS
    opacity: root.enabled ? 1 : Theme.opacityDisabled

    RowLayout {
        visible: root.showHeader
        Layout.fillWidth: true
        spacing: Theme.spacingM

        Text {
            Layout.fillWidth: true
            text: root.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
            elide: Text.ElideRight
        }

        Text {
            text: root.activeValue + root.valueSuffix
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
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
            radius: Theme.radiusS
            color: Theme.foregroundTrack
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.maximum === root.minimum ? 0 : ((root.activeValue - root.minimum) / (root.maximum - root.minimum)) * track.width
            height: 4
            radius: Theme.radiusS
            color: Theme.accent
        }

        Rectangle {
            id: handle
            anchors.verticalCenter: parent.verticalCenter
            x: root.maximum === root.minimum ? 0 : ((root.activeValue - root.minimum) / (root.maximum - root.minimum)) * (track.width - width)
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
            preventStealing: true
            z: 1

            property int dragStartValue: root.activeValue
            property bool finishedPress: false

            function valueAt(mouseX) {
                var ratio = Math.max(0, Math.min(1, mouseX / track.width))
                var raw = root.minimum + ratio * (root.maximum - root.minimum)
                var stepped = Math.round(raw / root.step) * root.step
                return Math.max(root.minimum, Math.min(root.maximum, stepped))
            }

            function setDragValue(next) {
                if (next === dragValue)
                    return
                dragValue = next
                root.valueEdited(next)
            }

            onPressed: function(mouse) {
                finishedPress = false
                dragStartValue = root.activeValue
                root.dragging = true
                root.setDragValue(valueAt(mouse.x))
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return
                root.setDragValue(valueAt(mouse.x))
            }

            onReleased: function(mouse) {
                finishedPress = true
                root.setDragValue(valueAt(mouse.x))
                root.dragging = false
                root.valueCommitted(root.dragValue)
            }

            onCanceled: {
                root.dragging = false
                if (finishedPress)
                    return
                root.setDragValue(dragStartValue)
            }
        }
    }
}
