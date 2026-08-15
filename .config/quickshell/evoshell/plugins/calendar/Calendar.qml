import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-calendar"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 260

    CalendarModule {}
}
