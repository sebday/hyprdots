import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: {
        if (host && host.effectivePluginId)
            return host.effectivePluginId
        return shell ? String(shell.hoverPopupId || "") : ""
    }

    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null

    readonly property int primaryStatFont: Theme.fontSize9xl
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int chartAxisFont: Theme.fontSizeS
    readonly property int sectionSpacing: 6
    readonly property int statBoxMinHeight: root.primaryStatFont + root.hintFont + 44
    readonly property int chartHeight: 150
    readonly property int chartLabelPad: 4
    readonly property int chartBottomPad: 22

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
                label: String(d.label || ""),
                code: Number(d.code) || 0,
                min: Number(d.min) || 0,
                max: Number(d.max) || 0
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

    readonly property int todayCode: root.daily.length > 0 ? (Number(root.daily[0].code) || 0) : 0
    readonly property int tomorrowCode: root.daily.length > 1 ? (Number(root.daily[1].code) || 0) : 0

    function tempColor(temp) {
        return Format.tempColor(temp)
    }

    function weatherStyle(code) {
        var c = Number(code)
        if (isNaN(c))
            c = 0
        if (c === 0)
            return { accent: "#f0b429", glow: "#ffe08a", fill: Qt.rgba(240 / 255, 180 / 255, 41 / 255, 0.2) }
        if (c === 1)
            return { accent: "#7ec8f0", glow: "#b8e4ff", fill: Qt.rgba(126 / 255, 200 / 255, 240 / 255, 0.18) }
        if (c <= 3)
            return { accent: "#8aa4bc", glow: "#b8c9d9", fill: Qt.rgba(138 / 255, 164 / 255, 188 / 255, 0.18) }
        if (c <= 48)
            return { accent: "#a8b0ba", glow: "#d0d6de", fill: Qt.rgba(168 / 255, 176 / 255, 186 / 255, 0.16) }
        if (c <= 67)
            return { accent: "#5b9bd5", glow: "#8ec5f0", fill: Qt.rgba(91 / 255, 155 / 255, 213 / 255, 0.2) }
        if (c <= 86)
            return { accent: "#b8d4e8", glow: "#e8f4fc", fill: Qt.rgba(184 / 255, 212 / 255, 232 / 255, 0.2) }
        if (c <= 99)
            return { accent: "#a78bfa", glow: "#d4c4ff", fill: Qt.rgba(167 / 255, 139 / 255, 250 / 255, 0.2) }
        return { accent: Theme.accent, glow: Theme.accent, fill: Theme.withOpacity(Theme.accent, 0.14) }
    }

    function hourFractionFromTime(timeStr) {
        var parts = String(timeStr || "").split(":")
        if (parts.length < 1)
            return 0
        var h = parseInt(parts[0], 10)
        var m = parseInt(parts[1] || "0", 10)
        if (isNaN(h))
            h = 0
        if (isNaN(m))
            m = 0
        return h + m / 60
    }

    function sunXOnChart(timeStr, chartWidth) {
        var hours = hourly
        if (!timeStr || !hours || hours.length < 2 || chartWidth <= 0)
            return -1
        var target = hourFractionFromTime(timeStr)
        var padX = 2
        var usableW = Math.max(1, chartWidth - padX * 2)
        var first = hourFractionFromTime(hours[0].time)
        var last = hourFractionFromTime(hours[hours.length - 1].time)
        if (target <= first)
            return padX
        if (target >= last)
            return padX + usableW
        for (var i = 0; i < hours.length - 1; i++) {
            var a = hourFractionFromTime(hours[i].time)
            var b = hourFractionFromTime(hours[i + 1].time)
            if (target < a || target > b)
                continue
            var t = (b - a) > 0 ? (target - a) / (b - a) : 0
            var x0 = padX + (i / (hours.length - 1)) * usableW
            var x1 = padX + ((i + 1) / (hours.length - 1)) * usableW
            return x0 + t * (x1 - x0)
        }
        return -1
    }

    function openMetOffice() {
        if (!metOfficeUrl)
            return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(metOfficeUrl)])
    }

    component WeatherStatBackdrop: Item {
        id: backdrop
        property var mood: root.weatherStyle(0)
        property string watermarkIcon: ""

        default property alias content: body.data

        property color moodAccent: backdrop.mood.accent

        implicitWidth: body.implicitWidth
        implicitHeight: body.implicitHeight

        Rectangle {
            anchors.fill: parent
            radius: Theme.fieldsetCornerRadius
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(backdrop.moodAccent.r, backdrop.moodAccent.g, backdrop.moodAccent.b, 0.16) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 2
            anchors.topMargin: -4
            text: backdrop.watermarkIcon
            color: backdrop.moodAccent
            font.family: Theme.fontFamily
            font.pixelSize: 52
            opacity: 0.1
        }

        ColumnLayout {
            id: body
            anchors.fill: parent
            spacing: root.sectionSpacing
        }
    }

    component CurrentDayPanel: SectionPanel {
        id: currentDay
        property bool linkable: false
        signal linkActivated()

        readonly property var mood: root.weatherStyle(
            root.current ? (Number(root.current.code) || root.todayCode) : root.todayCode)
        readonly property color moodAccent: currentDay.mood.accent

        label: ""
        filled: true
        fillColor: currentDay.mood.fill
        contentPad: 12
        sectionSpacing: 0
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 1
        Layout.preferredHeight: root.statBoxMinHeight

        WeatherStatBackdrop {
            Layout.fillWidth: true
            mood: currentDay.mood
            watermarkIcon: root.currentIcon

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: root.sectionSpacing

                    HoverPopupLabelPill {
                        text: "Now"
                        fontSize: Theme.fontSizeS
                        fill: Qt.rgba(currentDay.moodAccent.r, currentDay.moodAccent.g, currentDay.moodAccent.b, 0.16)
                        textColor: currentDay.moodAccent
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.currentIcon
                            color: currentDay.moodAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.primaryStatFont
                            font.bold: Theme.fontBold
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
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentLabel
                        visible: root.currentLabel !== ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: Theme.opacityMuted
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                    color: Theme.foregroundDivider
                    opacity: 0.45
                    visible: root.todayOutlook !== null
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    visible: root.todayOutlook !== null
                    spacing: root.sectionSpacing

                    HoverPopupLabelPill {
                        text: "Today"
                        fontSize: Theme.fontSizeS
                        fill: Qt.rgba(currentDay.moodAccent.r, currentDay.moodAccent.g, currentDay.moodAccent.b, 0.12)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.todayOutlook ? root.todayOutlook.icon : ""
                            color: currentDay.moodAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: root.primaryStatFont
                            font.bold: Theme.fontBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.todayOutlook ? root.todayOutlook.range : ""
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.primaryStatFont
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.todayOutlook ? root.todayOutlook.label : ""
                        visible: root.todayOutlook && root.todayOutlook.label !== ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        opacity: Theme.opacityMuted
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
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

        readonly property var mood: root.weatherStyle(root.tomorrowCode)
        readonly property color moodAccent: outlook.mood.accent

        label: ""
        filled: true
        fillColor: outlook.mood.fill
        contentPad: 12
        sectionSpacing: 0
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 1
        Layout.preferredHeight: root.statBoxMinHeight

        WeatherStatBackdrop {
            Layout.fillWidth: true
            mood: outlook.mood
            watermarkIcon: outlook.boxIcon

            HoverPopupLabelPill {
                text: outlook.boxTitle
                fontSize: Theme.fontSizeS
                fill: Qt.rgba(outlook.moodAccent.r, outlook.moodAccent.g, outlook.moodAccent.b, 0.16)
                textColor: outlook.moodAccent
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    visible: outlook.boxIcon !== ""
                    text: outlook.boxIcon
                    color: outlook.moodAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.primaryStatFont
                    font.bold: Theme.fontBold
                }

                Text {
                    Layout.fillWidth: true
                    text: outlook.boxValue
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.primaryStatFont
                    font.bold: Theme.fontBold
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
                opacity: Theme.opacityMuted
                elide: Text.ElideRight
                maximumLineCount: 1
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
                opacity: Theme.opacitySecondary
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
            spacing: Theme.spacingL
            visible: root.weatherOk && !root.loading

            CurrentDayPanel {
                Layout.fillWidth: true
                Layout.preferredWidth: 66
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                linkable: root.metOfficeUrl !== ""
                onLinkActivated: root.openMetOffice()
            }

            OutlookStatBox {
                visible: root.tomorrowOutlook !== null
                Layout.fillWidth: true
                Layout.preferredWidth: 34
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                boxTitle: root.tomorrowOutlook ? root.tomorrowOutlook.title : ""
                boxIcon: root.tomorrowOutlook ? root.tomorrowOutlook.icon : ""
                boxValue: root.tomorrowOutlook ? root.tomorrowOutlook.range : ""
                boxDetail: root.tomorrowOutlook ? root.tomorrowOutlook.label : ""
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

                    Item {
                        id: hourlyChartHost
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.chartHeight + root.chartBottomPad

                        Text {
                            id: hourlyMaxLabel
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.topMargin: 2
                            anchors.leftMargin: root.chartLabelPad
                            z: 2
                            text: Math.round(root.hourlyTempRange.rawMax) + "°"
                            color: root.tempColor(root.hourlyTempRange.rawMax)
                            font.family: Theme.fontFamily
                            font.pixelSize: root.chartAxisFont
                            font.bold: Theme.fontBold
                            opacity: 0.85
                        }

                        Canvas {
                            id: hourlyChart
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: root.chartHeight

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

                                    function drawSunMarker(timeStr, color) {
                                        var sx = root.sunXOnChart(timeStr, width)
                                        if (sx < 0)
                                            return
                                        ctx.save()
                                        ctx.beginPath()
                                        ctx.moveTo(sx, padY)
                                        ctx.lineTo(sx, height - padY)
                                        ctx.strokeStyle = color
                                        ctx.globalAlpha = 0.55
                                        ctx.lineWidth = 1
                                        ctx.setLineDash([3, 4])
                                        ctx.stroke()
                                        ctx.restore()
                                    }

                                    for (var i = 0; i < pts.length; i++) {
                                        if (String(pts[i].time || "") === nowLabel)
                                            nowIndex = i
                                    }

                                    var gridColor = Theme.foregroundFaint
                                    for (var g = 0; g <= 2; g++) {
                                        var gy = padY + (usableH / 2) * g
                                        ctx.beginPath()
                                        ctx.moveTo(padX, gy)
                                        ctx.lineTo(width - padX, gy)
                                        ctx.strokeStyle = gridColor
                                        ctx.lineWidth = 1
                                        ctx.stroke()
                                    }

                                    drawSunMarker(root.sunrise, "#f2a65a")
                                    drawSunMarker(root.sunset, "#c084fc")

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
                                        ctx.strokeStyle = Theme.withOpacity(Theme.foreground, 0.2)
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
                                    function onSunriseChanged() { hourlyChart.requestPaint() }
                                    function onSunsetChanged() { hourlyChart.requestPaint() }
                                }

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Component.onCompleted: requestPaint()
                            }

                        Repeater {
                            model: [
                                { time: root.sunrise, glyph: "󰖜", tint: "#f2a65a" },
                                { time: root.sunset, glyph: "󰖛", tint: "#c084fc" }
                            ]

                            delegate: Item {
                                required property var modelData
                                visible: modelData.time !== ""
                                width: sunMarkerColumn.implicitWidth
                                height: sunMarkerColumn.implicitHeight
                                x: root.sunXOnChart(modelData.time, hourlyChartHost.width) - width / 2
                                anchors.top: hourlyChart.bottom
                                anchors.topMargin: 3
                                z: 2

                                Column {
                                    id: sunMarkerColumn
                                    spacing: 0
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.glyph
                                        color: modelData.tint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeS
                                        opacity: 0.9
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.time
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.chartAxisFont
                                        opacity: Theme.opacityMuted
                                    }
                                }
                            }
                        }
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
                                opacity: Theme.opacityDisabled
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    visible: root.weekDays.length > 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.chartHeight

                        Text {
                            id: weeklyMaxLabel
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.topMargin: 2
                            anchors.leftMargin: root.chartLabelPad
                            z: 1
                            text: Math.round(root.dailyTempRange.rawMax) + "°"
                            color: root.tempColor(root.dailyTempRange.rawMax)
                            font.family: Theme.fontFamily
                            font.pixelSize: root.chartAxisFont
                            font.bold: Theme.fontBold
                            opacity: 0.85
                        }

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

                                    var gridColor = Theme.foregroundFaint
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
                                    ctx.strokeStyle = Theme.withOpacity(Theme.foreground, 0.2)
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
                                opacity: Theme.opacityDisabled
                            }
                        }
                    }
                }
            }
        }
    }
}
