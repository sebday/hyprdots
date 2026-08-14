import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "Model.js" as Model

Item {
    id: root

    property var host: null

    property date today: new Date()
    property date nowTick: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property string selectedDayKey: Model.keyForDate(today)
    property var weekStartOverride: null

    readonly property string todayKey: Model.keyForDate(today)
    readonly property date viewDate: new Date(viewYear, viewMonth, 1)
    readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()
    readonly property int weekStart: Model.normalizedWeekStart(weekStartOverride, Qt.locale().firstDayOfWeek)
    readonly property var weekdays: Model.weekdayOrder(weekStart)
    readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)
    readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property date selectedDate: Model.dateFromKey(selectedDayKey, today)
    readonly property int selectedWeek: Model.isoWeek(
        selectedDate.getFullYear(),
        selectedDate.getMonth(),
        selectedDate.getDate()
    )

    readonly property int cellWidth: {
        var extra = weekColumnWidth + gutterWidth + cellSpacing * 6
        return Math.max(26, Math.floor((Math.max(200, width) - extra) / 7))
    }
    readonly property int cellHeight: 22
    readonly property int cellSpacing: 2
    readonly property int weekColumnWidth: 22
    readonly property int gutterWidth: 8
    readonly property int headerRowHeight: 16
    readonly property int smallFont: Theme.panelHintFontPixelSize
    readonly property int bodyFont: Theme.panelTitleFontPixelSize
    readonly property int titleFont: Theme.panelTitleFontPixelSize

    function onActivated() {
        today = new Date()
        nowTick = new Date()
        goToToday()
    }

    function weekdayLabel(weekday) {
        return String(Qt.locale().dayName(weekday, Locale.ShortFormat)).replace(/\.$/, "").toUpperCase()
    }

    function selectDay(key) {
        selectedDayKey = String(key)
    }

    function goToToday() {
        viewYear = today.getFullYear()
        viewMonth = today.getMonth()
        selectedDayKey = todayKey
    }

    function moveMonth(delta) {
        var next = Model.stepMonth(viewYear, viewMonth, delta)
        viewYear = next.year
        viewMonth = next.month
    }

    function toggleWeekStart() {
        weekStartOverride = Model.weekStartSettingName(Model.toggledWeekStart(weekStart))
    }

    Timer {
        interval: 60000
        running: host && host.opened
        repeat: true
        onTriggered: {
            nowTick = new Date()
            var key = Model.keyForDate(nowTick)
            if (key === todayKey) return
            var follow = viewingCurrentMonth
            today = nowTick
            if (follow) goToToday()
        }
    }

    implicitHeight: innerCol.implicitHeight
    implicitWidth: 200

    Column {
        id: innerCol
        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 22

            RowLayout {
                anchors.fill: parent
                spacing: 10

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: String(root.today.getFullYear())
                    color: Theme.foreground
                    opacity: 0.55
                    font.family: Theme.fontFamily
                    font.pixelSize: root.smallFont
                    font.letterSpacing: 1
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    Layout.alignment: Qt.AlignVCenter
                    radius: 3
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)

                    Rectangle {
                        width: Math.round(parent.width * root.yearDone)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.yearDonePercent + "%"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.smallFont
                }
            }
        }

        Item {
            width: parent.width
            height: gridCol.y + gridCol.height

            WheelHandler {
                onWheel: function(event) {
                    if (event.angleDelta.y === 0) return
                    root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
                }
            }

            Column {
                id: gridCol
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                spacing: 3

                Row {
                    id: headerRow
                    spacing: root.cellSpacing

                    Rectangle {
                        width: root.weekColumnWidth
                        height: root.headerRowHeight
                        radius: 4
                        color: weekStartMouse.containsMouse ? Theme.panelMantle : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "W"
                            color: weekStartMouse.containsMouse ? Theme.accent : Theme.foreground
                            opacity: weekStartMouse.containsMouse ? 1 : 0.45
                            font.family: Theme.fontFamily
                            font.pixelSize: root.smallFont
                            font.letterSpacing: 1
                            font.bold: Theme.fontBold
                        }

                        MouseArea {
                            id: weekStartMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleWeekStart()
                        }
                    }

                    Item { width: root.gutterWidth; height: root.headerRowHeight }

                    Repeater {
                        model: root.weekdays
                        Text {
                            required property var modelData
                            width: root.cellWidth
                            height: root.headerRowHeight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.weekdayLabel(modelData)
                            color: Theme.foreground
                            opacity: 0.5
                            font.family: Theme.fontFamily
                            font.pixelSize: root.smallFont
                            font.letterSpacing: 1
                            font.bold: Theme.fontBold
                        }
                    }
                }

                Repeater {
                    model: root.weeks
                    Row {
                        required property var modelData
                        spacing: root.cellSpacing

                        Text {
                            width: root.weekColumnWidth
                            height: root.cellHeight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.week
                            color: Theme.foreground
                            opacity: 0.35
                            font.family: Theme.fontFamily
                            font.pixelSize: root.smallFont
                        }

                        Item { width: root.gutterWidth; height: root.cellHeight }

                        Repeater {
                            model: modelData.days
                            Rectangle {
                                id: dayCell
                                required property var modelData
                                readonly property bool selected: modelData.key === root.selectedDayKey

                                width: root.cellWidth
                                height: root.cellHeight
                                radius: 4
                                color: selected
                                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
                                    : "transparent"
                                border.width: modelData.today ? 1 : 0
                                border.color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    color: modelData.inMonth
                                        ? (modelData.weekend
                                            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.75)
                                            : Theme.foreground)
                                        : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.35)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.bodyFont
                                    font.bold: modelData.today
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectDay(dayCell.modelData.key)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                x: gridCol.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
                y: gridCol.y + headerRow.height + gridCol.spacing
                width: 1
                height: gridCol.height - headerRow.height - gridCol.spacing
                color: Theme.foreground
                opacity: 0.1
            }
        }

        Item {
            width: parent.width
            height: 28

            Text {
                anchors.centerIn: parent
                width: 160
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
                color: Theme.foreground
                opacity: 0.6
                font.family: Theme.fontFamily
                font.pixelSize: root.bodyFont
                font.letterSpacing: 1
            }

            MouseArea {
                anchors.left: parent.left
                anchors.leftMargin: gridCol.x - 8
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                onClicked: root.moveMonth(-1)
                Text {
                    anchors.centerIn: parent
                    text: "󰅁"
                    color: parent.containsMouse ? Theme.accent : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.titleFont
                }
            }

            MouseArea {
                anchors.right: parent.right
                anchors.rightMargin: parent.width - gridCol.x - gridCol.width - 8
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                onClicked: root.moveMonth(1)
                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    color: parent.containsMouse ? Theme.accent : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.titleFont
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "WEEK " + root.selectedWeek
            color: Theme.foreground
            opacity: 0.45
            font.family: Theme.fontFamily
            font.pixelSize: root.smallFont
            font.letterSpacing: 1
            font.bold: Theme.fontBold
        }
    }
}
