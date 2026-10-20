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
    currentIndex: selectedIndex
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    spacing: 2

    onSelectedIndexChanged: {
        if (selectedIndex >= 0 && selectedIndex < count)
            positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    section.property: "section"
    section.criteria: ViewSection.FullString
    section.delegate: Item {
        required property string section
        width: list.width
        height: section === "" ? 0 : Theme.fontSizeXs + Theme.spacingM

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            visible: section !== ""
            text: section
            color: Theme.foreground
            opacity: Theme.opacityMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            font.bold: Theme.fontBold
        }
    }

    delegate: Rectangle {
        id: row
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
                        if (!row.modelData)
                            return ""
                        return String(row.modelData.iconSource || "")
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: row.modelData && String(row.modelData.iconSource || "") === ""
                    text: row.modelData && row.modelData.icon ? row.modelData.icon : "󰍉"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.launcherIconSize
                    font.bold: Theme.fontBold
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: row.modelData ? row.modelData.name : ""
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
                    if (!row.modelData)
                        return ""
                    if (row.modelData.accessory)
                        return String(row.modelData.accessory)
                    if (row.modelData.detail)
                        return String(row.modelData.detail)
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
                list.activated(row.modelData)
            }
        }
    }
}
