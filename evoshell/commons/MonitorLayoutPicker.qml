import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string barOutput: ""
    property string barPosition: "bottom"
    property string notificationsOutput: ""
    property string notificationsPosition: "bottom"
    property bool enabled: true
    property bool showWorkspaces: true
    property bool workspaceClickable: false
    property var workspaceByMonitor: ({})

    signal barChosen(string output, string position)
    signal notificationsChosen(string output, string position)
    signal workspaceChosen(string workspaceId)

    readonly property int canvasHeight: 240
    readonly property int canvasPad: Theme.spacingM
    readonly property int edgeStripHeight: 8
    readonly property int notifMarkerWidth: 28
    readonly property int notifMarkerHeight: 8
    readonly property real layoutVerticalStretch: 1.45
    readonly property int workspacePillPadH: 2
    readonly property int workspacePillPadV: 1
    readonly property int workspaceFlowSpacing: 2

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
        var scaleW = availW / layoutBounds.width
        var scaleH = availH / (layoutBounds.height * layoutVerticalStretch)
        return Math.min(scaleW, scaleH)
    }

    readonly property real scaledWidth: layoutBounds.width * layoutScale
    readonly property real scaledHeight: layoutBounds.height * layoutScale * layoutVerticalStretch
    readonly property real layoutOffsetX: (root.width - scaledWidth) / 2
    readonly property real layoutOffsetY: (root.canvasHeight - scaledHeight) / 2

    function monitorRect(screen) {
        if (!screen)
            return ({ x: 0, y: 0, width: 0, height: 0 })
        return {
            x: layoutOffsetX + (screen.x - layoutBounds.minX) * layoutScale,
            y: layoutOffsetY + (screen.y - layoutBounds.minY) * layoutScale * layoutVerticalStretch,
            width: screen.width * layoutScale,
            height: screen.height * layoutScale * layoutVerticalStretch
        }
    }

    function isBarActive(output, position) {
        return String(barOutput) === String(output) && String(barPosition) === String(position)
    }

    function isNotificationsActive(output, position) {
        return String(notificationsOutput) === String(output)
            && String(notificationsPosition) === String(position)
    }

    function parseWorkspaceRules(raw) {
        var map = {}
        try {
            var rules = JSON.parse(String(raw || "[]"))
            for (var i = 0; i < rules.length; i++) {
                var rule = rules[i]
                if (!rule || rule.enabled === false)
                    continue
                var monitor = String(rule.monitor || "")
                var ws = String(rule.workspaceString || "")
                if (!monitor || !ws)
                    continue
                if (!map[monitor])
                    map[monitor] = []
                map[monitor].push(ws)
            }
            var keys = Object.keys(map)
            for (var k = 0; k < keys.length; k++) {
                var key = keys[k]
                map[key].sort(function(a, b) {
                    var na = Number(a)
                    var nb = Number(b)
                    if (isFinite(na) && isFinite(nb))
                        return na - nb
                    return String(a).localeCompare(String(b))
                })
            }
        } catch (e) {
            map = {}
        }
        return map
    }

    function workspacesForMonitor(monitorName) {
        if (!monitorName)
            return []
        var map = workspaceByMonitor
        return map && map[monitorName] ? map[monitorName] : []
    }

    function workspacePillWidth(wsId) {
        return Math.max(12, String(wsId).length * 7) + workspacePillPadH * 2
    }

    function workspaceFlowRows(monitorName, maxWidth) {
        var ids = workspacesForMonitor(monitorName)
        if (!ids.length || maxWidth <= 0)
            return []
        var gap = workspaceFlowSpacing
        var rows = []
        var row = []
        var rowW = 0
        for (var i = 0; i < ids.length; i++) {
            var w = workspacePillWidth(ids[i])
            var needed = rowW === 0 ? w : rowW + gap + w
            if (rowW > 0 && needed > maxWidth) {
                rows.push(row)
                row = [ids[i]]
                rowW = w
            } else {
                row.push(ids[i])
                rowW = needed
            }
        }
        if (row.length)
            rows.push(row)
        return rows
    }

    function isWorkspaceFocused(wsId) {
        if (!Hyprland.focusedWorkspace)
            return false
        var id = String(wsId)
        return id === String(Hyprland.focusedWorkspace.id)
            || id === String(Hyprland.focusedWorkspace.name || "")
    }

    function refreshWorkspaceRules() {
        if (!showWorkspaces || workspaceRulesProc.running)
            return
        workspaceRulesProc.running = true
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

    Process {
        id: workspaceRulesProc
        command: ["bash", "-lc", "hyprctl workspacerules -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.workspaceByMonitor = root.parseWorkspaceRules(text)
        }
    }

    Timer {
        interval: 30000
        running: root.showWorkspaces
        repeat: true
        onTriggered: root.refreshWorkspaceRules()
    }

    Component.onCompleted: refreshWorkspaceRules()

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

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: root.edgeStripHeight + 1
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.edgeStripHeight + 1

                    Column {
                        anchors.centerIn: parent
                        spacing: root.workspaceFlowSpacing
                        width: parent.width

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: monitorItem.monitorName
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: Theme.opacitySecondary
                        }

                        Column {
                            width: parent.width
                            spacing: root.workspaceFlowSpacing
                            visible: root.showWorkspaces
                                && root.workspacesForMonitor(monitorItem.monitorName).length > 0

                            Repeater {
                                model: root.workspaceFlowRows(
                                    monitorItem.monitorName,
                                    monitorItem.width - root.workspacePillPadH * 2)

                                delegate: Row {
                                    required property var modelData
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: root.workspaceFlowSpacing

                                    Repeater {
                                        model: modelData

                                        delegate: Rectangle {
                                            required property string modelData
                                            readonly property string wsId: String(modelData)
                                            readonly property bool focused: root.isWorkspaceFocused(wsId)

                                            radius: Theme.radiusS
                                            color: focused
                                                ? Theme.withOpacity(Theme.accent, 0.14)
                                                : Theme.foregroundSubtle
                                            border.color: focused ? Theme.accent : "transparent"
                                            border.width: focused ? 1 : 0
                                            implicitWidth: wsLabel.width + root.workspacePillPadH * 2
                                            implicitHeight: wsLabel.height + root.workspacePillPadV * 2

                                            Text {
                                                id: wsLabel
                                                anchors.centerIn: parent
                                                text: wsId
                                                color: focused ? Theme.accent : Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                font.bold: focused ? Theme.fontBold : false
                                                opacity: Theme.opacitySecondary
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: root.workspaceClickable
                                                hoverEnabled: root.workspaceClickable
                                                cursorShape: root.workspaceClickable
                                                    ? Qt.PointingHandCursor
                                                    : Qt.ArrowCursor
                                                onClicked: root.workspaceChosen(wsId)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                    z: 2
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
                    z: 2
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
