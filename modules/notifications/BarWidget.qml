import QtQuick
import qs.commons
import qs.ui

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPanelId: settings.onHover
        ? String(settings.onHover)
        : "evo.panels.notifications"
    readonly property var notificationService: shell ? shell.serviceFor("evo.sys.notifications") : null
    readonly property int unreadCount: notificationService && notificationService.unreadCount
        ? notificationService.unreadCount : 0

    implicitWidth: Theme.bar.iconSlot
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: Theme.barHeight

    function openPanel() {
        Util.openBarPanelFromClick(shell, hoverPanelId, root, barPanel)
    }

    Item {
        anchors.centerIn: parent
        width: Theme.bar.iconCanvas
        height: Theme.bar.iconCanvas
        opacity: root.unreadCount > 0 ? Theme.barIconOpacityActive : Theme.barIconOpacity

        OpticalGlyph {
            anchors.fill: parent
            text: "󰂚"
            fontSize: Theme.bar.iconFont
            color: Theme.barIconColor
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPanelFromBarIfActive(root.shell, root.hoverPanelId))
                    return
            }
            if (mouse.button === Qt.LeftButton)
                root.openPanel()
        }
    }
}
