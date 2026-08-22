import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property int currentIndex: 0
    property var tabs: []

    signal tabActivated(int index)

    spacing: Theme.spacingS
    implicitHeight: tabRow.implicitHeight
    implicitWidth: tabRow.implicitWidth

    RowLayout {
        id: tabRow
        spacing: Theme.spacingS

        Repeater {
            model: root.tabs

            delegate: Item {
                id: tabItem
                required property int index
                required property var modelData

                implicitWidth: tabPill.implicitWidth
                implicitHeight: tabPill.implicitHeight

                readonly property bool selected: root.currentIndex === index

                Rectangle {
                    id: tabPill
                    radius: height / 2
                    color: tabItem.selected
                        ? Theme.accent
                        : (tabMouse.containsMouse ? Theme.foregroundHoverWash : Theme.foregroundWash)
                    implicitWidth: tabLabelRow.implicitWidth + 16
                    implicitHeight: tabLabelRow.implicitHeight + 8

                    RowLayout {
                        id: tabLabelRow
                        anchors.centerIn: parent
                        spacing: tabItem.modelData.icon !== "" && tabItem.modelData.label !== "" ? 5 : 0

                        Text {
                            visible: tabItem.modelData.icon !== ""
                            text: tabItem.modelData.icon
                            color: tabItem.selected ? Theme.mantle : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            font.bold: Theme.fontBold
                        }

                        Text {
                            visible: tabItem.modelData.label !== ""
                            text: tabItem.modelData.label
                            color: tabItem.selected ? Theme.mantle : Theme.foreground
                            opacity: tabItem.selected ? 1 : Theme.opacityMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tabActivated(tabItem.index)
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
    }
}
