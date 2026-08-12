import QtQuick
import "."

Item {
    id: root

    property real progress: 0
    property int barWidth: 36
    property int barHeight: 4

    implicitWidth: barWidth
    implicitHeight: barHeight

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
    }

    Rectangle {
        height: parent.height
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        radius: 2
        color: Theme.accent
        opacity: 0.9
    }
}
