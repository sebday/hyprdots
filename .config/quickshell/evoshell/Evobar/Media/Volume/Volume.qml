import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.media.volume"
    layerNamespace: "evo-bar-media-volume"
    contentWidth: 104
    contentMargin: 0
    minContentHeight: 180

    VolumeModule {
        sliderOnly: true
    }
}
