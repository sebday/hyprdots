import QtQuick
import QtQuick.Layouts
import "../../commons"

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

            MonitorLayoutPicker {
                Layout.fillWidth: true
                barOutput: module ? module.barOutput : ""
                barPosition: module ? module.barPosition : "bottom"
                notificationsOutput: module ? module.notificationsOutput : ""
                notificationsPosition: module ? module.notificationsPosition : "bottom"
                enabled: module && module.barReady && module.notificationsReady && !module.settingsBusy
                onBarChosen: function(output, position) {
                    if (module)
                        module.setBar(output, position)
                }
                onNotificationsChosen: function(output, position) {
                    if (module)
                        module.setNotifications(output, position)
                }
            }
        }
    }
}
