import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property int tooltipWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null

    readonly property int locationFont: Theme.tooltipTitleFontPixelSize + 8
    readonly property int nowIconFont: Theme.tooltipIconFontPixelSize + 10
    readonly property int nowPrimaryFont: Theme.tooltipIconFontPixelSize + 8
    readonly property int dayIconFont: Theme.tooltipBodyFontPixelSize
    readonly property int dayPrimaryFont: Theme.tooltipBodyFontPixelSize - 1
    readonly property int subtitleFont: Math.max(8, Theme.tooltipHintFontPixelSize - 2)
    readonly property int titleFont: Theme.tooltipTitleFontPixelSize
    readonly property int bodyFont: Theme.tooltipBodyFontPixelSize
    readonly property int hintFont: Theme.tooltipHintFontPixelSize
    readonly property int chartHeight: 176
    readonly property int yAxisWidth: 28
    readonly property int chartGap: 4

    property var weather: ({})
    property bool loading: false
    property bool locationPickerOpen: false

    readonly property string weatherStatePath: (Quickshell.env("HOME") || "") + "/.local/state/evoshell/weather-location.json"
    readonly property var defaultLocations: [
        { name: "Derby", lat: 52.9219, lon: -1.4746 },
        { name: "Edinburgh", lat: 55.9533, lon: -3.1883 },
        { name: "Cardiff", lat: 51.4816, lon: -3.1791 },
        { name: "Belfast", lat: 54.5973, lon: -5.9301 },
        { name: "Reykjavik", lat: 64.1466, lon: -21.9426 },
        { name: "Tokyo", lat: 35.6762, lon: 139.6503 },
        { name: "Singapore", lat: 1.3521, lon: 103.8198 },
        { name: "Buenos Aires", lat: -34.6037, lon: -58.3816 },
        { name: "Honolulu", lat: 21.3069, lon: -157.8583 }
    ]
    readonly property var locationOptions: {
        var item = barSource
        if (item && item.settings && Array.isArray(item.settings.locations) && item.settings.locations.length > 0)
            return item.settings.locations
        return defaultLocations
    }

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

    readonly property var columns: {
        var cols = [{
            now: true,
            title: "Now",
            icon: current ? String(current.icon || "󰖐") : "󰖐",
            primary: loading ? "…" : (current ? String(current.temp) + "°" : "—"),
            subtitle: statusText
        }]
        for (var i = 0; i < daily.length && i < 2; i++) {
            var d = daily[i]
            cols.push({
                now: false,
                title: String(d.dow || ""),
                icon: String(d.icon || "󰖐"),
                primary: String(d.min) + "–" + String(d.max) + "°",
                subtitle: String(d.label || "")
            })
        }
        return cols
    }

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

    function onDeactivated() {
        locationPickerOpen = false
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.polling) {
            loading = true
            return
        }
        if (item && item.lastPayload)
            applyPayload(item.lastPayload)
        else
            applyPayload(null)
    }

    function applyPayload(json) {
        loading = false
        if (!json || typeof json !== "object") {
            weather = { ok: false, error: "Weather unavailable" }
            return
        }
        weather = json
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
        var t = Number(temp)
        if (t >= 34) return Theme.urgent
        if (t >= 28) return Theme.mixColors(Theme.accent, Theme.urgent, 0.62)
        return Theme.accent
    }

    function isCurrentLocation(loc) {
        if (!loc)
            return false
        return String(location).toLowerCase() === String(loc.name || "").toLowerCase()
    }

    function setLocation(loc) {
        if (!loc)
            return
        var name = String(loc.name || "")
        var lat = Number(loc.lat)
        var lon = Number(loc.lon)
        if (!name || isNaN(lat) || isNaN(lon))
            return

        locationPickerOpen = false
        loading = true
        var cacheKey = "weather-" + lat + "-" + lon
        var stateJson = JSON.stringify({ name: name, lat: lat, lon: lon })
        Quickshell.execDetached(["bash", "-lc",
            "mkdir -p \"${HOME}/.local/state/evoshell\" && "
            + "printf %s " + Util.shellQuote(stateJson) + " > " + Util.shellQuote(weatherStatePath)
            + " && rm -f \"${HOME}/.cache/evoshell/bar/" + cacheKey + ".json\""
        ])
        if (barSource && typeof barSource.restartPolling === "function")
            barSource.restartPolling()
    }

    function toggleLocationPicker() {
        locationPickerOpen = !locationPickerOpen
    }

    ColumnLayout {
        id: column
        width: root.tooltipWidth
        spacing: Theme.tooltipSectionSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.location + (root.locationPickerOpen ? "  ▴" : "  ▾")
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.locationFont
                font.bold: Theme.fontBold

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleLocationPicker()
                }
            }

            SectionPanel {
                label: ""
                Layout.fillWidth: true
                visible: root.locationPickerOpen

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 4

                    Repeater {
                        model: root.locationOptions

                        Text {
                            required property var modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.name
                            color: root.isCurrentLocation(modelData) ? Theme.accent : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            font.bold: root.isCurrentLocation(modelData) ? Theme.fontBold : false
                            opacity: root.isCurrentLocation(modelData) ? 1 : 0.72

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setLocation(modelData)
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: root.loading
                text: "Loading…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: 0.72
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: !root.loading && !root.weatherOk
                text: root.statusText
                color: Theme.urgent
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                wrapMode: Text.WordWrap
            }
        }

        SectionPanel {
            label: "Forecast"
            visible: root.weatherOk && !root.loading

            RowLayout {
                Layout.fillWidth: true

                Repeater {
                    model: root.columns

                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.title
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    opacity: 0.6
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: modelData.now ? 4 : 5
                                    visible: modelData.now

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.nowIconFont
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.primary
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.nowPrimaryFont
                                        font.bold: Theme.fontBold
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 4
                                    visible: !modelData.now

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.dayIconFont
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.primary
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.dayPrimaryFont
                                        font.bold: Theme.fontBold
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.subtitle
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.subtitleFont
                                    opacity: modelData.now ? 0.55 : 0.5
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                visible: root.sunrise !== "" || root.sunset !== ""

                    Repeater {
                        model: [
                            { icon: "󰖜", text: root.sunrise },
                            { icon: "󰖛", text: root.sunset }
                        ]

                        RowLayout {
                            required property var modelData
                            spacing: 6
                            visible: modelData.text !== ""

                            Text {
                                text: modelData.icon
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: root.bodyFont
                            }

                            Text {
                                text: modelData.text
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.bodyFont
                                opacity: 0.75
                            }
                        }
                }
            }
        }

        SectionPanel {
            label: "24 hour"
            visible: root.weatherOk && !root.loading && root.hourly.length > 0

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
                                font.pixelSize: root.hintFont
                                font.bold: Theme.fontBold
                                opacity: 0.85
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                text: Math.round(root.hourlyTempRange.rawMin) + "°"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.hintFont
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
                            font.pixelSize: root.hintFont
                            opacity: 0.45
                        }
                    }
                }
            }
        }

        SectionPanel {
            label: "1 week"
            visible: root.weatherOk && !root.loading && root.weekDays.length > 0

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
                        font.pixelSize: root.hintFont
                        font.bold: Theme.fontBold
                        opacity: 0.85
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: Math.round(root.dailyTempRange.rawMin) + "°"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
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
                            font.pixelSize: root.hintFont
                            opacity: 0.45
                        }
                    }
                }
            }
        }
    }
}
