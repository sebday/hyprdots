import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var panel: null
    property var shell: null

    property bool loading: false
    property bool ok: false
    property string errorText: ""
    property string location: "Derby"
    property string metOfficeUrl: "https://weather.metoffice.gov.uk/forecast/gcqvn6pq4"
    property var current: null
    property var daily: []
    property var hourly: []

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-panel-weather.sh"
    readonly property bool active: panel && panel.opened && panel.activeModule === "weather"

    function refresh() {
        if (loadProc.running) return
        loading = true
        loadProc.running = true
    }

    function parseWeather(raw) {
        loading = false
        try {
            var data = JSON.parse(String(raw || "{}"))
            root.ok = data.ok === true
            root.errorText = String(data.error || "")
            root.location = String(data.location || "Derby")
            root.metOfficeUrl = String(data.metOfficeUrl || root.metOfficeUrl)
            root.current = data.current || null
            root.daily = Array.isArray(data.daily) ? data.daily : []
            root.hourly = Array.isArray(data.hourly) ? data.hourly : []
        } catch (e) {
            root.ok = false
            root.errorText = "Weather unavailable"
            root.current = null
            root.daily = []
            root.hourly = []
        }
    }

    function openMetOffice() {
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(root.metOfficeUrl)])
    }

    function onActivated() {
        refresh()
        Qt.callLater(function() {
            if (root.active)
                focusSink.forceActiveFocus()
        })
    }

    Process {
        id: loadProc
        command: ["bash", root.script]
        stdout: StdioCollector {
            onStreamFinished: root.parseWeather(text)
        }
        onExited: function(exitCode) {
            if (root.loading && exitCode !== 0) {
                root.loading = false
                root.ok = false
                root.errorText = "Weather unavailable"
            }
        }
    }

    Item {
        id: focusSink
        anchors.fill: parent
        focus: root.active
        Keys.enabled: root.active
        Keys.onEscapePressed: if (panel) panel.dismiss()

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            // Current conditions
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.location
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: Theme.fontBold
                    opacity: 0.7
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: root.current ? String(root.current.icon || "󰖐") : "󰖐"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 42
                        font.bold: Theme.fontBold
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: root.loading ? "…" : (root.current ? (String(root.current.temp) + "°") : "—")
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 32
                            font.bold: Theme.fontBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.loading ? "Loading…" : (root.ok && root.current ? String(root.current.label || "") : (root.errorText || "Unavailable"))
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            opacity: 0.75
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Today / tomorrow
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: root.daily.length > 0

                Repeater {
                    model: root.daily

                    Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: String(modelData.dow || "")
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: Theme.fontBold
                                opacity: 0.65
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: String(modelData.icon || "󰖐")
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: String(modelData.min) + "–" + String(modelData.max) + "°"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: Theme.fontBold
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(modelData.label || "")
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                opacity: 0.6
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            FramedPanel {
                label: "Hourly"
                contentFill: true
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 14

                ListView {
                    id: hourlyView
                    anchors.fill: parent
                    clip: true
                    model: root.hourly
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 2

                    delegate: Item {
                        required property var modelData
                        width: ListView.view.width
                        height: 28

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                Layout.preferredWidth: 42
                                text: String(modelData.time || "")
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                opacity: 0.7
                            }

                            Text {
                                Layout.preferredWidth: 22
                                text: String(modelData.icon || "󰖐")
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                            }

                            Text {
                                Layout.preferredWidth: 36
                                text: String(modelData.temp) + "°"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: Theme.fontBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(modelData.label || "")
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                opacity: 0.75
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: typeof modelData.precip === "number" && modelData.precip > 0
                                text: String(modelData.precip) + "%"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                opacity: 0.55
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.loading && hourlyView.count === 0
                    text: root.errorText || "No hourly data"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    opacity: 0.5
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                Text {
                    id: metLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Met Office"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    opacity: metMouse.containsMouse ? 1 : 0.75
                }

                MouseArea {
                    id: metMouse
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: metLabel.width
                    height: parent.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openMetOffice()
                }
            }
        }
    }
}
