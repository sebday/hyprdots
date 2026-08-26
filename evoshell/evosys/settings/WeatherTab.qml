import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var module: null
    property alias weatherLocationRow: weatherLocationRow

    implicitWidth: parent ? parent.width : Theme.settingsPanelWidth
    implicitHeight: weatherColumn.implicitHeight

    ColumnLayout {
        id: weatherColumn
        width: parent.width
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            visible: module && module.sectionFilterVisible("Location")
            Layout.fillWidth: true
            notchLegend: true
            legendText: "Location"
            legendIcon: "󰍎"
            legendBackground: Theme.background
            label: ""

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Weather location"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    opacity: Theme.opacityMuted
                }

                RowLayout {
                    id: weatherLocationRow
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 6
                        property bool keyboardSelected: false
                        property alias settingsNavInput: weatherLocationInput
                        color: keyboardSelected ? Theme.foregroundHoverWash : Theme.foregroundWash
                        border.color: Theme.foregroundDivider
                        border.width: 1

                        TextInput {
                            id: weatherLocationInput
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
                            text: module.weatherLocation
                            enabled: module.weatherReady && !module.settingsBusy
                            onEditingFinished: module.setWeatherLocation(text)
                        }
                    }

                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: module.weatherLocationPickerOpen || weatherLocationPickMouse.containsMouse
                                ? Theme.foregroundHoverWash
                                : Theme.foregroundWash
                            border.color: module.weatherLocationPickerOpen
                                ? Theme.accent
                                : Theme.foregroundDivider
                            border.width: 1
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰍎"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXl
                            opacity: weatherLocationPickMouse.enabled
                                ? (weatherLocationPickMouse.containsMouse || module.weatherLocationPickerOpen ? 1 : 0.72)
                                : 0.35
                        }

                        MouseArea {
                            id: weatherLocationPickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            enabled: module.weatherReady && !module.settingsBusy
                            onClicked: {
                                if (module.weatherLocationPickerOpen)
                                    module.closeWeatherLocationPicker()
                                else
                                    module.openWeatherLocationPicker()
                            }
                        }
                    }
                }
            }
        }
    }
}
