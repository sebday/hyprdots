import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../Commons"

Item {
    id: root

    property var barPanel: null
    property bool opened: false
    property var activeMenu: null
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

    function reposition() {
        if (!anchorItem || !barPanel)
            return
        var point = anchorItem.mapToItem(barPanel.contentItem, 0, 0)
        var width = menuBox.width
        var height = menuBox.height
        var x = point.x + (anchorItem.width - width) / 2
        var y = point.y - height - 4
        if (x < 8) x = 8
        if (x + width > barPanel.width - 8)
            x = barPanel.width - width - 8
        if (y < 8)
            y = point.y + anchorItem.height + 4
        menuX = x
        menuY = y
    }

    function open(menu, anchor) {
        if (!menu || !anchor)
            return
        activeMenu = menu
        anchorItem = anchor
        if (menu.menu)
            menu.menu.sendOpened()
        opened = true
        Qt.callLater(reposition)
    }

    function close() {
        if (activeMenu && activeMenu.menu)
            activeMenu.menu.sendClosed()
        opened = false
        activeMenu = null
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
        entry.sendTriggered()
        close()
    }

    PanelWindow {
        visible: root.opened && root.barPanel
        screen: root.barPanel ? root.barPanel.screen : null
        color: "transparent"
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
                        color: rowMouse.containsMouse ? Theme.mantle : "transparent"
                        visible: !modelData.isSeparator

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                visible: modelData.buttonType !== 0
                                text: modelData.checkState === 2 ? "☑" : "☐"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.barFontPixelSize
                                font.bold: Theme.fontBold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.text
                                color: modelData.enabled ? Theme.foreground : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.45)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.barFontPixelSize
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
                                font.pixelSize: Theme.barFontPixelSize
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
