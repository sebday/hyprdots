import QtQuick

MouseArea {
    id: root

    property var shell: null
    property string popupId: ""

    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    enabled: popupId !== "" && shell

    onClicked: function(mouse) {
        if (mouse.button !== Qt.RightButton || !shell || !popupId)
            return
        Util.pinHoverPanelFromBarIfActive(shell, popupId)
    }
}
