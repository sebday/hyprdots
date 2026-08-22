import QtQuick
import QtQuick.Layouts
import "../../commons"
import "Model.js" as Model

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPanelWidth: 0

    property date today: new Date()
    property date nowTick: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property string selectedDayKey: Model.keyForDate(today)

    readonly property string todayKey: Model.keyForDate(today)
    readonly property date viewDate: new Date(viewYear, viewMonth, 1)
    readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()
    readonly property int weekStart: Model.normalizedWeekStart(null, Qt.locale().firstDayOfWeek)
    readonly property var weekdays: Model.weekdayOrder(weekStart)
    readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)
    readonly property date selectedDate: Model.dateFromKey(selectedDayKey, today)
    readonly property int yearDonePercent: Model.yearProgressPercent(
        selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate())
    readonly property real yearDone: Model.yearProgress(
        selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate())
    readonly property int selectedWeek: Model.isoWeek(
        selectedDate.getFullYear(),
        selectedDate.getMonth(),
        selectedDate.getDate()
    )
    readonly property string selectedDateLabel: Qt.formatDate(root.selectedDate, "dddd, d MMMM")
    readonly property string selectedYearLabel: String(root.selectedDate.getFullYear())

    readonly property int cellWidth: {
        var extra = cellSpacing * 6
        return Math.max(28, Math.floor((Math.max(200, hoverPanelWidth) - extra) / 7))
    }
    readonly property int cellHeight: 26
    readonly property int cellSpacing: 3
    readonly property int headerRowHeight: 18
    readonly property int gridWidth: cellWidth * 7 + cellSpacing * 6
    readonly property int hintFont: Theme.fontSizeL
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int titleFont: Theme.fontSize2xl
    readonly property string calendarLegendLabel: "Calendar"
    readonly property string calendarLegendLogo: "https://www.google.com/s2/favicons?domain=calendar.google.com&sz=32"
    readonly property string calendarLegendIcon: "󰃭"

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

    ColumnLayout {
        id: innerCol
        width: root.hoverPanelWidth
        spacing: Theme.hoverPanelSectionSpacing

        SectionPanel {
            label: ""
            Layout.fillWidth: true
            sectionSpacing: 10
            contentPad: Theme.hoverPanelContentPad

            HoverPanelLabelPill {
                text: root.calendarLegendLabel
                icon: root.calendarLegendIcon
                iconUrl: root.calendarLegendLogo
                fontSize: Theme.fontSizeS
            }

            Text {
                Layout.fillWidth: true
                text: root.selectedDateLabel
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.titleFont
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingL

                Text {
                    text: "Week " + root.selectedWeek
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    font.bold: Theme.fontBold
                    font.letterSpacing: 0.5
                }

                Text {
                    text: "·"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: 0.35
                }

                Text {
                    text: root.selectedYearLabel
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: Theme.opacityMuted
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.yearDonePercent + "% of year"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: Theme.opacityMuted
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: Theme.radiusS
                color: Theme.foregroundHoverWash

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
        }

        SectionPanel {
            label: ""
            Layout.fillWidth: true
            sectionSpacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: root.gridWidth
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingS

                NavButton {
                    icon: "󰅁"
                    onTriggered: root.moveMonth(-1)
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                    font.bold: Theme.fontBold
                    font.letterSpacing: 0.5
                }

                NavButton {
                    icon: "󰅂"
                    onTriggered: root.moveMonth(1)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: root.gridWidth
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: gridCol.implicitHeight

                WheelHandler {
                    onWheel: function(event) {
                        if (event.angleDelta.y === 0) return
                        root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
                    }
                }

                Column {
                    id: gridCol
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.cellSpacing

                    Row {
                        spacing: root.cellSpacing

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
                                font.pixelSize: root.hintFont
                                font.letterSpacing: 0.5
                                font.bold: Theme.fontBold
                            }
                        }
                    }

                    Repeater {
                        model: root.weeks
                        Row {
                            required property var modelData
                            spacing: root.cellSpacing

                            Repeater {
                                model: modelData.days
                                DayCell {
                                    cellWidth: root.cellWidth
                                    cellHeight: root.cellHeight
                                    selected: modelData.key === root.selectedDayKey
                                    onActivated: root.selectDay(modelData.key)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component NavButton: Item {
        id: navBtn

        property string icon: ""
        signal triggered()

        implicitWidth: 28
        implicitHeight: 28

        Rectangle {
            anchors.fill: parent
            radius: Theme.fieldsetCornerRadius
            color: navMouse.containsMouse
                ? Theme.panelMantle
                : Theme.foregroundWash
        }

        Text {
            anchors.centerIn: parent
            text: navBtn.icon
            color: navMouse.containsMouse ? Theme.accent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
            opacity: navMouse.containsMouse ? 1 : 0.75
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navBtn.triggered()
        }
    }

    component DayCell: Item {
        id: dayCell

        required property var modelData
        property bool selected: false
        property int cellWidth: 28
        property int cellHeight: 26

        signal activated()

        implicitWidth: cellWidth
        implicitHeight: cellHeight

        readonly property bool inMonth: dayCell.modelData.inMonth === true
        readonly property bool isToday: dayCell.modelData.today === true
        readonly property bool isWeekend: dayCell.modelData.weekend === true

        Rectangle {
            anchors.fill: parent
            radius: Theme.fieldsetCornerRadius
            color: dayCell.selected
                ? Theme.mixColors(Theme.accent, Theme.mantle, 0.42)
                : (dayCell.isToday
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    : (dayMouse.containsMouse ? Theme.panelMantle : "transparent"))
            border.width: dayCell.selected || dayCell.isToday ? 1 : 0
            border.color: dayCell.selected
                ? Theme.accent
                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)

            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }

        Text {
            anchors.centerIn: parent
            text: dayCell.modelData.day
            color: {
                if (!dayCell.inMonth)
                    return Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.28)
                if (dayCell.selected)
                    return Theme.foreground
                if (dayCell.isToday)
                    return Theme.accent
                if (dayCell.isWeekend)
                    return Theme.withOpacity(Theme.foreground, Theme.opacitySecondary)
                return Theme.foreground
            }
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
            font.bold: dayCell.selected || dayCell.isToday
        }

        MouseArea {
            id: dayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dayCell.activated()
        }
    }
}
