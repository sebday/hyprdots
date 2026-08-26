import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var module: null

    implicitWidth: parent ? parent.width : Theme.settingsPanelWidth
    implicitHeight: wallpapersColumn.implicitHeight

    ColumnLayout {
        id: wallpapersColumn
        width: parent.width
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            visible: module && (module.sectionFilterVisible("Wallpapers")
                || module.sectionFilterVisible("Personal wallpapers"))
            Layout.fillWidth: true
            notchLegend: true
            legendText: "Personal wallpapers"
            legendIcon: "󰏘"
            legendBackground: Theme.background
            label: ""

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Folder"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    opacity: Theme.opacityMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 6
                        property bool keyboardSelected: false
                        property alias settingsNavInput: personalWallpaperInput
                        color: keyboardSelected ? Theme.foregroundHoverWash : Theme.foregroundWash
                        border.color: Theme.foregroundDivider
                        border.width: 1

                        TextInput {
                            id: personalWallpaperInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.mantle
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            text: module.personalWallpaperDir
                            enabled: module.personalWallpaperReady && !module.settingsBusy
                            onEditingFinished: module.setPersonalWallpaperDir(text)
                        }
                    }

                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34

                        Text {
                            anchors.centerIn: parent
                            text: "󰉖"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXl
                            opacity: personalWallpaperPickMouse.enabled
                                ? (personalWallpaperPickMouse.containsMouse ? 1 : 0.72)
                                : 0.35
                        }

                        MouseArea {
                            id: personalWallpaperPickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: module.personalWallpaperReady && !module.settingsBusy
                            onClicked: module.pickPersonalWallpaperDir()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Images here appear in the wallpaper carousel."
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    opacity: Theme.opacityMuted
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
