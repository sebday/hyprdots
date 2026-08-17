import QtQuick
import "../../Commons"
import "."

BarHoverPopup {
    layerNamespace: "bar-volume"
    contentWidth: 104
    contentMargin: 0
    minContentHeight: 180

    VolumeModule {
        sliderOnly: true
    }
}
