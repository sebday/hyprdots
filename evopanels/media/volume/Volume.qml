import QtQuick
import "../../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.media.volume"
    layerNamespace: "evo-panels-media-volume"
    contentWidth: 104
    contentMargin: 0
    minContentHeight: 180

    VolumeModule {
        sliderOnly: true
    }
}
