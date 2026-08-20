import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Commons"

Item {
    id: root

    property var barPanel: null
    property var bar: null
    property bool opened: false
    property var activeMenu: null
    property var rootMenu: null
    property Item anchorItem: null
    property int menuX: 0
    property int menuY: 0

    readonly property var menuEntries: {
        if (!menuOpener.children || !menuOpener.children.values)
            return []
        return menuOpener.children.values
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.activeMenu
    }

    readonly property bool barOnBottom: {
        if (bar && bar.barConfig && bar.barConfig.position)
            return String(bar.barConfig.position) !== "top"
        return true
    }

    function reposition() {
        if (!anchorItem || !barPanel || !menuOverlay.screen)
            return
        var point = anchorItem.mapToItem(barPanel.contentItem, anchorItem.width / 2, 0)
        var width = menuBox.width
        var height = menuBox.height
        var screenW = menuOverlay.screen.width
        var screenH = menuOverlay.screen.height
        var barH = barPanel.height
        var x = Math.round(point.x - width / 2)
        var y
        if (barOnBottom) {
            var barTopY = screenH - barH + point.y
            y = Math.round(barTopY - height - 6)
            if (y < 8)
                y = Math.round(barTopY + anchorItem.height + 6)
        } else {
            y = Math.round(point.y + anchorItem.height + 6)
            if (y + height > screenH - 8)
                y = Math.round(Math.max(8, point.y - height - 6))
        }
        if (x < 8)
            x = 8
        if (x + width > screenW - 8)
            x = Math.max(8, screenW - width - 8)
        if (y + height > screenH - 8)
            y = Math.max(8, screenH - height - 8)
        menuX = x
        menuY = y
    }

    function open(menu, anchor) {
        if (!menu || !anchor)
            return
        rootMenu = menu
        activeMenu = menu
        anchorItem = anchor
        if (menu.menu)
            menu.menu.sendOpened()
        opened = true
        Qt.callLater(reposition)
    }

    function close() {
        var handle = rootMenu || activeMenu
        if (handle && handle.menu)
            handle.menu.sendClosed()
        opened = false
        activeMenu = null
        rootMenu = null
        anchorItem = null
    }

    function activateEntry(entry) {
        if (!entry || entry.isSeparator || !entry.enabled)
            return
        if (entry.hasChildren) {
            activeMenu = entry
            Qt.callLater(reposition)
            return
        }
        entry.triggered()
        close()
    }

    Connections {
        target: menuOpener
        function onChildrenChanged() {
            if (root.opened)
                Qt.callLater(root.reposition)
        }
    }

    PanelWindow {
        id: menuOverlay
        visible: root.opened && root.barPanel
        screen: root.barPanel ? root.barPanel.screen : null
        color: "transparent"
        implicitWidth: screen ? screen.width : 1920
        implicitHeight: screen ? screen.height : 1080
        WlrLayershell.namespace: "evo-bar-tray-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: menuBox
            x: root.menuX
            y: root.menuY
            width: Math.max(180, menuList.contentWidth + 24)
            height: menuList.contentHeight
            color: Theme.background
            border.color: Theme.accent
            border.width: 1
            radius: Theme.panelCornerRadius

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) { mouse.accepted = true }
            }

            onWidthChanged: Qt.callLater(root.reposition)
            onHeightChanged: Qt.callLater(root.reposition)

            ListView {
                id: menuList
                width: parent.width
                height: contentHeight
                clip: true
                interactive: false
                model: root.menuEntries

                delegate: Item {
                    required property var modelData
                    width: menuList.width
                    height: modelData.isSeparator ? 9 : 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                        visible: modelData.isSeparator
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: rowMouse.containsMouse ? Theme.foregroundWash : "transparent"
                        visible: !modelData.isSeparator

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: Theme.spacingM

                            Text {
                                visible: modelData.buttonType !== 0
                                text: modelData.checkState === 2 ? "☑" : "☐"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeM
                                font.bold: Theme.fontBold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.text
                                color: modelData.enabled ? Theme.foreground : Theme.withOpacity(Theme.foreground, Theme.opacityDisabled)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeM
                                font.bold: Theme.fontBold
                                elide: Text.ElideRight
                                width: parent.width - (modelData.buttonType !== 0 ? 20 : 0) - (modelData.hasChildren ? 16 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                visible: modelData.hasChildren
                                text: "›"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeM
                                font.bold: Theme.fontBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !modelData.isSeparator
                            onClicked: root.activateEntry(modelData)
                        }
                    }
                }
            }
        }
    }
}
