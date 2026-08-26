import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.calendar"
    layerNamespace: "evo-panels-calendar"
    contentWidth: Theme.hoverPanelWidthStandard
    minContentHeight: 260

    CalendarModule {}
}
