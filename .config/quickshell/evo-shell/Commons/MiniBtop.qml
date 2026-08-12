import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var sample: ({})
    property bool active: true
    property bool loading: false
    property int historySize: 28

    property var cpuHistory: []

    readonly property bool ready: sample && sample.ok === true
    readonly property real cpuPercent: ready ? Number(sample.cpuPercent || 0) : 0
    readonly property string hostLabel: ready ? String(sample.host || "") : ""
    readonly property string uptimeLabel: ready ? String(sample.uptime || "") : ""
    readonly property string loadLabel: ready ? Number(sample.load1 || 0).toFixed(2) : ""

    readonly property var diskRows: {
        if (!ready) return []
        var rows = [{
            name: "/",
            percent: Number(sample.diskPercent || 0),
            total: String(sample.diskTotalLabel || "")
        }]
        if (Number(sample.storageTotal || 0) > 0) {
            rows.push({
                name: "sto",
                percent: Number(sample.storagePercent || 0),
                total: String(sample.storageTotalLabel || "")
            })
        }
        if (Number(sample.externalTotal || 0) > 0) {
            rows.push({
                name: "ext",
                percent: Number(sample.externalPercent || 0),
                total: String(sample.externalTotalLabel || "")
            })
        }
        return rows
    }

    implicitWidth: 200
    implicitHeight: content.implicitHeight

    function meterColor(fraction) {
        var f = Math.max(0, Math.min(1, fraction))
        if (f >= 0.9) return Theme.urgent
        if (f >= 0.7) return Theme.accent
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.82)
    }

    function pushSample(json) {
        if (!active || !json || json.ok !== true) return
        sample = json
        var next = cpuHistory.slice()
        next.push(Number(json.cpuPercent || 0))
        if (next.length > historySize)
            next = next.slice(next.length - historySize)
        cpuHistory = next
    }

    function resetHistory() {
        cpuHistory = []
    }

    onActiveChanged: if (!active) resetHistory()

    ColumnLayout {
        id: content
        width: parent.width
        spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.hostLabel || "system"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelSmallFontPixelSize
                    font.bold: Theme.fontBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.uptimeLabel !== ""
                    text: root.uptimeLabel
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelHintFontPixelSize
                    opacity: 0.72
                }

                Text {
                    visible: root.loadLabel !== ""
                    text: "ld " + root.loadLabel
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelHintFontPixelSize
                    opacity: 0.72
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.ready || root.loading

                Text {
                    Layout.preferredWidth: 26
                    text: "cpu"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelHintFontPixelSize
                    font.bold: Theme.fontBold
                    opacity: 0.8
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    Row {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height
                        spacing: 1

                        Repeater {
                            model: root.historySize

                            Rectangle {
                                required property int index
                                property real value: {
                                    var offset = root.cpuHistory.length - root.historySize
                                    var idx = index + Math.max(0, offset)
                                    if (idx < 0 || idx >= root.cpuHistory.length) return 0
                                    return Number(root.cpuHistory[idx] || 0)
                                }

                                anchors.bottom: parent.bottom
                                width: Math.max(2, (parent.width - (root.historySize - 1)) / root.historySize)
                                height: parent.height * Math.max(0.08, value / 100)
                                radius: 1
                                color: root.meterColor(value / 100)
                                opacity: value > 0 ? 0.95 : 0.18
                            }
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: root.loading && !root.ready ? "…" : Math.round(root.cpuPercent) + "%"
                    color: root.meterColor(root.cpuPercent / 100)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelHintFontPixelSize
                    font.bold: Theme.fontBold
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.ready

                Text {
                    Layout.preferredWidth: 26
                    text: "mem"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelHintFontPixelSize
                    font.bold: Theme.fontBold
                    opacity: 0.8
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8

                    Rectangle {
                        anchors.fill: parent
                        radius: 1
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
                    }

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, Number(root.sample.memPercent || 0) / 100))
                        radius: 1
                        color: root.meterColor(Number(root.sample.memPercent || 0) / 100)
                    }
                }

                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Number(root.sample.memPercent || 0)) + "%"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelHintFontPixelSize
                }

                Text {
                    Layout.preferredWidth: 52
                    horizontalAlignment: Text.AlignRight
                    text: String(root.sample.memTotalLabel || "")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelHintFontPixelSize
                    opacity: 0.72
                    elide: Text.ElideLeft
                }
            }

            Repeater {
                model: root.diskRows

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.preferredWidth: 26
                        text: modelData.name
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelHintFontPixelSize
                        font.bold: Theme.fontBold
                        opacity: 0.8
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8

                        Rectangle {
                            anchors.fill: parent
                            radius: 1
                            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
                        }

                        Rectangle {
                            height: parent.height
                            width: parent.width * Math.max(0, Math.min(1, modelData.percent / 100))
                            radius: 1
                            color: root.meterColor(modelData.percent / 100)
                        }
                    }

                    Text {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(modelData.percent) + "%"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelHintFontPixelSize
                    }

                    Text {
                        Layout.preferredWidth: 52
                        horizontalAlignment: Text.AlignRight
                        text: modelData.total
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelHintFontPixelSize
                        opacity: 0.72
                        elide: Text.ElideLeft
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.ready && root.loading
                text: "Loading…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelHintFontPixelSize
                opacity: 0.55
            }
    }
}
