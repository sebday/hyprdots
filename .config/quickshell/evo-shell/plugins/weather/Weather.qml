import Quickshell
import QtQuick
import "../../Commons"
import "../panel/modules"

Item {
    id: root

    property var shell: null
    property bool opened: false

    function open(payloadJson) {
        opened = true
        weatherContent.onActivated()
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.weather")
        else close()
    }

    CenteredOverlay {
        opened: root.opened
        layerNamespace: "evo-weather"
        contentWidth: 400
        contentHeight: 540
        onDismissed: root.dismiss()

        WeatherModule {
            id: weatherContent
            anchors.fill: parent
            host: root
        }
    }
}
