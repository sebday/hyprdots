import QtQuick
import Quickshell
import "../../../Commons"

Item {
    id: audioRoot
    property var bar: null
    property var barPanel: null
    property var settings: ({})
    property var shell: null

    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : ""

    readonly property var audio: shell ? shell.serviceFor("evo.audio") : null

    implicitWidth: label.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPaddingX
        text: audioRoot.audio ? audioRoot.audio.displayText : "󰕾"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.barFontPixelSize
        font.bold: Theme.fontBold
    }

    HoverHandler {
        enabled: audioRoot.hoverPopupId !== "" && audioRoot.shell
        onHoveredChanged: {
            if (!audioRoot.shell || !audioRoot.hoverPopupId) return
            if (hovered)
                audioRoot.shell.hoverEnter(audioRoot.hoverPopupId, audioRoot, audioRoot.barPanel)
            else
                audioRoot.shell.hoverLeave(audioRoot.hoverPopupId)
        }
    }

  MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onWheel: function(wheel) {
            if (!audioRoot.audio) return
            if (wheel.angleDelta.y > 0) audioRoot.audio.stepUp()
            else if (wheel.angleDelta.y < 0) audioRoot.audio.stepDown()
            wheel.accepted = true
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton)
                Quickshell.execDetached(["ghostty", "--class=TUI.main", "-e", "alsamixer"])
            else
                Quickshell.execDetached(["ghostty", "--class=TUI.main", "-e", "wiremix"])
        }
    }
}
