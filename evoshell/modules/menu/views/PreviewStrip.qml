import QtQuick
import qs.commons

Item {
    id: root

    property var entries: []
    property int selectedIndex: 0
    property color ink: Theme.foreground
    property color accentColor: Theme.accent
    property color surface: Theme.overlaySurface
    property color divider: Theme.foregroundDivider
    readonly property int tileWidth: 136
    readonly property int tileHeight: 84
    signal activated(var entry)
    signal indexMoved(int index)

    ListView {
        id: strip
        anchors.fill: parent
        orientation: ListView.Horizontal
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: Theme.spacingS
        model: root.entries
        currentIndex: root.selectedIndex

        readonly property bool canLeft: contentX > 2
        readonly property bool canRight: contentWidth > width + 2 && contentX < contentWidth - width - 2

        function page(direction) {
            var span = Math.max(root.tileWidth + spacing, width - root.tileWidth)
            var limit = Math.max(0, contentWidth - width)
            var next = Math.max(0, Math.min(limit, contentX + direction * span))
            scrollAnim.from = contentX
            scrollAnim.to = next
            scrollAnim.restart()
        }

        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex < count)
                positionViewAtIndex(currentIndex, ListView.Contain)
        }

        NumberAnimation {
            id: scrollAnim
            target: strip
            property: "contentX"
            duration: Theme.duration(160)
            easing.type: Easing.OutCubic
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool picked: index === root.selectedIndex
            width: root.tileWidth
            height: strip.height

            Rectangle {
                id: tile
                width: parent.width
                height: root.tileHeight
                radius: Theme.cornerRadius
                color: root.surface
                clip: true

                Image {
                    id: preview
                    anchors.fill: parent
                    source: cell.modelData && cell.modelData.preview
                        ? Util.fileUrl(cell.modelData.preview)
                        : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !cell.modelData || !cell.modelData.preview || preview.status === Image.Error
                    text: cell.modelData && cell.modelData.icon ? cell.modelData.icon : "󰸌"
                    color: root.accentColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize6xl
                    font.bold: Theme.fontBold
                }
            }

            Rectangle {
                anchors.fill: tile
                color: "transparent"
                radius: tile.radius
                border.width: cell.picked ? 3 : (cellMouse.containsMouse ? 2 : 1)
                border.color: cell.picked || cellMouse.containsMouse ? root.accentColor : root.divider
            }

            Rectangle {
                visible: cell.modelData && cell.modelData.current === true
                anchors.right: tile.right
                anchors.top: tile.top
                anchors.margins: 6
                width: 8
                height: 8
                radius: 4
                color: root.accentColor
            }

            Text {
                anchors.top: tile.bottom
                anchors.topMargin: 4
                anchors.left: tile.left
                anchors.right: tile.right
                horizontalAlignment: Text.AlignHCenter
                text: cell.modelData ? cell.modelData.name : ""
                color: cell.picked ? root.accentColor : root.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.bold: Theme.fontBold
                elide: Text.ElideMiddle
            }

            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.indexMoved(index)
                    root.activated(cell.modelData)
                }
            }
        }
    }

    Rectangle {
        visible: strip.canLeft
        z: 2
        x: 4
        y: (root.tileHeight - height) / 2
        width: 28
        height: 28
        radius: Theme.cornerRadius
        color: Theme.withOpacity(Theme.background, 0.82)

        Text {
            anchors.centerIn: parent
            text: "󰅁"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.bold: Theme.fontBold
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: strip.page(-1)
        }
    }

    Rectangle {
        visible: strip.canRight
        z: 2
        x: parent.width - width - 4
        y: (root.tileHeight - height) / 2
        width: 28
        height: 28
        radius: Theme.cornerRadius
        color: Theme.withOpacity(Theme.background, 0.82)

        Text {
            anchors.centerIn: parent
            text: "󰅂"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.bold: Theme.fontBold
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: strip.page(1)
        }
    }
}
