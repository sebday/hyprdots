import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-stocks"
    contentWidth: Theme.hoverPopupWidthWide
    minContentHeight: stocksModule.stableContentHeight

    StocksModule {
        id: stocksModule
    }
}
