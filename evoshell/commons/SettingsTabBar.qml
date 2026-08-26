import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int currentIndex: 0
    property var tabs: []
    property bool vertical: false

    signal tabActivated(int index)

    implicitHeight: vertical ? tabColumn.implicitHeight : tabRow.implicitHeight
    implicitWidth: vertical ? Theme.settingsSideTabWidth : tabRow.implicitWidth

    RowLayout {
        id: tabRow
        visible: !root.vertical
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

        Item { Layout.fillWidth: true }
    }

    ColumnLayout {
        id: tabColumn
        visible: root.vertical
        width: parent.width
        spacing: Theme.spacing2

        Repeater {
            model: root.tabs

            delegate: Item {
                id: sideTabItem
                required property int index
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: sideTabRail.implicitHeight

                readonly property bool selected: root.currentIndex === index

                Rectangle {
                    id: sideTabRail
                    width: parent.width
                    implicitHeight: sideTabRow.implicitHeight + 10
                    radius: Theme.radiusM
                    color: sideTabItem.selected
                        ? Theme.foregroundHoverWash
                        : (sideTabMouse.containsMouse ? Theme.foregroundWash : "transparent")

                    Rectangle {
                        width: 3
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        radius: 2
                        color: Theme.accent
                        visible: sideTabItem.selected
                    }

                    RowLayout {
                        id: sideTabRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: Theme.spacingS

                        Item {
                            Layout.preferredWidth: Theme.settingsSideTabIconWidth
                            Layout.preferredHeight: sideTabIcon.implicitHeight
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: sideTabIcon
                                anchors.centerIn: parent
                                visible: sideTabItem.modelData.icon !== ""
                                text: sideTabItem.modelData.icon
                                color: Theme.foreground
                                opacity: sideTabItem.selected ? 1 : Theme.opacityMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeL
                                font.bold: Theme.fontBold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: sideTabItem.modelData.label !== ""
                            text: sideTabItem.modelData.label
                            color: Theme.foreground
                            opacity: sideTabItem.selected ? 1 : Theme.opacitySecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            font.bold: sideTabItem.selected ? Theme.fontBold : false
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                MouseArea {
                    id: sideTabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tabActivated(sideTabItem.index)
                }
            }
        }
    }
}
