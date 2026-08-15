import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "evo-weather"
    contentWidth: Theme.hoverPopupWidthWide

    WeatherModule {}
}
