import QtQuick
import QtQuick.Layouts
import qs.commons

Item {
    id: root

    property var module: null

    implicitWidth: parent ? parent.width : Theme.settingsPanelWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            visible: module && module.sectionFilterVisible("Display")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            legendBackground: Theme.background
            label: ""

            HoverPanelLabelPill {
                text: "Display"
                icon: "󰍹"
                fontSize: Theme.fontSizeS
            }

            SliderSetting {
                Layout.fillWidth: true
                label: "Lock after"
                value: module ? module.idleLockMin : 15
                minimum: 0
                maximum: 120
                step: 5
                valueSuffix: "m"
                enabled: module && module.idleReady && !module.settingsBusy
                onValueCommitted: function(value) {
                    if (module)
                        module.setIdleLockMin(value)
                }
            }
        }
    }
}
