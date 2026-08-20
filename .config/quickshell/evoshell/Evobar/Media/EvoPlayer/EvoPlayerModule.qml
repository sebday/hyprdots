import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property bool contentReady: true
    readonly property string playerScript: (Quickshell.env("HOME") || "") + "/.local/bin/evo-player"
    readonly property var playerMonitor: shell ? shell.serviceFor("evo.panel.player.monitor") : null
    readonly property var player: playerMonitor && playerMonitor.player ? playerMonitor.player : ({})
    readonly property bool hasTrack: String(player.path || "") !== ""
    readonly property bool isPlaying: String(player.state || "") === "playing"
    readonly property real trackProgress: {
        var dur = Number(player.duration) || 0
        if (dur <= 0)
            return 0
        return Math.max(0, Math.min(1, Number(player.position) || 0) / dur)
    }
    readonly property string artUrl: {
        var art = String(player.art || "")
        return art ? Util.fileUrl(art) : ""
    }

    function openDashboard() {
        if (!shell)
            return
        shell.summon("evo.panel.player", "")
    }

    function stopPlayback() {
        Quickshell.execDetached(["bash", playerScript, "stop"])
    }

    function togglePlayback() {
        Quickshell.execDetached(["bash", playerScript, "toggle"])
    }

    function skip(forward) {
        Quickshell.execDetached(["bash", playerScript, forward ? "next" : "prev"])
    }

    function nudgeVolume(delta) {
        Quickshell.execDetached(["bash", playerScript, "volume", String(delta)])
    }

    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: ""
            visible: root.hasTrack

            HoverPopupLabelPill {
                text: "Evoplayer"
                icon: "󰎈"
                fontSize: Theme.fontSizeS
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.fieldsetCornerRadius
                        color: Theme.foregroundFaint
                        visible: root.artUrl === ""
                    }

                    Image {
                        anchors.fill: parent
                        visible: root.artUrl !== ""
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing2

                    Text {
                        Layout.fillWidth: true
                        text: String(player.title || "Unknown track")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize2xl
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: String(player.artist || "") !== ""
                        text: String(player.artist || "")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeL
                        opacity: 0.82
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: String(player.position_label || "0:00")
                            + " / "
                            + String(player.duration_label || "0:00")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeL
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: 2
                color: Theme.foregroundFaint

                Rectangle {
                    width: parent.width * root.trackProgress
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Text {
                    text: "󰒮"
                    color: Theme.foreground
                    opacity: 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize4xl
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.skip(false)
                    }
                }
                Text {
                    text: root.isPlaying ? "󰏤" : "󰐊"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize6xl
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlayback()
                    }
                }
                Text {
                    text: "󰒭"
                    color: Theme.foreground
                    opacity: 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize4xl
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.skip(true)
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "󰍉"
                    color: Theme.foreground
                    opacity: 0.75
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize4xl
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openDashboard()
                    }
                }
                Text {
                    text: "󰓛"
                    color: Theme.urgent
                    opacity: 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize4xl
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopPlayback()
                    }
                }
            }
        }

        SectionPanel {
            label: ""
            visible: !root.hasTrack

            Text {
                text: "No track playing"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeL
                opacity: 0.7
            }

            Text {
                text: "Open Evoplayer"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeL

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDashboard()
                }
            }
        }
    }
}
