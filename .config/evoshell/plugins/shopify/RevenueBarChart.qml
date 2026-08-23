import QtQuick
import "../commons"

Item {
    id: root

    property var bars: []
    property string currency: "£"
    property string valueKind: "currency"
    property bool showOrdersInTooltip: true
    property string colorMode: "default"
    property string chartStyle: "line"
    property int tooltipIndex: -1

    readonly property bool isBarChart: chartStyle === "bar"

    onBarsChanged: {
        tooltipIndex = -1
        if (!isBarChart)
            lineCanvas.requestPaint()
    }

    onColorModeChanged: if (!isBarChart) lineCanvas.requestPaint()
    onChartStyleChanged: if (!isBarChart) lineCanvas.requestPaint()

    readonly property var tooltipBar: {
        if (tooltipIndex < 0 || tooltipIndex >= bars.length)
            return null
        return bars[tooltipIndex]
    }

    readonly property bool hasTooltip: tooltipBar !== null

    readonly property string tooltipLabel: {
        if (!tooltipBar)
            return ""
        var parts = []
        var date = tooltipDate(tooltipBar)
        if (date !== "")
            parts.push(date)
        var value = tooltipValue(tooltipBar)
        if (value !== "")
            parts.push(value)
        var orders = showOrdersInTooltip ? tooltipOrders(tooltipBar) : ""
        if (orders !== "")
            parts.push(orders)
        return parts.join(" · ")
    }

    readonly property int padInset: 6
    readonly property int plotTopInset: padInset

    readonly property real plotWidth: Math.max(0, width - padInset * 2)
    readonly property real plotHeight: Math.max(40, height - plotTopInset - padInset)

    readonly property real slotWidth: bars.length > 0 && plotWidth > 0
        ? plotWidth / bars.length
        : 0

    readonly property real effectiveBarWidth: Math.max(3, slotWidth - 2)

    readonly property var valueRange: valueRangeFor(bars)

    function valueRangeFor(series) {
        var pts = series || []
        var minV = Number.POSITIVE_INFINITY
        var maxV = Number.NEGATIVE_INFINITY
        for (var i = 0; i < pts.length; i++) {
            var v = parseFloat(pts[i] && pts[i].value)
            if (isNaN(v))
                continue
            if (v < minV)
                minV = v
            if (v > maxV)
                maxV = v
        }
        if (!isFinite(minV) || !isFinite(maxV))
            return { min: 0, max: 1 }
        if (minV >= 0 && maxV >= 0) {
            if (maxV === 0)
                return { min: 0, max: 1 }
            var topPad = (maxV - minV) * 0.08
            if (topPad === 0)
                topPad = maxV * 0.08 || 1
            return { min: 0, max: maxV + topPad }
        }
        if (minV === maxV) {
            var pad = Math.abs(minV) * 0.02 || 1
            return { min: minV - pad, max: maxV + pad }
        }
        var span = maxV - minV
        return { min: minV - span * 0.08, max: maxV + span * 0.08 }
    }

    function barColor(bar) {
        return Qt.color(bar && bar.color ? bar.color : Theme.accent)
    }

    function barColorAlpha(bar, alpha) {
        var c = barColor(bar)
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function barHeightFor(bar, plotH) {
        var level = parseInt(bar && bar.level, 10)
        if (isNaN(level) || level <= 0)
            return 0
        return Math.max(2, plotH * level / 7)
    }

    function seriesColor() {
        if (bars.length === 0)
            return Theme.accent
        var last = bars[bars.length - 1]
        return Qt.color(last && last.color ? last.color : Theme.accent)
    }

    function resolvedLineColor() {
        if (colorMode === "revenue")
            return Qt.color("#a6e3a1")
        if (colorMode === "cos")
            return Theme.urgent
        return seriesColor()
    }

    function pointX(index) {
        if (bars.length <= 1)
            return padInset + plotWidth / 2
        return padInset + (plotWidth * index / (bars.length - 1))
    }

    function pointY(value) {
        var n = parseFloat(value)
        var minV = valueRange.min
        var maxV = valueRange.max
        var span = maxV - minV || 1
        if (isNaN(n))
            n = minV
        return plotTopInset + plotHeight - ((n - minV) / span) * plotHeight
    }

    function tooltipDate(bar) {
        if (!bar || !bar.date)
            return ""
        return Format.formatDay(bar.date)
    }

    function tooltipValue(bar) {
        if (!bar || bar.value === undefined || bar.value === null)
            return ""
        var n = parseFloat(bar.value)
        if (isNaN(n))
            return ""
        if (valueKind === "percent")
            return (n * 100).toFixed(1) + "%"
        if (valueKind === "integer")
            return String(Math.round(n))
        return Format.formatRevenue(n, currency)
    }

    function tooltipOrders(bar) {
        var n = parseInt(bar && bar.orders, 10)
        if (isNaN(n) || n <= 0)
            return ""
        return n + " orders"
    }

    implicitHeight: 100

    Item {
        id: plotArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: padInset
        anchors.rightMargin: padInset
        anchors.bottomMargin: padInset
        anchors.topMargin: root.plotTopInset

        Repeater {
            model: 3

            Rectangle {
                required property int index
                anchors.left: parent.left
                anchors.right: parent.right
                y: parent.height * (index + 1) / 4
                height: 1
                color: Theme.withOpacity(Theme.foreground, 0.05)
            }
        }

        Canvas {
            id: lineCanvas
            anchors.fill: parent
            visible: !root.isBarChart

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var pts = root.bars || []
                if (pts.length === 0)
                    return

                var w = width
                var h = height
                var color = root.resolvedLineColor().toString()
                var minV = root.valueRange.min
                var maxV = root.valueRange.max
                var span = maxV - minV || 1
                var step = pts.length > 1 ? w / (pts.length - 1) : 0

                function yAt(v) {
                    var n = parseFloat(v)
                    if (isNaN(n))
                        n = minV
                    return h - ((n - minV) / span) * h
                }

                ctx.beginPath()
                for (var i = 0; i < pts.length; i++) {
                    var x = i * step
                    var y = yAt(pts[i].value)
                    if (i === 0)
                        ctx.moveTo(x, y)
                    else
                        ctx.lineTo(x, y)
                }
                ctx.lineTo((pts.length - 1) * step, h)
                ctx.lineTo(0, h)
                ctx.closePath()
                ctx.globalAlpha = 0.14
                ctx.fillStyle = color
                ctx.fill()
                ctx.globalAlpha = 1

                ctx.beginPath()
                for (var j = 0; j < pts.length; j++) {
                    var x2 = j * step
                    var y2 = yAt(pts[j].value)
                    if (j === 0)
                        ctx.moveTo(x2, y2)
                    else
                        ctx.lineTo(x2, y2)
                }
                ctx.strokeStyle = color
                ctx.lineWidth = 2
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.stroke()
            }

            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: root
                function onValueRangeChanged() { lineCanvas.requestPaint() }
            }
        }

        Rectangle {
            id: hoverGuide
            visible: !root.isBarChart && root.tooltipIndex >= 0
            width: 1
            x: root.tooltipIndex >= 0 ? root.pointX(root.tooltipIndex) - padInset - 0.5 : 0
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Theme.withOpacity(root.resolvedLineColor(), 0.35)
        }

        Rectangle {
            id: hoverDot
            visible: !root.isBarChart && root.tooltipIndex >= 0
            width: 8
            height: 8
            radius: 4
            x: root.tooltipIndex >= 0
                ? root.pointX(root.tooltipIndex) - padInset - width / 2
                : 0
            y: root.tooltipIndex >= 0 && root.tooltipBar
                ? root.pointY(root.tooltipBar.value) - plotTopInset - height / 2
                : 0
            color: root.resolvedLineColor()
            border.width: 2
            border.color: Theme.background

            Behavior on x {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            id: chartRow
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: root.bars

                Item {
                    id: barCell
                    required property var modelData
                    required property int index

                    width: root.slotWidth
                    height: chartRow.height

                    readonly property bool cellHovered: hitArea.containsMouse
                        || root.tooltipIndex === index

                    readonly property real plotH: plotArea.height

                    Rectangle {
                        anchors.fill: parent
                        visible: root.isBarChart && barCell.cellHovered
                        radius: Theme.radiusS
                        color: Theme.withOpacity(root.barColor(barCell.modelData), 0.1)
                        border.width: 1
                        border.color: Theme.withOpacity(root.barColor(barCell.modelData), 0.35)
                    }

                    Rectangle {
                        visible: root.isBarChart
                        width: Math.min(root.effectiveBarWidth, parent.width - 1)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        height: root.barHeightFor(modelData, barCell.plotH)
                        radius: Theme.radiusS
                        transformOrigin: Item.Bottom
                        scale: barCell.cellHovered ? 1.06 : 1
                        opacity: barCell.cellHovered ? 1 : 0.82
                        border.width: barCell.cellHovered ? 2 : 0
                        border.color: root.barColor(barCell.modelData)

                        Behavior on scale {
                            NumberAnimation {
                                duration: 90
                                easing.type: Easing.OutCubic
                            }
                        }

                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop {
                                position: 0
                                color: root.barColorAlpha(
                                    modelData,
                                    barCell.cellHovered ? 1 : 0.9)
                            }
                            GradientStop {
                                position: 1
                                color: root.barColorAlpha(
                                    modelData,
                                    barCell.cellHovered ? 0.72 : 0.4)
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !root.isBarChart && barCell.cellHovered
                        radius: Theme.radiusS
                        color: Theme.withOpacity(root.resolvedLineColor(), 0.08)
                    }

                    MouseArea {
                        id: hitArea
                        anchors.fill: parent
                        z: 1
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse)
                                root.tooltipIndex = index
                            else if (root.tooltipIndex === index)
                                root.tooltipIndex = -1
                        }
                        onClicked: root.tooltipIndex = index
                    }
                }
            }
        }
    }
}
