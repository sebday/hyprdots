import QtQuick
import "../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.weather"
    layerNamespace: "evo-panels-weather"
    contentWidth: Theme.hoverPanelWidthStandard

    WeatherModule {}
}
