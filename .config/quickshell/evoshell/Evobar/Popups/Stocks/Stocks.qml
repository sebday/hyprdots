import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.stocks"
    layerNamespace: "evo-bar-popups-stocks"
    contentWidth: Theme.hoverPopupWidthStandard

    StocksModule {
        id: stocksModule
    }
}
