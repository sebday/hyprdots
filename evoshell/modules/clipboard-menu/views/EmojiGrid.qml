import QtQuick
import qs.commons

GridView {
    id: grid

    property int selectedIndex: 0
    readonly property int columnCount: Math.max(1, width > 0
        ? Math.floor(width / Theme.launcherEmojiCell)
        : 1)
    signal activated(var entry)
    signal indexMoved(int index)

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: selectedIndex
    cellWidth: Math.max(Theme.launcherEmojiCell, Math.floor(width / Math.max(1, columnCount)))
    cellHeight: Theme.launcherEmojiCell

    onCurrentIndexChanged: {
        if (currentIndex >= 0)
            positionViewAtIndex(currentIndex, GridView.Contain)
    }

    delegate: Rectangle {
        id: cell
        required property var modelData
        required property int index
        width: grid.cellWidth - 4
        height: grid.cellHeight - 4
        radius: Theme.cornerRadius
        color: index === grid.selectedIndex || cellMouse.containsMouse
            ? Theme.panelMantle
            : "transparent"
        border.width: index === grid.selectedIndex ? 1 : 0
        border.color: Theme.accent

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -6
            text: cell.modelData ? cell.modelData.emoji : ""
            color: Theme.foreground
            font.family: "Noto Color Emoji"
            font.pixelSize: Theme.fontSize6xl
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            horizontalAlignment: Text.AlignHCenter
            text: cell.modelData ? cell.modelData.name : ""
            color: Theme.foreground
            opacity: Theme.opacityMuted
            font.family: Theme.fontFamily
            font.pixelSize: 9
            elide: Text.ElideRight
        }

        MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            onEntered: grid.indexMoved(index)
            onClicked: {
                grid.indexMoved(index)
                grid.activated(cell.modelData)
            }
        }
    }
}
