import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: shell ? String(shell.hoverPopupId || "") : ""

    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null

    readonly property int primaryStatFont: Theme.fontSize9xl
    readonly property int sunEventGlyphFont: root.primaryStatFont + 6
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int chartAxisFont: Theme.fontSizeS
    readonly property int sectionSpacing: 6
    readonly property int statBoxPad: 10
    readonly property int sunEventRowHeight: Theme.hoverPopupContentPad * 2
        + Math.max(root.primaryStatFont + 10, root.primaryStatFont + root.hintFont + 2)
    readonly property int chartHeight: 150
    readonly property int yAxisWidth: 28
    readonly property int chartGap: 4

    property var weather: ({})
    property bool loading: false

    readonly property bool weatherOk: weather.ok === true
    readonly property string location: String(weather.location || "Derby")
    readonly property string metOfficeUrl: String(weather.metOfficeUrl || "https://weather.metoffice.gov.uk/forecast/gcqvn6pq4")
    readonly property var current: weather.current || null
    readonly property var daily: Array.isArray(weather.daily) ? weather.daily : []
    readonly property var hourly: Array.isArray(weather.hourly) ? weather.hourly : []
    readonly property string sunrise: String(weather.sunrise || "")
    readonly property string sunset: String(weather.sunset || "")
    readonly property string statusText: loading
        ? "Loading…"
        : (weatherOk && current ? String(current.label || "") : String(weather.error || "Unavailable"))

    readonly property string currentIcon: current ? String(current.icon || "󰖐") : "󰖐"
    readonly property string currentTemp: loading ? "…" : (current ? String(current.temp) + "°" : "—")
    readonly property string currentLabel: weatherOk && current ? String(current.label || "") : ""

    readonly property var outlookDays: {
        var titles = ["Today", "Tomorrow"]
        var out = []
        for (var i = 0; i < daily.length && i < 2; i++) {
            var d = daily[i]
            out.push({
                title: i < titles.length ? titles[i] : String(d.dow || ""),
                dow: String(d.dow || ""),
                icon: String(d.icon || "󰖐"),
                range: String(d.min) + "–" + String(d.max) + "°",
                label: String(d.label || "")
            })
        }
        return out
    }

    readonly property var todayOutlook: root.outlookDays.length > 0 ? root.outlookDays[0] : null
    readonly property var tomorrowOutlook: root.outlookDays.length > 1 ? root.outlookDays[1] : null

    readonly property string currentHourLabel: {
        if (!current || !current.time) return ""
        var t = String(current.time)
        var idx = t.indexOf("T")
        if (idx < 0) return ""
        return t.slice(idx + 1, idx + 3) + ":00"
    }

    readonly property var hourlyTempRange: {
        var hours = hourly
        if (!hours || hours.length === 0)
            return { min: 0, max: 1, rawMin: 0, rawMax: 0 }
        var minV = Number.POSITIVE_INFINITY
        var maxV = Number.NEGATIVE_INFINITY
        for (var i = 0; i < hours.length; i++) {
            var v = Number(hours[i].temp)
            if (isNaN(v)) continue
            if (v < minV) minV = v
            if (v > maxV) maxV = v
        }
        if (!isFinite(minV) || !isFinite(maxV))
            return { min: 0, max: 1, rawMin: 0, rawMax: 0 }
        if (minV === maxV)
            return { min: minV - 1, max: maxV + 1, rawMin: minV, rawMax: maxV }
        var span = maxV - minV
        return {
            min: minV - span * 0.1,
            max: maxV + span * 0.1,
            rawMin: minV,
            rawMax: maxV
        }
    }

    readonly property var weekDays: daily.slice(0, 7)

    readonly property var dailyTempRange: {
        var days = weekDays
        if (!days || days.length === 0)
            return { min: 0, max: 1, rawMin: 0, rawMax: 0 }
        var minV = Number.POSITIVE_INFINITY
        var maxV = Number.NEGATIVE_INFINITY
        for (var i = 0; i < days.length; i++) {
            var lo = Number(days[i].min)
            var hi = Number(days[i].max)
            if (!isNaN(lo) && lo < minV) minV = lo
            if (!isNaN(hi) && hi > maxV) maxV = hi
        }
        if (!isFinite(minV) || !isFinite(maxV))
            return { min: 0, max: 1, rawMin: 0, rawMax: 0 }
        if (minV === maxV)
            return { min: minV - 1, max: maxV + 1, rawMin: minV, rawMax: maxV }
        var pad = maxV - minV
        return {
            min: minV - pad * 0.1,
            max: maxV + pad * 0.1,
            rawMin: minV,
            rawMax: maxV
        }
    }

    implicitHeight: column.implicitHeight

    function onActivated() {
        syncFromBar()
    }

    function hasDisplayData() {
        return weatherOk || !!(weather && weather.error)
    }

    function bootstrapFromCache() {
        if (!cacheKey || !shell)
            return
        var cached = Util.hoverPopupCacheRead(shell, cacheKey)
        if (cached)
            applyPayload(cached)
    }

    function publishCache(json) {
        if (cacheKey && shell && json && typeof json === "object")
            Util.hoverPopupCacheWrite(shell, cacheKey, json)
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.polling) {
            if (!hasDisplayData())
                loading = true
            return
        }
        if (item && item.lastPayload)
            applyPayload(item.lastPayload)
        else {
            var cached = Util.hoverPopupCacheRead(shell, cacheKey)
            if (cached)
                applyPayload(cached)
            else
                applyPayload(null)
        }
    }

    function applyPayload(json) {
        loading = false
        if (!json || typeof json !== "object") {
            weather = { ok: false, error: "Weather unavailable" }
            return
        }
        weather = json
        publishCache(json)
    }

    onActiveChanged: if (active) syncFromBar()
    onBarSourceChanged: if (active) syncFromBar()

    Connections {
        target: root.barSource
        enabled: root.barSource !== null
        function onLastPayloadChanged() {
            if (root.active) root.syncFromBar()
        }
        function onPollingChanged() {
            if (root.active) root.syncFromBar()
        }
    }

    function tempColor(temp) {
        return Format.tempColor(temp)
    }

    function openMetOffice() {
        if (!metOfficeUrl)
            return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(metOfficeUrl)])
    }

    component CurrentDayPanel: SectionPanel {
        id: currentDay
        property bool linkable: false
        signal linkActivated()

        label: ""
        filled: true
        contentPad: root.statBoxPad
        sectionSpacing: 0
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 2

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.sectionSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.fillWidth: true
                    implicitHeight: nowPill.implicitHeight

                    HoverPopupLabelPill {
                        id: nowPill
                        text: "Now"
                        fontSize: Theme.fontSizeS
                    }
                }

                Rectangle {
                    visible: root.todayOutlook !== null
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: root.hintFont
                    Layout.alignment: Qt.AlignVCenter
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                }

                Item {
                    Layout.fillWidth: true
                    visible: root.todayOutlook !== null
                    implicitHeight: todayPill.implicitHeight

                    HoverPopupLabelPill {
                        id: todayPill
                        text: "Today"
                        fontSize: Theme.fontSizeS
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: root.currentIcon
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.primaryStatFont
                        font.bold: Theme.fontBold
                        lineHeight: root.primaryStatFont
                        lineHeightMode: Text.FixedHeight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentTemp
                        color: root.current
                            ? root.tempColor(root.current.temp)
                            : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.primaryStatFont
                        font.bold: Theme.fontBold
                        lineHeight: root.primaryStatFont
                        lineHeightMode: Text.FixedHeight
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    visible: root.todayOutlook !== null
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: root.primaryStatFont
                    Layout.alignment: Qt.AlignVCenter
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.todayOutlook !== null
                    spacing: 4

                    Text {
                        text: root.todayOutlook ? root.todayOutlook.icon : ""
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.primaryStatFont
                        font.bold: Theme.fontBold
                        lineHeight: root.primaryStatFont
                        lineHeightMode: Text.FixedHeight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.todayOutlook ? root.todayOutlook.range : ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.primaryStatFont
                        font.bold: Theme.fontBold
                        lineHeight: root.primaryStatFont
                        lineHeightMode: Text.FixedHeight
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: root.currentHourLabel
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    lineHeight: root.hintFont
                    lineHeightMode: Text.FixedHeight
                    opacity: root.currentHourLabel !== "" ? 0.55 : 0
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: root.todayOutlook !== null
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: root.hintFont
                    Layout.alignment: Qt.AlignVCenter
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.todayOutlook !== null
                    text: root.todayOutlook ? root.todayOutlook.label : ""
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    lineHeight: root.hintFont
                    lineHeightMode: Text.FixedHeight
                    opacity: root.todayOutlook && root.todayOutlook.label !== "" ? 0.55 : 0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: currentDay.linkable
            cursorShape: Qt.PointingHandCursor
            onClicked: currentDay.linkActivated()
        }
    }

    component OutlookStatBox: SectionPanel {
        id: outlook
        property string boxTitle: ""
        property string boxIcon: ""
        property string boxValue: ""
        property string boxDetail: ""

        label: ""
        filled: true
        contentPad: root.statBoxPad
        sectionSpacing: 0
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 1

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.sectionSpacing

            Item {
                Layout.fillWidth: true
                visible: outlook.boxTitle !== ""
                implicitHeight: titlePill.implicitHeight

                HoverPopupLabelPill {
                    id: titlePill
                    text: outlook.boxTitle
                    fontSize: Theme.fontSizeS
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    visible: outlook.boxIcon !== ""
                    text: outlook.boxIcon
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.primaryStatFont
                    font.bold: Theme.fontBold
                    lineHeight: root.primaryStatFont
                    lineHeightMode: Text.FixedHeight
                }

                Text {
                    Layout.fillWidth: true
                    text: outlook.boxValue
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.primaryStatFont
                    font.bold: Theme.fontBold
                    lineHeight: root.primaryStatFont
                    lineHeightMode: Text.FixedHeight
                    elide: Text.ElideRight
                }
            }

            Text {
                Layout.fillWidth: true
                visible: outlook.boxDetail !== ""
                text: outlook.boxDetail
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                lineHeight: root.hintFont
                lineHeightMode: Text.FixedHeight
                opacity: 0.55
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    component SunEventBox: SectionPanel {
        id: sunEvent
        property string glyph: ""
        property string time: ""
        property string eventLabel: ""
        property color tint: Theme.accent

        readonly property int glyphBox: root.sunEventGlyphFont + 10

        label: ""
        filled: true
        contentPad: 10
        sectionSpacing: 0
        Layout.fillWidth: true
        Layout.minimumWidth: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.preferredWidth: sunEvent.glyphBox
                Layout.preferredHeight: sunEvent.glyphBox
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.fieldsetCornerRadius
                    color: Qt.rgba(sunEvent.tint.r, sunEvent.tint.g, sunEvent.tint.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(sunEvent.tint.r, sunEvent.tint.g, sunEvent.tint.b, 0.34)
                }

                Text {
                    anchors.centerIn: parent
                    text: sunEvent.glyph
                    color: sunEvent.tint
                    font.family: Theme.fontFamily
                    font.pixelSize: root.sunEventGlyphFont
                    font.bold: Theme.fontBold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: sunEvent.time
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.primaryStatFont
                    font.bold: Theme.fontBold
                    lineHeight: root.primaryStatFont
                    lineHeightMode: Text.FixedHeight
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: sunEvent.eventLabel !== ""
                    text: sunEvent.eventLabel
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    opacity: 0.55
                    elide: Text.ElideRight
                }
            }
        }
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: ""
            Layout.fillWidth: true
            visible: root.loading || !root.weatherOk

            Text {
                Layout.fillWidth: true
                visible: root.loading
                text: "Loading…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.bodyFont
                opacity: 0.72
            }

            Text {
                Layout.fillWidth: true
                visible: !root.loading && !root.weatherOk
                text: root.statusText
                color: Theme.urgent
                font.family: Theme.fontFamily
                font.pixelSize: root.bodyFont
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root.weatherOk && !root.loading

            CurrentDayPanel {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                linkable: root.metOfficeUrl !== ""
                onLinkActivated: root.openMetOffice()
            }

            OutlookStatBox {
                visible: root.tomorrowOutlook !== null
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                boxTitle: root.tomorrowOutlook ? root.tomorrowOutlook.title : ""
                boxIcon: root.tomorrowOutlook ? root.tomorrowOutlook.icon : ""
                boxValue: root.tomorrowOutlook ? root.tomorrowOutlook.range : ""
                boxDetail: root.tomorrowOutlook ? root.tomorrowOutlook.label : ""
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root.weatherOk && !root.loading
                && (root.sunrise !== "" || root.sunset !== "")

            SunEventBox {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: root.sunEventRowHeight
                visible: root.sunrise !== ""
                glyph: "󰖜"
                time: root.sunrise
                eventLabel: "Sunrise"
                tint: "#f2a65a"
            }

            SunEventBox {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: root.sunEventRowHeight
                visible: root.sunset !== ""
                glyph: "󰖛"
                time: root.sunset
                eventLabel: "Sunset"
                tint: "#c084fc"
            }
        }

        SectionPanel {
            label: ""
            visible: root.weatherOk && !root.loading
                && (root.hourly.length > 0 || root.weekDays.length > 0)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.hoverPopupSectionSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    visible: root.hourly.length > 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.chartGap

                        ColumnLayout {
                            Layout.preferredWidth: root.yAxisWidth
                            Layout.preferredHeight: root.chartHeight
                            spacing: 0

                            Text {
                                text: Math.round(root.hourlyTempRange.rawMax) + "°"
                                color: root.tempColor(root.hourlyTempRange.rawMax)
                                font.family: Theme.fontFamily
                                font.pixelSize: root.chartAxisFont
                                font.bold: Theme.fontBold
                                opacity: 0.85
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                text: Math.round(root.hourlyTempRange.rawMin) + "°"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.chartAxisFont
                                font.bold: Theme.fontBold
                                opacity: 0.5
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.chartHeight

                            Canvas {
                                id: hourlyChart
                                anchors.fill: parent

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var pts = root.hourly || []
                                    if (pts.length === 0) return

                                    var range = root.hourlyTempRange
                                    var minV = range.min
                                    var maxV = range.max
                                    var span = maxV - minV || 1
                                    var padX = 2
                                    var padY = 12
                                    var usableW = Math.max(1, width - padX * 2)
                                    var usableH = Math.max(1, height - padY * 2)
                                    var step = pts.length > 1 ? usableW / (pts.length - 1) : 0
                                    var nowLabel = root.currentHourLabel
                                    var nowIndex = -1

                                    function yAt(v) {
                                        var n = Number(v)
                                        if (isNaN(n)) n = minV
                                        return padY + usableH - ((n - minV) / span) * usableH
                                    }

                                    for (var i = 0; i < pts.length; i++) {
                                        if (String(pts[i].time || "") === nowLabel)
                                            nowIndex = i
                                    }

                                    var gridColor = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                                    for (var g = 0; g <= 2; g++) {
                                        var gy = padY + (usableH / 2) * g
                                        ctx.beginPath()
                                        ctx.moveTo(padX, gy)
                                        ctx.lineTo(width - padX, gy)
                                        ctx.strokeStyle = gridColor
                                        ctx.lineWidth = 1
                                        ctx.stroke()
                                    }

                                    for (var s = 0; s < pts.length - 1; s++) {
                                        var x0 = padX + s * step
                                        var x1 = padX + (s + 1) * step
                                        var y0 = yAt(pts[s].temp)
                                        var y1 = yAt(pts[s + 1].temp)
                                        var segColor = root.tempColor(Math.max(Number(pts[s].temp), Number(pts[s + 1].temp)))

                                        ctx.beginPath()
                                        ctx.moveTo(x0, y0)
                                        ctx.lineTo(x1, y1)
                                        ctx.lineTo(x1, height - padY)
                                        ctx.lineTo(x0, height - padY)
                                        ctx.closePath()
                                        ctx.globalAlpha = 0.16
                                        ctx.fillStyle = segColor
                                        ctx.fill()
                                        ctx.globalAlpha = 1

                                        ctx.beginPath()
                                        ctx.moveTo(x0, y0)
                                        ctx.lineTo(x1, y1)
                                        ctx.strokeStyle = segColor
                                        ctx.lineWidth = 3
                                        ctx.lineJoin = "round"
                                        ctx.lineCap = "round"
                                        ctx.stroke()
                                    }

                                    if (nowIndex >= 0) {
                                        var nx = padX + nowIndex * step
                                        var ny = yAt(pts[nowIndex].temp)
                                        ctx.beginPath()
                                        ctx.moveTo(nx, padY)
                                        ctx.lineTo(nx, height - padY)
                                        ctx.strokeStyle = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)
                                        ctx.lineWidth = 1
                                        ctx.stroke()

                                        ctx.beginPath()
                                        ctx.arc(nx, ny, 6, 0, Math.PI * 2)
                                        ctx.fillStyle = root.tempColor(pts[nowIndex].temp)
                                        ctx.fill()
                                    }
                                }

                                Connections {
                                    target: root
                                    function onHourlyChanged() { hourlyChart.requestPaint() }
                                    function onCurrentHourLabelChanged() { hourlyChart.requestPaint() }
                                }

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Component.onCompleted: requestPaint()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.chartGap

                        Item {
                            Layout.preferredWidth: root.yAxisWidth
                            Layout.maximumWidth: root.yAxisWidth
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Repeater {
                                model: ["00", "06", "12", "18"]

                                Text {
                                    required property string modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    horizontalAlignment: index === 0 ? Text.AlignLeft
                                        : (index === 3 ? Text.AlignRight : Text.AlignHCenter)
                                    text: modelData
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.chartAxisFont
                                    opacity: 0.45
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    visible: root.weekDays.length > 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.chartGap

                        ColumnLayout {
                            Layout.preferredWidth: root.yAxisWidth
                            Layout.preferredHeight: root.chartHeight
                            spacing: 0

                            Text {
                                text: Math.round(root.dailyTempRange.rawMax) + "°"
                                color: root.tempColor(root.dailyTempRange.rawMax)
                                font.family: Theme.fontFamily
                                font.pixelSize: root.chartAxisFont
                                font.bold: Theme.fontBold
                                opacity: 0.85
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                text: Math.round(root.dailyTempRange.rawMin) + "°"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.chartAxisFont
                                font.bold: Theme.fontBold
                                opacity: 0.5
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.chartHeight

                            Canvas {
                                id: weeklyChart
                                anchors.fill: parent

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var pts = root.weekDays || []
                                    if (pts.length === 0) return

                                    var range = root.dailyTempRange
                                    var minV = range.min
                                    var maxV = range.max
                                    var span = maxV - minV || 1
                                    var padX = 2
                                    var padY = 12
                                    var usableW = Math.max(1, width - padX * 2)
                                    var usableH = Math.max(1, height - padY * 2)
                                    var step = pts.length > 1 ? usableW / (pts.length - 1) : 0

                                    function yAt(v) {
                                        var n = Number(v)
                                        if (isNaN(n)) n = minV
                                        return padY + usableH - ((n - minV) / span) * usableH
                                    }

                                    var gridColor = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                                    for (var g = 0; g <= 2; g++) {
                                        var gy = padY + (usableH / 2) * g
                                        ctx.beginPath()
                                        ctx.moveTo(padX, gy)
                                        ctx.lineTo(width - padX, gy)
                                        ctx.strokeStyle = gridColor
                                        ctx.lineWidth = 1
                                        ctx.stroke()
                                    }

                                    for (var b = 0; b < pts.length; b++) {
                                        var bx = padX + b * step
                                        var byMax = yAt(pts[b].max)
                                        var byMin = yAt(pts[b].min)
                                        var bandColor = root.tempColor(pts[b].max)

                                        ctx.beginPath()
                                        ctx.moveTo(bx, byMax)
                                        ctx.lineTo(bx, byMin)
                                        ctx.strokeStyle = Qt.rgba(bandColor.r, bandColor.g, bandColor.b, 0.35)
                                        ctx.lineWidth = 6
                                        ctx.lineCap = "round"
                                        ctx.stroke()
                                    }

                                    for (var s = 0; s < pts.length - 1; s++) {
                                        var x0 = padX + s * step
                                        var x1 = padX + (s + 1) * step
                                        var y0 = yAt(pts[s].max)
                                        var y1 = yAt(pts[s + 1].max)
                                        var segColor = root.tempColor(Math.max(Number(pts[s].max), Number(pts[s + 1].max)))

                                        ctx.beginPath()
                                        ctx.moveTo(x0, y0)
                                        ctx.lineTo(x1, y1)
                                        ctx.lineTo(x1, height - padY)
                                        ctx.lineTo(x0, height - padY)
                                        ctx.closePath()
                                        ctx.globalAlpha = 0.12
                                        ctx.fillStyle = segColor
                                        ctx.fill()
                                        ctx.globalAlpha = 1

                                        ctx.beginPath()
                                        ctx.moveTo(x0, y0)
                                        ctx.lineTo(x1, y1)
                                        ctx.strokeStyle = segColor
                                        ctx.lineWidth = 3
                                        ctx.lineJoin = "round"
                                        ctx.lineCap = "round"
                                        ctx.stroke()
                                    }

                                    var nx = padX
                                    var ny = yAt(pts[0].max)
                                    ctx.beginPath()
                                    ctx.moveTo(nx, padY)
                                    ctx.lineTo(nx, height - padY)
                                    ctx.strokeStyle = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)
                                    ctx.lineWidth = 1
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.arc(nx, ny, 6, 0, Math.PI * 2)
                                    ctx.fillStyle = root.tempColor(pts[0].max)
                                    ctx.fill()
                                }

                                Connections {
                                    target: root
                                    function onWeatherChanged() { weeklyChart.requestPaint() }
                                }

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Component.onCompleted: requestPaint()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.chartGap

                        Item {
                            Layout.preferredWidth: root.yAxisWidth
                            Layout.maximumWidth: root.yAxisWidth
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Repeater {
                                model: root.weekDays

                                Text {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    horizontalAlignment: index === 0 ? Text.AlignLeft
                                        : (index === root.weekDays.length - 1 ? Text.AlignRight : Text.AlignHCenter)
                                    text: String(modelData.dow || "")
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.chartAxisFont
                                    opacity: 0.45
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
