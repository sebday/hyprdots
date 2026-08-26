import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var module: null

    implicitWidth: parent ? parent.width : Theme.settingsPanelWidth
    implicitHeight: haColumn.implicitHeight

    ColumnLayout {
        id: haColumn
        width: parent.width
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            visible: module && module.sectionFilterVisible("Areas")
            Layout.fillWidth: true
            notchLegend: true
            legendText: "Areas"
            legendIcon: "󰠵"
            legendBackground: Theme.background
            label: ""

            Text {
                Layout.fillWidth: true
                text: module.haDiscoveryError !== ""
                    ? module.haDiscoveryError
                    : "Choose light areas from your Home Assistant instance."
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                opacity: Theme.opacityMuted
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: module.haAreaOptions.length

                ToggleRow {
                    Layout.fillWidth: true
                    property int rowIndex: index
                    property var rowData: module.haAreaOptions[rowIndex]
                    label: rowData ? rowData.name : ""
                    checked: rowData ? rowData.enabled === true : false
                    enabled: module.haDiscoveryReady && !module.settingsBusy
                    onToggled: module.setHaAreaEnabled(rowIndex, !checked)
                }
            }
        }

        SectionPanel {
            visible: module && module.sectionFilterVisible("Climate")
            Layout.fillWidth: true
            notchLegend: true
            legendText: "Climate"
            legendIcon: "󱤖"
            legendBackground: Theme.background
            label: ""

            Repeater {
                model: module.haClimateOptions.length

                ToggleRow {
                    Layout.fillWidth: true
                    property int rowIndex: index
                    property var rowData: module.haClimateOptions[rowIndex]
                    label: rowData ? rowData.name : ""
                    checked: rowData ? rowData.enabled === true : false
                    enabled: module.haDiscoveryReady && !module.settingsBusy
                    onToggled: module.setHaClimateEnabled(rowIndex, !checked)
                }
            }
        }
    }
}
