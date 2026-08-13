import Quickshell
import QtQuick
import "../../Commons"
import "."

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
        contentWidth: 1020
        contentHeight: 620
        onDismissed: root.dismiss()

        WeatherModule {
            id: weatherContent
            anchors.fill: parent
            host: root
        }
    }
}
