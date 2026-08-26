import QtQuick
import "."

Item {
    id: root

    property real progress: 0
    property int barWidth: 36
    property int barHeight: 4
    property color color: Theme.accent

    implicitWidth: barWidth
    implicitHeight: barHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusS
        color: Theme.foregroundRaised
    }

    Rectangle {
        height: parent.height
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        radius: Theme.radiusS
        color: root.color
        opacity: Theme.opacityEmphasis
    }
}
