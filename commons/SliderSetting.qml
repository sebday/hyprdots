import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property bool showHeader: true
    property int value: 0
    property int minimum: 0
    property int maximum: 20
    property int step: 1
    property bool enabled: true
    property bool dragging: false
    property bool keyboardSelected: false

    property string valueSuffix: ""

    signal valueEdited(int value)
    signal valueCommitted(int value)

    readonly property int activeValue: dragging ? dragValue : value

    property int dragValue: value

    onValueChanged: {
        if (!dragging)
            dragValue = value
    }

    function valueAt(mouseX, trackWidth) {
        var ratio = Math.max(0, Math.min(1, mouseX / trackWidth))
        var raw = minimum + ratio * (maximum - minimum)
        var stepped = Math.round(raw / step) * step
        return Math.max(minimum, Math.min(maximum, stepped))
    }

    function setDragValue(next) {
        if (next === dragValue)
            return
        dragValue = next
        valueEdited(next)
    }

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    opacity: root.enabled ? 1 : Theme.opacityDisabled

    Rectangle {
        anchors.fill: parent
        visible: root.keyboardSelected
        radius: 4
        color: Theme.foregroundWash
        opacity: 0.85
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spacingS

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

                onPressed: function(mouse) {
                    finishedPress = false
                    dragStartValue = root.activeValue
                    root.dragging = true
                    root.setDragValue(root.valueAt(mouse.x, track.width))
                }

                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return
                    root.setDragValue(root.valueAt(mouse.x, track.width))
                }

                onReleased: function(mouse) {
                    finishedPress = true
                    root.setDragValue(root.valueAt(mouse.x, track.width))
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
}
