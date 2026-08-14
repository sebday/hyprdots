import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../../Commons"

Item {
    id: root
    property var bar: null
    property var barPanel: null
    property var settings: ({})

    readonly property real dpr: barPanel ? barPanel.devicePixelRatio : 1.0
    readonly property int trayIconSize: 18
    readonly property int trayIconSource: Math.max(trayIconSize, Math.round(trayIconSize * dpr))
    readonly property int trayCellWidth: trayIconSize + 4

    implicitWidth: trayRow.width + Theme.barSectionGap
    implicitHeight: Theme.barHeight

    TrayContextMenu {
        id: trayContextMenu
        barPanel: root.barPanel
    }

    Row {
        id: trayRow
        anchors.left: parent.left
        anchors.leftMargin: Theme.barSectionGap
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        height: Theme.barHeight

        Repeater {
            model: SystemTray.items

            Item {
                id: trayCell
                required property var modelData
                width: root.trayCellWidth
                height: Theme.barHeight

                Image {
                    anchors.centerIn: parent
                    width: root.trayIconSize
                    height: root.trayIconSize
                    source: modelData ? modelData.icon : ""
                    sourceSize.width: root.trayIconSource
                    sourceSize.height: root.trayIconSource
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    cache: false
                    asynchronous: true
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: function(mouse) {
                        if (!modelData) return
                        if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                            return
                        }
                        if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                            trayContextMenu.open(modelData.menu, trayCell)
                            return
                        }
                        if (modelData.onlyMenu && modelData.hasMenu) {
                            trayContextMenu.open(modelData.menu, trayCell)
                            return
                        }
                        modelData.activate()
                    }
                }
            }
        }
    }
}
