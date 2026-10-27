import QtQuick
import QtQuick.Layouts
import qs.commons

ListView {
    id: list

    property var entries: []
    property int selectedIndex: 0
    // Pinned app rows sit at the top and can be dragged among themselves.
    property bool reorderable: false
    signal activated(var entry)
    signal indexMoved(int index)
    signal reorderRequested(int from, int target, bool after)

    readonly property real dragThreshold: Theme.space(4)
    readonly property int pinnedCount: {
        var n = 0
        while (n < entries.length && entries[n] && entries[n].kind === "app" && entries[n].pinned === true)
            n++
        return n
    }
    property int dragIndex: -1
    property int dropIndex: -1
    property bool dropAfter: false
    property real dragY: 0
    property real dragOffsetY: 0

    function clearDrag() {
        dragIndex = -1
        dropIndex = -1
        dropAfter = false
    }

    // Nearest pinned row to a y in content coordinates.
    function dropAt(contentYPos) {
        if (pinnedCount === 0)
            return null
        var stride = Theme.launcherRowHeight + spacing
        var row = Math.floor(contentYPos / stride)
        row = Math.max(0, Math.min(pinnedCount - 1, row))
        var within = contentYPos - row * stride
        return { index: row, after: within > Theme.launcherRowHeight / 2 }
    }

    model: entries
    reuseItems: false
    currentIndex: selectedIndex
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    spacing: 2

    onSelectedIndexChanged: {
        if (selectedIndex >= 0 && selectedIndex < count)
            positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    onReorderableChanged: if (!reorderable) clearDrag()

    Item {
        id: dragGhost
        z: 10
        visible: list.dragIndex >= 0 && list.dragIndex < list.entries.length
        x: 0
        y: Math.round(list.dragY - list.dragOffsetY)
        width: list.width
        height: Theme.launcherRowHeight
        opacity: 0.9

        readonly property var dragged: visible ? list.entries[list.dragIndex] : null

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Theme.panelMantle
            border.width: 1
            border.color: Theme.accent
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 10

            Image {
                Layout.preferredWidth: Theme.launcherIconSize
                Layout.preferredHeight: Theme.launcherIconSize
                Layout.alignment: Qt.AlignVCenter
                source: dragGhost.dragged ? Util.normalizeIconSource(String(dragGhost.dragged.iconSource || "")) : ""
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Theme.launcherIconSize * 2, Theme.launcherIconSize * 2)
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: dragGhost.dragged ? dragGhost.dragged.name : ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }
        }
    }

    delegate: Rectangle {
        id: card
        required property var modelData
        required property int index
        readonly property bool draggable: list.reorderable && index < list.pinnedCount
        width: list.width
        height: Theme.launcherRowHeight
        radius: Theme.cornerRadius
        color: list.dragIndex < 0 && (index === list.selectedIndex || rowMouse.containsMouse)
            ? Theme.panelMantle
            : "transparent"

        Rectangle {
            visible: list.dragIndex >= 0 && list.dropIndex === card.index
            width: parent.width
            height: 2
            y: list.dropAfter
                ? parent.height + list.spacing / 2 - height / 2
                : -list.spacing / 2 - height / 2
            color: Theme.accent
            z: 3
        }

        RowLayout {
            opacity: list.dragIndex === card.index ? 0.22 : 1
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 10

            Item {
                Layout.preferredWidth: Theme.launcherIconSize
                Layout.preferredHeight: Theme.launcherIconSize
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.fill: parent
                    visible: iconSource !== ""
                    source: Util.normalizeIconSource(iconSource)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(Theme.launcherIconSize * 2, Theme.launcherIconSize * 2)

                    readonly property string iconSource: {
                        if (!card.modelData)
                            return ""
                        return String(card.modelData.iconSource || "")
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: card.modelData && String(card.modelData.iconSource || "") === ""
                    text: card.modelData && card.modelData.icon ? card.modelData.icon : "󰍉"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.launcherIconSize
                    font.bold: Theme.fontBold
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: card.modelData ? card.modelData.name : ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: card.modelData && card.modelData.pinned === true
                text: "󰐃"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: accessory !== ""
                text: accessory
                color: Theme.foreground
                opacity: Theme.opacitySecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.bold: Theme.fontBold
                elide: Text.ElideLeft

                readonly property string accessory: {
                    if (!card.modelData)
                        return ""
                    if (card.modelData.accessory)
                        return String(card.modelData.accessory)
                    if (card.modelData.detail)
                        return String(card.modelData.detail)
                    return ""
                }
            }
        }

        MouseArea {
            id: rowMouse

            property bool dragging: false
            property bool suppressClick: false
            property real pressedX: 0
            property real pressedY: 0

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: card.draggable
            cursorShape: dragging ? Qt.SizeVerCursor : Qt.ArrowCursor
            onEntered: if (list.dragIndex < 0) list.indexMoved(index)

            onPressed: function(mouse) {
                dragging = false
                suppressClick = false
                pressedX = mouse.x
                pressedY = mouse.y
                list.clearDrag()
            }

            onPositionChanged: function(mouse) {
                if (!card.draggable || list.pinnedCount < 2 || !(mouse.buttons & Qt.LeftButton))
                    return
                var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
                if (distance >= list.dragThreshold && !dragging) {
                    dragging = true
                    suppressClick = true
                    list.dragOffsetY = pressedY
                    list.dragIndex = index
                }
                if (!dragging)
                    return
                var point = card.mapToItem(list.contentItem, mouse.x, mouse.y)
                list.dragY = point.y
                var drop = list.dropAt(point.y)
                list.dropIndex = drop ? drop.index : -1
                list.dropAfter = drop ? drop.after : false
            }

            onReleased: {
                var wasDragging = dragging
                var from = list.dragIndex
                var target = list.dropIndex
                var after = list.dropAfter
                dragging = false
                list.clearDrag()
                if (wasDragging && from >= 0 && target >= 0)
                    list.reorderRequested(from, target, after)
            }

            onCanceled: {
                dragging = false
                suppressClick = false
                list.clearDrag()
            }

            onClicked: {
                if (suppressClick) {
                    suppressClick = false
                    return
                }
                list.indexMoved(index)
                list.activated(card.modelData)
            }
        }
    }
}
