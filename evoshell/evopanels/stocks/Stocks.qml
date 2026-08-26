import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.stocks"
    layerNamespace: "evo-panels-stocks"
    contentWidth: Theme.hoverPanelWidthStandard

    StocksModule {
        id: stocksModule
    }
}
