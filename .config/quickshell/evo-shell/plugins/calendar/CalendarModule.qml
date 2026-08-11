import Quickshell
import QtQuick
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
    readonly property string nextWeekStartLabel: Qt.locale().dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)
    readonly property var weekdays: Model.weekdayOrder(weekStart)
    readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey, ({}))
    readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property date selectedDate: Model.dateFromKey(selectedDayKey, today)
    readonly property int selectedWeek: Model.isoWeek(
        selectedDate.getFullYear(),
        selectedDate.getMonth(),
        selectedDate.getDate()
    )

    readonly property int cellWidth: 52
    readonly property int cellHeight: 34
    readonly property int cellSpacing: 2
    readonly property int weekColumnWidth: 32
    readonly property int gutterWidth: 14

    function dismissHost() {
        if (host && typeof host.dismiss === "function")
            host.dismiss()
    }

    function onActivated() {
        today = new Date()
        nowTick = new Date()
        goToToday()
        Qt.callLater(function() {
            if (host && host.opened)
                focusSink.forceActiveFocus()
        })
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

    Item {
        id: focusSink
        anchors.fill: parent
        focus: host && host.opened
        Keys.enabled: host && host.opened
        Keys.onEscapePressed: root.dismissHost()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Left || event.text === "[") moveMonth(-1)
            else if (event.key === Qt.Key_Right || event.text === "]") moveMonth(1)
            else if (event.text === "t" || event.text === "T") goToToday()
            else if (event.text === "w" || event.text === "W") toggleWeekStart()
        }

        Column {
            anchors.fill: parent
            spacing: 8

            // Hero
            Item {
                width: parent.width
                height: 56

                Row {
                    id: heroRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰃭"
                        color: heroMouse.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 36
                    }

                    Text {
                        id: heroDate
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(root.today, "MMMM d")
                        color: heroMouse.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 32
                        font.bold: Theme.fontBold
                    }
                }

                MouseArea {
                    id: heroMouse
                    x: heroRow.x
                    y: heroRow.y
                    width: heroRow.width
                    height: heroRow.height
                    enabled: !root.viewingCurrentMonth
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.goToToday()
                }
            }

            // Year progress
            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(root.today.getFullYear())
                        color: Theme.foreground
                        opacity: 0.55
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.letterSpacing: 1
                    }

                    Rectangle {
                        width: parent.width - 80
                        height: 6
                        anchors.verticalCenter: parent.verticalCenter
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
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.yearDonePercent + "%"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            // Month grid
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
                    y: 12
                    spacing: 3

                    Row {
                        id: headerRow
                        spacing: root.cellSpacing

                        Rectangle {
                            width: root.weekColumnWidth
                            height: 16
                            radius: 4
                            color: weekStartMouse.containsMouse ? Theme.panelMantle : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "W"
                                color: weekStartMouse.containsMouse ? Theme.accent : Theme.foreground
                                opacity: weekStartMouse.containsMouse ? 1 : 0.45
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
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

                        Item { width: root.gutterWidth; height: 16 }

                        Repeater {
                            model: root.weekdays
                            Text {
                                required property var modelData
                                width: root.cellWidth
                                height: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: root.weekdayLabel(modelData)
                                color: Theme.foreground
                                opacity: 0.5
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
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
                                font.pixelSize: 10
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
                                        id: dayNum
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        color: modelData.inMonth
                                            ? (modelData.weekend
                                                ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.75)
                                                : Theme.foreground)
                                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.35)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPixelSize
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

            // Month nav
            Item {
                width: parent.width
                height: 28

                Text {
                    id: monthLabel
                    anchors.centerIn: parent
                    width: 130
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
                    color: Theme.foreground
                    opacity: 0.6
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSize
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
                        font.pixelSize: 14
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
                        font.pixelSize: 14
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "WEEK " + root.selectedWeek
                color: Theme.foreground
                opacity: 0.45
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1
                font.bold: Theme.fontBold
            }
        }
    }
}
