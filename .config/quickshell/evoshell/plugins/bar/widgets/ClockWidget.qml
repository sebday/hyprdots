import QtQuick
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})
    property date nowTick: new Date()

    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : "evo.calendar"
    readonly property bool showEffect: settings.effect !== false
    readonly property int dialSize: 17
    readonly property real secondProgress: {
        var s = nowTick.getSeconds()
        var ms = nowTick.getMilliseconds()
        return Math.max(0, Math.min(1, (s + ms / 1000) / 60))
    }
    readonly property string phaseIcon: {
        var h = nowTick.getHours()
        if (h >= 6 && h < 18)
            return "󰖙"
        return "󰖔"
    }

    implicitWidth: clockRow.implicitWidth + Theme.barSectionGap * 2
    implicitHeight: Theme.barHeight

    function strftimeToQt(fmt) {
        var f = String(fmt || "")
        f = f.replace(/%Y/g, "yyyy")
        f = f.replace(/%y/g, "yy")
        f = f.replace(/%m/g, "MM")
        f = f.replace(/%d/g, "dd")
        f = f.replace(/%H/g, "HH")
        f = f.replace(/%I/g, "hh")
        f = f.replace(/%M/g, "mm")
        f = f.replace(/%S/g, "ss")
        f = f.replace(/%p/g, "AP")
        f = f.replace(/%A/g, "dddd")
        f = f.replace(/%a/g, "ddd")
        f = f.replace(/%B/g, "MMMM")
        f = f.replace(/%b/g, "MMM")
        return f
    }

    function qtFormat() {
        var raw = settings.format ? String(settings.format) : "%a %d %H:%M"
        return strftimeToQt(raw)
    }

    function updateText() {
        label.text = Qt.formatDateTime(nowTick, qtFormat())
    }

    Row {
        id: clockRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.barSectionGap
        spacing: 9

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.bold: Theme.fontBold
        }

        Item {
            visible: root.showEffect
            width: root.dialSize
            height: root.dialSize
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: dial
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    var cx = width / 2
                    var cy = height / 2
                    var lw = 1.75
                    var r = Math.min(width, height) / 2 - lw - 0.5
                    var start = -Math.PI / 2
                    var sweep = root.secondProgress * Math.PI * 2
                    var track = Theme.foregroundSubtle

                    ctx.lineWidth = lw
                    ctx.lineCap = "round"

                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.strokeStyle = track
                    ctx.stroke()

                    if (root.secondProgress > 0.001) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, start, start + sweep)
                        ctx.strokeStyle = Theme.accent
                        ctx.stroke()

                        var angle = start + sweep
                        var dotX = cx + r * Math.cos(angle)
                        var dotY = cy + r * Math.sin(angle)
                        ctx.beginPath()
                        ctx.arc(dotX, dotY, 2.1, 0, Math.PI * 2)
                        ctx.fillStyle = Theme.accent
                        ctx.fill()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.phaseIcon
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
                opacity: Theme.opacityEmphasis2
            }

            Connections {
                target: root
                function onSecondProgressChanged() { dial.requestPaint() }
            }

            Component.onCompleted: dial.requestPaint()
        }
    }

    HoverHandler {
        enabled: root.hoverPopupId !== ""
        onHoveredChanged: {
            if (!root.shell || !root.hoverPopupId) return
            if (hovered)
                root.shell.hoverEnter(root.hoverPopupId, root, root.barPanel)
            else
                root.shell.hoverLeave(root.hoverPopupId)
        }
    }

    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: {
            root.nowTick = new Date()
            root.updateText()
        }
    }

    Component.onCompleted: updateText()
}
