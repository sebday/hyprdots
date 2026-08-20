import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.weather"
    layerNamespace: "evo-bar-popups-weather"
    contentWidth: Theme.hoverPopupWidthStandard

    WeatherModule {}
}
