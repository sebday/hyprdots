import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-stocks"
    contentWidth: Theme.hoverPopupWidthStandard

    StocksModule {
        id: stocksModule
    }
}
