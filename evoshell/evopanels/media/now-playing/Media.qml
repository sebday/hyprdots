import QtQuick
import "../../../commons"
import "."

BarHoverPanel {
    pluginId: "evo.panels.media.now-playing"
    layerNamespace: "evo-panels-media-now-playing"
    contentWidth: Theme.hoverPanelWidthStandard

    MediaModule {}
}
