import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.calendar"
    layerNamespace: "evo-bar-popups-calendar"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 260

    CalendarModule {}
}
