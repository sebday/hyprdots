import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.steam"
    layerNamespace: "evo-bar-steam"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 120

    SteamModule {}
}
