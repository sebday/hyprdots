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

    readonly property int titleFont: Theme.tooltipTitleFontPixelSize
    readonly property int bodyFont: Theme.tooltipBodyFontPixelSize
    readonly property int hintFont: Theme.tooltipHintFontPixelSize
    readonly property int heroFont: Theme.tooltipIconFontPixelSize + 2
    readonly property int chartHeight: 176
    readonly property int yAxisWidth: 40
    readonly property int chartGap: 10

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

    readonly property var columns: {
        var cols = [{
            now: true,
            title: "Now",
            icon: current ? String(current.icon || "󰖐") : "󰖐",
            primary: loading ? "…" : (current ? String(current.temp) + "°" : "—"),
            subtitle: statusText
        }]
        for (var i = 0; i < daily.length; i++) {
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

    implicitHeight: column.implicitHeight

    function onActivated() {
        syncFromBar()
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

    function openMetOffice() {
        if (!metOfficeUrl) return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(metOfficeUrl)])
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
                text: root.location
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.titleFont
                font.bold: Theme.fontBold

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openMetOffice()
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
                                        font.pixelSize: root.heroFont
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.primary
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.heroFont
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
                                        font.pixelSize: root.bodyFont
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.primary
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.bodyFont
                                        font.bold: Theme.fontBold
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.subtitle
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
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
            label: "24 hour temperature"
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
    }
}
