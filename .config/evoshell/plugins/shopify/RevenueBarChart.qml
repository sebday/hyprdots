import QtQuick
import "../commons"

Item {
    id: root

    property var bars: []
    property string currency: "£"
    property int tooltipIndex: -1

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
        var orders = tooltipOrders(tooltipBar)
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

    function tooltipDate(bar) {
        if (!bar || !bar.date)
            return ""
        return Format.formatDay(bar.date)
    }

    function tooltipValue(bar) {
        if (!bar || bar.value === undefined || bar.value === null)
            return ""
        return Format.formatRevenue(bar.value, currency)
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

                    readonly property bool barHovered: barHit.containsMouse
                        || root.tooltipIndex === index

                    readonly property real plotH: plotArea.height

                    Rectangle {
                        anchors.fill: parent
                        visible: barCell.barHovered
                        radius: Theme.radiusS
                        color: Theme.withOpacity(Theme.accent, 0.1)
                        border.width: 1
                        border.color: Theme.withOpacity(Theme.accent, 0.35)
                    }

                    Rectangle {
                        width: Math.min(root.effectiveBarWidth, parent.width - 1)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        height: root.barHeightFor(modelData, barCell.plotH)
                        radius: Theme.radiusS
                        transformOrigin: Item.Bottom
                        scale: barCell.barHovered ? 1.06 : 1
                        opacity: barCell.barHovered ? 1 : 0.82
                        border.width: barCell.barHovered ? 2 : 0
                        border.color: Theme.accent

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
                                    barCell.barHovered ? 1 : 0.9)
                            }
                            GradientStop {
                                position: 1
                                color: root.barColorAlpha(
                                    modelData,
                                    barCell.barHovered ? 0.72 : 0.4)
                            }
                        }
                    }

                    MouseArea {
                        id: barHit
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
