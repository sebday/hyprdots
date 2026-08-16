import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-weather"
    contentWidth: Theme.hoverPopupWidthStandard

    WeatherModule {}
}
