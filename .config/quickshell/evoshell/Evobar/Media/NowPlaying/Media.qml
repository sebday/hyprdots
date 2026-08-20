import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.media.now-playing"
    layerNamespace: "evo-bar-media-now-playing"
    contentWidth: Theme.hoverPopupWidthStandard

    MediaModule {}
}
