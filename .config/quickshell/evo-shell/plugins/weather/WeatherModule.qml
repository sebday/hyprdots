import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null

    readonly property string home: Quickshell.env("HOME")
    readonly property bool active: host && host.opened === true
    readonly property int colWidth: 88

    property var weather: ({})
    readonly property bool weatherOk: weather.ok === true
    readonly property string location: String(weather.location || "Derby")
    readonly property string metOfficeUrl: String(weather.metOfficeUrl || "https://weather.metoffice.gov.uk/forecast/gcqvn6pq4")
    readonly property var current: weather.current || null
    readonly property var daily: Array.isArray(weather.daily) ? weather.daily : []
    readonly property var hourly: Array.isArray(weather.hourly) ? weather.hourly : []
    readonly property string sunrise: String(weather.sunrise || "")
    readonly property string sunset: String(weather.sunset || "")
    readonly property string statusText: poll.loading
        ? "Loading…"
        : (weatherOk && current ? String(current.label || "") : String(weather.error || "Unavailable"))

    readonly property var columns: {
        var cols = [{
            now: true,
            title: "Now",
            icon: current ? String(current.icon || "󰖐") : "󰖐",
            primary: poll.loading ? "…" : (current ? String(current.temp) + "°" : "—"),
            subtitle: statusText
        }]
        for (var i = 0; i < daily.length; i++) {
            var d = daily[i]
            cols.push({
                now: false,
                title: String(d.dow || ""),
                icon: String(d.icon || "󰖐"),
                primary: String(d.min) + "—" + String(d.max) + "°",
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
            min: minV - span * 0.12,
            max: maxV + span * 0.12,
            rawMin: minV,
            rawMax: maxV
        }
    }

    function onActivated() {
        poll.runPoll()
        Qt.callLater(function() {
            if (root.active)
                focusSink.forceActiveFocus()
        })
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

    Item {
        id: focusSink
        anchors.fill: parent
        focus: root.active
        Keys.onEscapePressed: {
            if (host && typeof host.dismiss === "function")
                host.dismiss()
        }
    }

    JsonPollRunner {
        id: poll
        active: root.active
        defaultIntervalSec: 600
        command: ["bash", root.home + "/.local/bin/evo-panel-weather.sh"]
        onPolled: function(json) { root.weather = json && json.ok === true ? json : (json || { ok: false, error: "Weather unavailable" }) }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.location
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
            font.bold: Theme.fontBold

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openMetOffice()
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Repeater {
                model: root.columns

                ColumnLayout {
                    required property var modelData
                    Layout.preferredWidth: root.colWidth
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.title
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelHintFontPixelSize
                        opacity: 0.65
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.colWidth
                        Layout.preferredHeight: 28
                        spacing: modelData.now ? 6 : 4

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.icon
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: modelData.now ? 28 : 16
                            font.bold: modelData.now ? Theme.fontBold : false
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.primary
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: modelData.now ? 24 : Theme.panelHintFontPixelSize
                            font.bold: Theme.fontBold
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.subtitle
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelHintFontPixelSize
                        opacity: modelData.now ? 0.55 : 0.5
                        elide: Text.ElideRight
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            visible: root.weatherOk && (root.sunrise !== "" || root.sunset !== "")

            Repeater {
                model: [
                    { icon: "󰖜", text: root.sunrise },
                    { icon: "󰖛", text: root.sunset }
                ]

                RowLayout {
                    required property var modelData
                    spacing: 4
                    visible: modelData.text !== ""

                    Text {
                        text: modelData.icon
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelSmallFontPixelSize
                    }

                    Text {
                        text: modelData.text
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelSmallFontPixelSize
                        opacity: 0.75
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 72
            visible: root.weatherOk && root.hourly.length > 0

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                text: Math.round(root.hourlyTempRange.rawMax) + "°"
                color: root.tempColor(root.hourlyTempRange.rawMax)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelHintFontPixelSize
                font.bold: Theme.fontBold
                opacity: 0.85
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                text: Math.round(root.hourlyTempRange.rawMin) + "°"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelHintFontPixelSize
                font.bold: Theme.fontBold
                opacity: 0.5
            }

            Canvas {
                id: hourlyChart
                anchors.fill: parent
                anchors.leftMargin: 26

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var pts = root.hourly || []
                    if (pts.length === 0) return

                    var range = root.hourlyTempRange
                    var minV = range.min
                    var maxV = range.max
                    var span = maxV - minV || 1
                    var h = height - 14
                    var padX = 2
                    var padY = 4
                    var usableW = Math.max(1, width - padX * 2)
                    var usableH = Math.max(1, h - padY * 2)
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

                    for (var s = 0; s < pts.length - 1; s++) {
                        var x0 = padX + s * step
                        var x1 = padX + (s + 1) * step
                        var y0 = yAt(pts[s].temp)
                        var y1 = yAt(pts[s + 1].temp)
                        var segColor = root.tempColor(Math.max(Number(pts[s].temp), Number(pts[s + 1].temp)))

                        ctx.beginPath()
                        ctx.moveTo(x0, y0)
                        ctx.lineTo(x1, y1)
                        ctx.lineTo(x1, h)
                        ctx.lineTo(x0, h)
                        ctx.closePath()
                        ctx.globalAlpha = 0.18
                        ctx.fillStyle = segColor
                        ctx.fill()
                        ctx.globalAlpha = 1

                        ctx.beginPath()
                        ctx.moveTo(x0, y0)
                        ctx.lineTo(x1, y1)
                        ctx.strokeStyle = segColor
                        ctx.lineWidth = 1.75
                        ctx.lineJoin = "round"
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }

                    if (nowIndex >= 0) {
                        var nx = padX + nowIndex * step
                        var ny = yAt(pts[nowIndex].temp)
                        ctx.beginPath()
                        ctx.moveTo(nx, padY)
                        ctx.lineTo(nx, h)
                        ctx.strokeStyle = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                        ctx.lineWidth = 1
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.arc(nx, ny, 3, 0, Math.PI * 2)
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

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 26
                height: 12
                spacing: 0

                Repeater {
                    model: ["00", "06", "12", "18"]

                    Text {
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelHintFontPixelSize
                        opacity: 0.4
                    }
                }
            }
        }
    }
}
