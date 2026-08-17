import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-steam"
    contentWidth: Theme.hoverPopupWidthStandard
    minContentHeight: 120

    SteamModule {}
}
