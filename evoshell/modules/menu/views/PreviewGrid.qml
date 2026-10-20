import QtQuick
import QtQuick.Layouts
import qs.commons

Item {
    id: root

    property var entries: []
    property int selectedIndex: 0
    property bool showDetail: false
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
                    width: Math.min(Theme.launcherPreviewTileWidth, cell.width - Theme.spacingS)
                    height: Theme.launcherPreviewTileHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    radius: Theme.cornerRadius
                    color: Theme.overlaySurface
                    border.width: index === root.selectedIndex || cellMouse.containsMouse ? 2 : 1
                    border.color: index === root.selectedIndex
                        ? Theme.accent
                        : Theme.foregroundDivider
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
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize6xl
                        font.bold: Theme.fontBold
                    }

                    Rectangle {
                        visible: cell.modelData && cell.modelData.current === true
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.accent
                    }
                }

                Text {
                    anchors.top: tile.bottom
                    anchors.topMargin: 4
                    anchors.left: tile.left
                    anchors.right: tile.right
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.modelData ? cell.modelData.name : ""
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.bold: Theme.fontBold
                    elide: Text.ElideMiddle
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.indexMoved(index)
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
                color: Theme.overlaySurface
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
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.selectedEntry ? root.selectedEntry.name : ""
                color: Theme.foreground
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
