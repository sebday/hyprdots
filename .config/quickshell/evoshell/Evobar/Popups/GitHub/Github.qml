import QtQuick
import "../../../Commons"
import "."

BarHoverPopup {
    pluginId: "evo.bar.popups.github"
    layerNamespace: "evo-bar-popups-github"
    contentWidth: Theme.hoverPopupWidthStandard

    GithubModule {}
}
