import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.cursor-usage"
    layerNamespace: "evo-bar-popups-cursor-usage"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 320

    CursorModule {}
}
