import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-stocks"
    contentWidth: Theme.hoverPopupWidthWide

    StocksModule {
        id: stocksModule
    }
}
