import QtQuick
import "../../Commons"
import "."

BarHoverTooltip {
    layerNamespace: "evo-cursor"
    contentWidth: Theme.tooltipWidthStandard
    minContentHeight: 320

    CursorModule {}
}
