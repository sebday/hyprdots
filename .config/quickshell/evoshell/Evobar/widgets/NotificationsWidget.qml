import QtQuick
import "../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property string hoverPopupId: settings.onHover
        ? String(settings.onHover)
        : "evo.bar.popups.notifications"
    readonly property bool trayMode: settings.trayMode === true
    readonly property int trayIconSize: {
        var n = parseInt(settings.trayIconSize, 10)
        return isNaN(n) || n <= 0 ? 18 : n
    }
    readonly property int trayCellWidth: {
        var n = parseInt(settings.trayCellWidth, 10)
        return isNaN(n) || n <= 0 ? trayIconSize + 4 : n
    }
    readonly property var notifService: shell ? shell.serviceFor("evo.sys.notifications") : null
    readonly property int unreadCount: notifService ? (notifService.unreadCount || 0) : 0
    readonly property bool hasUnread: unreadCount > 0
    readonly property string trayIconText: "󰂚"

    implicitWidth: trayMode ? trayCellWidth : iconBox.implicitWidth + Theme.barPaddingX * 2
    implicitHeight: Theme.barHeight
    width: trayMode && parent ? parent.width : implicitWidth
    height: Theme.barHeight

    function setHoverPopup(active) {
        if (!shell || !hoverPopupId)
            return
        if (active)
            shell.hoverEnter(hoverPopupId, root, barPanel)
        else
            shell.hoverLeave(hoverPopupId)
    }

    Item {
        id: iconBox
        anchors.centerIn: parent
        width: root.trayMode ? root.trayIconSize + 10 : bellIcon.implicitWidth + badge.implicitWidth * 0.5
        height: root.trayMode ? root.trayIconSize + 6 : bellIcon.implicitHeight

        Text {
            id: bellIcon
            anchors.centerIn: parent
            text: root.trayIconText
            color: root.hasUnread ? Theme.accent : Theme.foreground
            opacity: root.hasUnread ? 1 : 0.82
            font.family: Theme.fontFamily
            font.pixelSize: root.trayMode ? root.trayIconSize : Theme.fontSize2xl
            font.bold: Theme.fontBold
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        Rectangle {
            id: badge
            visible: root.hasUnread
            anchors.right: bellIcon.right
            anchors.top: bellIcon.top
            anchors.rightMargin: root.trayMode ? -2 : -4
            anchors.topMargin: root.trayMode ? -3 : -2
            width: Math.max(root.trayMode ? 12 : 14, badgeText.implicitWidth + (root.trayMode ? 4 : 6))
            height: root.trayMode ? 12 : 14
            radius: root.trayMode ? 6 : 7
            color: Theme.urgent

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.unreadCount > 9 ? "9+" : String(root.unreadCount)
                color: Theme.background
                font.family: Theme.fontFamily
                font.pixelSize: root.trayMode ? Theme.fontSizeXxs - 1 : Theme.fontSizeXxs
                font.bold: Theme.fontBold
            }
        }
    }

    HoverHandler {
        enabled: !root.trayMode && root.hoverPopupId !== "" && root.shell
        onHoveredChanged: root.setHoverPopup(hovered)
    }

    BarHoverPinArea {
        visible: !root.trayMode
        shell: root.shell
        popupId: root.hoverPopupId
    }

    MouseArea {
        anchors.fill: parent
        visible: root.trayMode
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.setHoverPopup(containsMouse)
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (Util.pinHoverPopupFromBarIfActive(root.shell, root.hoverPopupId))
                    return
            }
        }
    }
}
