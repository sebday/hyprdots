import QtQuick
import Quickshell
import qs.commons
import "."

Row {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var barConfig: ({})
    property var entries: []
    property var widgetRegistry: null
    property int sectionMargin: 0
    property string region: ""

    spacing: 0
    height: Theme.barHeight
    anchors.leftMargin: sectionMargin
    anchors.rightMargin: sectionMargin

    Component.onCompleted: {
        if (bar)
            bar.registerModuleSection(root)
    }
    Component.onDestruction: {
        if (bar)
            bar.unregisterModuleSection(root)
    }

    function widgetComponentFor(entry) {
        if (entry.type === "command" || entry.exec) return commandComp
        if (!widgetRegistry) return null
        return widgetRegistry.componentFor(String(entry.id || ""))
    }

    function entryVisible(entry) {
        if (!entry || entry.enabled === false)
            return false
        return true
    }

    readonly property var visibleEntries: {
        var out = []
        var i
        for (i = 0; i < entries.length; i++) {
            if (entryVisible(entries[i]))
                out.push({ entry: entries[i], layoutIndex: i })
        }
        return out
    }

    Component { id: commandComp; CommandWidget {} }

    Repeater {
        model: root.visibleEntries
        delegate: Item {
            id: slot

            required property var modelData
            required property int index

            readonly property var entry: modelData.entry
            readonly property string region: root.region
            readonly property int layoutIndex: modelData.layoutIndex
            readonly property bool dragSource: root.bar && root.bar.barDragSource === slot
            readonly property Item activeItem: loader.item
            readonly property var hostPanel: root.barPanel

            implicitWidth: loader.item ? loader.item.implicitWidth : 0
            implicitHeight: Theme.barHeight
            width: implicitWidth
            height: Theme.barHeight

            Loader {
                id: loader
                anchors.verticalCenter: parent.verticalCenter
                width: item ? item.implicitWidth : 0
                height: Theme.barHeight
                sourceComponent: root.widgetComponentFor(slot.entry)
                opacity: slot.dragSource ? 0.22 : 1
                onLoaded: {
                    if (!item) return
                    if ("bar" in item) item.bar = root.bar
                    if ("barPanel" in item) item.barPanel = root.barPanel
                    if ("settings" in item) item.settings = slot.entry
                    if ("shell" in item) item.shell = root.shell
                    if (typeof item.restartPolling === "function") item.restartPolling()
                    else if (typeof item.runExec === "function") item.runExec()
                }
            }

            Rectangle {
                visible: root.bar && root.bar.barDragTarget === slot
                width: 2
                height: parent.height
                x: root.bar && root.bar.barDragAfter ? parent.width - width : -width
                color: Theme.accent
                z: 3
            }

            MouseArea {
                id: modulePointer

                property bool dragging: false
                property bool suppressClick: false
                property real pressedX: 0
                property real pressedY: 0
                readonly property bool canReorder: root.bar && root.shell && typeof root.shell.mutateShellConfig === "function"
                readonly property real dragThreshold: Theme.space(4)

                anchors.fill: parent
                z: 2
                acceptedButtons: Qt.LeftButton
                hoverEnabled: false
                preventStealing: true
                propagateComposedEvents: true
                cursorShape: dragging ? Qt.SizeHorCursor : Qt.ArrowCursor

                onPressed: function(mouse) {
                    dragging = false
                    suppressClick = false
                    pressedX = mouse.x
                    pressedY = mouse.y
                    if (root.bar)
                        root.bar.clearBarDrag()
                }

                onPositionChanged: function(mouse) {
                    if (!canReorder || !(mouse.buttons & Qt.LeftButton) || !root.bar)
                        return

                    var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
                    if (distance >= dragThreshold && !dragging) {
                        dragging = true
                        suppressClick = true
                        root.bar.barDragWindow = root.barPanel
                        root.bar.barDragScreen = root.barPanel ? root.barPanel.screen : null
                        root.bar.barDragOffsetX = pressedX
                        root.bar.barDragOffsetY = pressedY
                        root.bar.barDragSource = slot
                        root.bar.captureBarDragGhost(slot)
                        if (slot.activeItem)
                            root.bar.hideTooltip(slot.activeItem)
                    }

                    if (!dragging)
                        return

                    var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
                    var screenPoint = root.bar.barDragScreenPoint(scenePoint)
                    root.bar.barDragScreenX = screenPoint.x
                    root.bar.barDragScreenY = screenPoint.y
                    var drop = root.bar.moduleDropAtScene(scenePoint, slot)
                    root.bar.barDragTarget = drop ? drop.slot : null
                    root.bar.barDragAfter = drop ? drop.after : false
                }

                onReleased: function(mouse) {
                    var wasDragging = dragging
                    var targetSlot = root.bar ? root.bar.barDragTarget : null
                    var afterTarget = root.bar ? root.bar.barDragAfter : false
                    dragging = false
                    if (root.bar)
                        root.bar.clearBarDrag()
                    if (wasDragging && targetSlot && root.bar)
                        root.bar.dropBarModule(slot, targetSlot, afterTarget)
                    mouse.accepted = wasDragging
                }

                onCanceled: {
                    dragging = false
                    suppressClick = false
                    if (root.bar)
                        root.bar.clearBarDrag()
                }

                onClicked: function(mouse) {
                    if (suppressClick) {
                        suppressClick = false
                        mouse.accepted = true
                        return
                    }
                    mouse.accepted = false
                }

                onWheel: function(wheel) {
                    wheel.accepted = false
                }

                Component.onCompleted: {
                    if (root.bar)
                        root.bar.registerModuleSlot(slot)
                }
                Component.onDestruction: {
                    if (root.bar)
                        root.bar.unregisterModuleSlot(slot)
                }
            }
        }
    }
}
