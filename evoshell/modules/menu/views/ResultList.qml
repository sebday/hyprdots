import QtQuick
import QtQuick.Layouts
import qs.commons

ListView {
    id: list

    property var entries: []
    property int selectedIndex: 0
    signal activated(var entry)
    signal indexMoved(int index)

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

    delegate: Rectangle {
        id: card
        required property var modelData
        required property int index
        width: list.width
        height: Theme.launcherRowHeight
        radius: Theme.cornerRadius
        color: index === list.selectedIndex || rowMouse.containsMouse
            ? Theme.panelMantle
            : "transparent"

        RowLayout {
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
            anchors.fill: parent
            hoverEnabled: true
            onEntered: list.indexMoved(index)
            onClicked: {
                list.indexMoved(index)
                list.activated(card.modelData)
            }
        }
    }
}
