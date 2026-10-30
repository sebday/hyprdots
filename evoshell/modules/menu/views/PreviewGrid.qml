import QtQuick
import QtQuick.Layouts
import qs.commons

Item {
    id: root

    property var entries: []
    property int selectedIndex: 0
    property bool showDetail: false
    property color ink: Theme.foreground
    property color paper: Theme.background
    property color accentColor: Theme.accent
    property color surface: Theme.overlaySurface
    property color divider: Theme.foregroundDivider
    signal stepped(int delta)
    readonly property int columnCount: Math.max(1, grid.width > 0
        ? Math.floor(grid.width / Theme.launcherPreviewTileWidth)
        : 1)
    signal activated(var entry)
    signal indexMoved(int index)

    readonly property var selectedEntry: {
        if (selectedIndex < 0 || selectedIndex >= entries.length)
            return null
        return entries[selectedIndex]
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.entries
            currentIndex: root.selectedIndex
            cellWidth: Math.max(Theme.launcherPreviewTileWidth, Math.floor(width / Math.max(1, root.columnCount)))
            cellHeight: Theme.launcherPreviewTileHeight + Theme.fontSizeS + Theme.spacingL

            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, GridView.Contain)
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: tile
                    readonly property bool picked: index === root.selectedIndex
                    width: Math.min(Theme.launcherPreviewTileWidth, cell.width - Theme.spacingS)
                    height: Theme.launcherPreviewTileHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
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
                    border.width: tile.picked ? 3 : (cellMouse.containsMouse ? 2 : 1)
                    border.color: tile.picked || cellMouse.containsMouse ? root.accentColor : root.divider
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
                    color: tile.picked ? root.accentColor : root.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.bold: Theme.fontBold
                    elide: Text.ElideMiddle
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.indexMoved(index)
                        root.activated(cell.modelData)
                    }
                }
            }
        }

        ColumnLayout {
            visible: root.showDetail
            Layout.preferredWidth: Theme.launcherDetailWidth
            Layout.fillHeight: true
            spacing: Theme.spacingS

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: root.surface
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.selectedEntry && root.selectedEntry.preview
                        ? Util.fileUrl(root.selectedEntry.preview)
                        : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                Rectangle {
                    visible: root.entries.length > 1
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: Theme.cornerRadius
                    color: Theme.withOpacity(root.paper, 0.78)

                    Text {
                        anchors.centerIn: parent
                        text: "󰅁"
                        color: root.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeL
                        font.bold: Theme.fontBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepped(-1)
                    }
                }

                Rectangle {
                    visible: root.entries.length > 1
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: Theme.cornerRadius
                    color: Theme.withOpacity(root.paper, 0.78)

                    Text {
                        anchors.centerIn: parent
                        text: "󰅂"
                        color: root.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeL
                        font.bold: Theme.fontBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepped(1)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.selectedEntry ? root.selectedEntry.name : ""
                color: root.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
                elide: Text.ElideMiddle
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }
    }
}
