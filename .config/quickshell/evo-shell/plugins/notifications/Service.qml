import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../../Commons"

Scope {
    id: root

    property var shell: null
    property var activePopups: []

    readonly property int popupGap: 10
    readonly property int popupMarginAboveBar: 14
    readonly property int durationMs: {
        var cfg = shell && shell.shellConfig && shell.shellConfig.notifications
        return Math.max(500, parseInt(cfg && cfg.durationMs, 10) || 3000)
    }

    readonly property string barOutput: {
        if (shell && shell.barConfig && shell.barConfig.output)
            return String(shell.barConfig.output).trim()
        return ""
    }

    function screenForOutput(outputName) {
        return Util.screenForOutput(outputName, true)
    }

    readonly property var popupScreen: screenForOutput(barOutput)

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        onNotification: function(notification) {
            notification.tracked = true
            root.enqueuePopup(notification)
        }
    }

    function enqueuePopup(notification) {
        var entry = { notification: notification, key: Date.now() + Math.random() }
        activePopups = activePopups.concat([entry])
        scheduleDismiss(root.durationMs)
    }

    function showBrief(title, body, durationMs) {
        var titleStr = String(title || "")
        var next = []
        for (var i = 0; i < activePopups.length; i++) {
            var item = activePopups[i]
            if (item.local && String(item.title) === titleStr) continue
            next.push(item)
        }
        next.push({
            key: Date.now() + Math.random(),
            local: true,
            title: titleStr,
            body: String(body || "")
        })
        activePopups = next
        scheduleDismiss(Math.max(500, parseInt(durationMs, 10) || root.durationMs))
    }

    function scheduleDismiss(intervalMs) {
        dismissTimer.interval = intervalMs
        dismissTimer.restart()
    }

    function dismissAll() {
        for (var i = 0; i < activePopups.length; i++) {
            var item = activePopups[i]
            if (item.notification) item.notification.dismiss()
        }
        activePopups = []
    }

    function dismissEntry(key) {
        var next = []
        for (var i = 0; i < activePopups.length; i++) {
            var item = activePopups[i]
            if (item.key !== key) next.push(item)
            else if (item.notification) item.notification.dismiss()
        }
        activePopups = next
    }

    function dismissOldest() {
        dismissAll()
    }

    function popupTitle(entry) {
        if (!entry) return ""
        if (entry.local) return String(entry.title || "")
        if (entry.notification) return String(entry.notification.summary || entry.notification.title || "")
        return ""
    }

    function popupBody(entry) {
        if (!entry) return ""
        if (entry.local) return String(entry.body || "")
        if (entry.notification) return String(entry.notification.body || "")
        return ""
    }

    function popupIcon(entry) {
        var title = popupTitle(entry).trim().toLowerCase()
        var body = popupBody(entry).trim().toLowerCase()
        if (title === "volume")
            return body === "muted" || body === "0%" ? "󰝟" : "󰕾"
        if (title.indexOf("error") !== -1 || body.indexOf("error") !== -1)
            return "󰅙"
        return "󰂚"
    }

    function popupMarginLeft(screen) {
        if (!screen) return 0
        return Math.max(0, Math.round((screen.width - Theme.notificationWidth) / 2))
    }

    function popupMarginBottom(screen, stackIndex) {
        var stack = Math.max(0, stackIndex)
        return Theme.barHeight + popupMarginAboveBar + stack * (Theme.notificationStackSlot + popupGap)
    }

    Timer {
        id: dismissTimer
        interval: root.durationMs
        repeat: false
        onTriggered: root.dismissOldest()
    }

    Instantiator {
        model: root.activePopups
        active: true

        delegate: PanelWindow {
            required property var modelData
            required property int index

            screen: root.popupScreen
            color: "transparent"
            implicitWidth: Theme.notificationWidth
            implicitHeight: Math.max(Theme.notificationStackSlot - popupGap, card.height)

            anchors.bottom: true
            anchors.left: true
            margins.bottom: root.popupMarginBottom(root.popupScreen, index)
            margins.left: root.popupMarginLeft(root.popupScreen)

            WlrLayershell.namespace: "evo-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Item {
                id: card
                width: Theme.notificationWidth
                height: innerRow.height + Theme.notificationPadding * 2

                Rectangle {
                    anchors.fill: parent
                    color: Theme.panelBackground
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                    border.width: 1
                }

                Rectangle {
                    width: 5
                    height: parent.height
                    color: Theme.accent
                }

                Row {
                    id: innerRow
                    x: Theme.notificationPadding + 8
                    y: Theme.notificationPadding
                    width: parent.width - Theme.notificationPadding * 2 - 8
                    spacing: 16

                    Text {
                        id: iconLine
                        text: root.popupIcon(modelData)
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.notificationIconSize
                        font.bold: Theme.fontBold
                    }

                    Column {
                        spacing: 6
                        width: parent.width - iconLine.width - parent.spacing

                        Text {
                            id: titleLine
                            text: root.popupTitle(modelData)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.notificationTitleSize
                            font.bold: Theme.fontBold
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            id: bodyLine
                            text: root.popupBody(modelData)
                            color: Theme.foreground
                            opacity: 0.88
                            visible: text.length > 0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.notificationBodySize
                            font.bold: Theme.fontBold
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton && modelData)
                        root.dismissEntry(modelData.key)
                }
            }
        }
    }
}
