import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "bar-volume"
    contentWidth: 104
    minContentHeight: 196

    VolumeModule {
        sliderOnly: true
    }
}
