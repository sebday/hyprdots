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

    BarHoverPopup {
        shell: root.shell
        opened: root.opened
        layerNamespace: "evo-weather"
        contentWidth: 560
        contentHeight: 300
        contentMargin: 12

        WeatherModule {
            id: weatherContent
            anchors.fill: parent
            host: root
        }
    }
}
