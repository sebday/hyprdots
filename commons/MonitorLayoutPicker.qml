import Quickshell
import QtQuick

Item {
    id: root

    property string barOutput: ""
    property string barPosition: "bottom"
    property string notificationsOutput: ""
    property string notificationsPosition: "bottom"
    property bool enabled: true

    signal barChosen(string output, string position)
    signal notificationsChosen(string output, string position)

    readonly property int canvasHeight: 180
    readonly property int canvasPad: Theme.spacingM
    readonly property int edgeStripHeight: 8
    readonly property int notifMarkerWidth: 28
    readonly property int notifMarkerHeight: 8

    implicitWidth: 400
    implicitHeight: legendRow.height + canvasHeight + Theme.spacingS

    readonly property var layoutBounds: {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return { minX: 0, minY: 0, width: 1920, height: 1080 }
        var minX = Infinity
        var minY = Infinity
        var maxX = -Infinity
        var maxY = -Infinity
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (!s)
                continue
            minX = Math.min(minX, s.x)
            minY = Math.min(minY, s.y)
            maxX = Math.max(maxX, s.x + s.width)
            maxY = Math.max(maxY, s.y + s.height)
        }
        if (!isFinite(minX))
            return { minX: 0, minY: 0, width: 1920, height: 1080 }
        return {
            minX: minX,
            minY: minY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        }
    }

    readonly property real layoutScale: {
        var availW = Math.max(1, root.width - root.canvasPad * 2)
        var availH = Math.max(1, root.canvasHeight - root.canvasPad * 2)
        return Math.min(availW / layoutBounds.width, availH / layoutBounds.height)
    }

    readonly property real scaledWidth: layoutBounds.width * layoutScale
    readonly property real scaledHeight: layoutBounds.height * layoutScale
    readonly property real layoutOffsetX: (root.width - scaledWidth) / 2
    readonly property real layoutOffsetY: (root.canvasHeight - scaledHeight) / 2

    function monitorRect(screen) {
        if (!screen)
            return ({ x: 0, y: 0, width: 0, height: 0 })
        return {
            x: layoutOffsetX + (screen.x - layoutBounds.minX) * layoutScale,
            y: layoutOffsetY + (screen.y - layoutBounds.minY) * layoutScale,
            width: screen.width * layoutScale,
            height: screen.height * layoutScale
        }
    }

    function isBarActive(output, position) {
        return String(barOutput) === String(output) && String(barPosition) === String(position)
    }

    function isNotificationsActive(output, position) {
        return String(notificationsOutput) === String(output)
            && String(notificationsPosition) === String(position)
    }

    readonly property color barColor: Theme.accent
    readonly property color notificationsColor: Theme.urgent

    Row {
        id: legendRow
        spacing: Theme.spacingL

        Row {
            spacing: Theme.spacingS

            Rectangle {
                width: 18
                height: 4
                radius: Theme.radiusS
                color: root.barColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "Bar"
                color: root.barColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.bold: Theme.fontBold
            }
        }

        Row {
            spacing: Theme.spacingS

            Rectangle {
                width: 12
                height: 4
                radius: Theme.radiusS
                color: root.notificationsColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "Notifications"
                color: root.notificationsColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.bold: Theme.fontBold
            }
        }
    }

    Item {
        id: canvas
        anchors.top: legendRow.bottom
        anchors.topMargin: Theme.spacingS
        width: parent.width
        height: root.canvasHeight

        Repeater {
            model: Quickshell.screens

            delegate: Item {
                id: monitorItem
                required property var modelData

                readonly property string monitorName: modelData ? String(modelData.name || "") : ""
                readonly property var rect: root.monitorRect(modelData)

                x: rect.x
                y: rect.y
                width: rect.width
                height: rect.height

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.panelCornerRadius
                    color: Theme.foregroundWash
                    border.color: Theme.foregroundDivider
                    border.width: 1
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingS * 2
                    horizontalAlignment: Text.AlignHCenter
                    text: monitorItem.monitorName
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    font.bold: Theme.fontBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: Theme.opacitySecondary
                }

                Rectangle {
                    id: topBarStrip
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.edgeStripHeight
                    radius: Theme.radiusS
                    color: root.isBarActive(monitorItem.monitorName, "top")
                        ? root.barColor
                        : Theme.foregroundSubtle
                    opacity: topBarMouse.containsMouse && root.enabled ? 1 : 0.72

                    MouseArea {
                        id: topBarMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.enabled && monitorItem.monitorName !== ""
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.barChosen(monitorItem.monitorName, "top")
                    }
                }

                Rectangle {
                    id: topNotifMarker
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.notifMarkerWidth
                    height: root.notifMarkerHeight
                    radius: Theme.radiusS
                    color: root.isNotificationsActive(monitorItem.monitorName, "top")
                        ? root.notificationsColor
                        : Theme.foregroundTrack
                    border.color: root.isNotificationsActive(monitorItem.monitorName, "top")
                        ? root.notificationsColor
                        : Theme.foregroundDivider
                    border.width: 1
                    opacity: topNotifMouse.containsMouse && root.enabled ? 1 : 0.85

                    MouseArea {
                        id: topNotifMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.enabled && monitorItem.monitorName !== ""
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notificationsChosen(monitorItem.monitorName, "top")
                    }
                }

                Rectangle {
                    id: bottomBarStrip
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.edgeStripHeight
                    radius: Theme.radiusS
                    color: root.isBarActive(monitorItem.monitorName, "bottom")
                        ? root.barColor
                        : Theme.foregroundSubtle
                    opacity: bottomBarMouse.containsMouse && root.enabled ? 1 : 0.72

                    MouseArea {
                        id: bottomBarMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.enabled && monitorItem.monitorName !== ""
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.barChosen(monitorItem.monitorName, "bottom")
                    }
                }

                Rectangle {
                    id: bottomNotifMarker
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.notifMarkerWidth
                    height: root.notifMarkerHeight
                    radius: Theme.radiusS
                    color: root.isNotificationsActive(monitorItem.monitorName, "bottom")
                        ? root.notificationsColor
                        : Theme.foregroundTrack
                    border.color: root.isNotificationsActive(monitorItem.monitorName, "bottom")
                        ? root.notificationsColor
                        : Theme.foregroundDivider
                    border.width: 1
                    opacity: bottomNotifMouse.containsMouse && root.enabled ? 1 : 0.85

                    MouseArea {
                        id: bottomNotifMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.enabled && monitorItem.monitorName !== ""
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notificationsChosen(monitorItem.monitorName, "bottom")
                    }
                }
            }
        }
    }
}
