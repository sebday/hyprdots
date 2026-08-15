import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-cursor"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 320

    CursorModule {}
}
