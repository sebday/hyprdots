import QtQuick
import "../../Commons"
import "."

BarHoverTooltip {
    layerNamespace: "evo-stocks"
    contentWidth: Theme.tooltipWidthWide
    contentMargin: 10

    StocksModule {}
}
