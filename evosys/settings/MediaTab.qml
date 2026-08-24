import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var module: null

    implicitWidth: parent ? parent.width : Theme.settingsPanelWidth
    implicitHeight: mediaColumn.implicitHeight

    ColumnLayout {
        id: mediaColumn
        width: parent.width
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            visible: module && module.sectionFilterVisible("Media")
            Layout.fillWidth: true
            notchLegend: true
            legendText: "Media"
            legendIcon: "󰿯"
            legendBackground: Theme.background
            label: ""

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "TV folder"
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
                        property alias settingsNavInput: mediaTvInput
                        color: keyboardSelected ? Theme.foregroundHoverWash : Theme.foregroundWash
                        border.color: Theme.foregroundDivider
                        border.width: 1

                        TextInput {
                            id: mediaTvInput
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
                            text: module.mediaTvRoot
                            enabled: module.mediaReady && !module.settingsBusy
                            onEditingFinished: {
                                if (!module.suppressMediaPathCommit)
                                    module.setMediaTvRoot(text)
                            }
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
                            opacity: mediaTvPickMouse.enabled
                                ? (mediaTvPickMouse.containsMouse ? 1 : 0.72)
                                : 0.35
                        }

                        MouseArea {
                            id: mediaTvPickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: module.mediaReady && !module.settingsBusy
                            onClicked: module.pickMediaTv()
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Films folder"
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
                        property alias settingsNavInput: mediaFilmsInput
                        color: keyboardSelected ? Theme.foregroundHoverWash : Theme.foregroundWash
                        border.color: Theme.foregroundDivider
                        border.width: 1

                        TextInput {
                            id: mediaFilmsInput
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
                            text: module.mediaFilmsRoot
                            enabled: module.mediaReady && !module.settingsBusy
                            onEditingFinished: {
                                if (!module.suppressMediaPathCommit)
                                    module.setMediaFilmsRoot(text)
                            }
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
                            opacity: mediaFilmsPickMouse.enabled
                                ? (mediaFilmsPickMouse.containsMouse ? 1 : 0.72)
                                : 0.35
                        }

                        MouseArea {
                            id: mediaFilmsPickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: module.mediaReady && !module.settingsBusy
                            onClicked: module.pickMediaFilms()
                        }
                    }
                }
            }
        }
    }
}
