import QtQuick

Item {
    id: root

    property int value: 20
    property int minimum: 10
    property int maximum: 32
    property int step: 1
    property bool enabled: true
    property bool interactive: true
    property real currentValue: NaN
    property string unit: "°C"

    signal valueEdited(int value)
    signal valueCommitted(int value)

    readonly property real span: Math.max(1, maximum - minimum)
    readonly property real fraction: Math.max(0, Math.min(1, (value - minimum) / span))
    readonly property real currentFraction: {
        if (isNaN(currentValue))
            return -1
        return Math.max(0, Math.min(1, (currentValue - minimum) / span))
    }
    readonly property color accentColor: Format.tempColor(interactive ? value : currentValue)
    readonly property string currentLabel: {
        if (isNaN(currentValue))
            return "—"
        return Number(currentValue).toFixed(1) + unit
    }

    implicitWidth: 200
    implicitHeight: Math.max(112, width * 0.58)

    readonly property real cx: width / 2
    readonly property real cy: height - 8
    readonly property real radius: Math.min(width * 0.4, height * 0.72)
    readonly property real arcStart: Math.PI * 0.75
    readonly property real arcSweep: Math.PI * 1.5
    readonly property real readoutCenterY: cy - radius * 0.38

    function clampValue(raw) {
        var n = Math.round(raw / step) * step
        return Math.max(minimum, Math.min(maximum, n))
    }

    function angleForValue(temp) {
        return arcStart + ((temp - minimum) / span) * arcSweep
    }

    function valueFromPoint(x, y) {
        var dx = x - cx
        var dy = y - cy
        var dist = Math.sqrt(dx * dx + dy * dy)
        if (dist < radius * 0.32)
            return value
        var angle = Math.atan2(dy, dx)
        if (angle < 0)
            angle += Math.PI * 2
        var rel = angle - arcStart
        if (rel < 0)
            rel += Math.PI * 2
        if (rel > arcSweep) {
            var before = rel - Math.PI * 2
            if (before >= 0)
                rel = before
            else
                return rel > Math.PI ? maximum : minimum
        }
        return clampValue(minimum + (rel / arcSweep) * span)
    }

    function pointOnArc(temp) {
        var angle = angleForValue(temp)
        return {
            x: cx + Math.cos(angle) * radius,
            y: cy + Math.sin(angle) * radius
        }
    }

    Canvas {
        id: dial
        anchors.fill: parent
        antialiasing: true
        opacity: root.enabled ? 1 : Theme.opacityDisabled

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var start = root.arcStart
            var trackColor = Theme.foregroundTrack
            var accent = root.accentColor

            ctx.lineCap = "round"
            ctx.lineWidth = 8
            ctx.strokeStyle = trackColor
            ctx.beginPath()
            ctx.arc(root.cx, root.cy, root.radius, start, start + root.arcSweep, false)
            ctx.stroke()

            if (root.interactive && root.fraction > 0) {
                ctx.strokeStyle = accent
                ctx.beginPath()
                ctx.arc(root.cx, root.cy, root.radius, start, start + root.arcSweep * root.fraction, false)
                ctx.stroke()
            }

            if (root.currentFraction >= 0) {
                var currentPt = root.pointOnArc(root.minimum + root.currentFraction * root.span)
                ctx.beginPath()
                ctx.fillStyle = Theme.withOpacity(Theme.foreground, 0.85)
                ctx.arc(currentPt.x, currentPt.y, 4, 0, Math.PI * 2)
                ctx.fill()
            }

            if (root.interactive) {
                var handle = root.pointOnArc(root.value)
                ctx.beginPath()
                ctx.fillStyle = accent
                ctx.arc(handle.x, handle.y, 7, 0, Math.PI * 2)
                ctx.fill()
                ctx.lineWidth = 2
                ctx.strokeStyle = Theme.panelBackground
                ctx.stroke()
            }

            ctx.fillStyle = Theme.foreground
            ctx.font = "600 " + Theme.fontSizeXs + "px " + Theme.fontFamily
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            ctx.globalAlpha = Theme.opacityMuted
            var minPt = root.pointOnArc(root.minimum)
            var maxPt = root.pointOnArc(root.maximum)
            ctx.fillText(String(root.minimum) + "°", minPt.x, minPt.y + 10)
            ctx.fillText(String(root.maximum) + "°", maxPt.x, maxPt.y + 10)
            ctx.globalAlpha = 1
        }

        Connections {
            target: root
            function onValueChanged() { dial.requestPaint() }
            function onCurrentValueChanged() { dial.requestPaint() }
            function onInteractiveChanged() { dial.requestPaint() }
            function onMinimumChanged() { dial.requestPaint() }
            function onMaximumChanged() { dial.requestPaint() }
            function onEnabledChanged() { dial.requestPaint() }
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Column {
        id: centerColumn
        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.readoutCenterY - height / 2
        spacing: 4
        opacity: root.enabled ? 1 : Theme.opacityDisabled

        Item {
            id: overlayHost
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            visible: children.length > 0
        }

        default property alias overlay: overlayHost.data

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.interactive
            text: String(root.value) + "°"
            color: root.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize4xl
            font.bold: Theme.fontBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !isNaN(root.currentValue)
            text: "now " + root.currentLabel
            color: Theme.foreground
            opacity: Theme.opacityMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
        }
    }

    MouseArea {
        z: 1
        anchors.fill: parent
        enabled: root.enabled && root.interactive
        cursorShape: Qt.PointingHandCursor

        property int dragStartValue: root.value

        onPressed: function(mouse) {
            dragStartValue = root.value
            root.valueEdited(root.valueFromPoint(mouse.x, mouse.y))
        }

        onPositionChanged: function(mouse) {
            if (pressed)
                root.valueEdited(root.valueFromPoint(mouse.x, mouse.y))
        }

        onReleased: function(mouse) {
            root.valueCommitted(root.valueFromPoint(mouse.x, mouse.y))
        }

        onCanceled: {
            root.valueEdited(dragStartValue)
        }
    }
}
