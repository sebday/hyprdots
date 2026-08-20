import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string value: "0"
    property int deltaPct: 0
    property bool trendUp: true
    property bool peak: false
    property string topName: ""
    property int topCount: 0
    property color tintColor: Theme.panelMantle
    property bool clickable: false

    property bool allTime: false

    signal clicked()

    readonly property string trendLabel: {
        if (root.allTime)
            return "all time"
        if (root.deltaPct === 0 && String(root.value) === "0")
            return "—"
        return (root.trendUp ? "^ " : "↓ ") + Math.abs(root.deltaPct) + "%"
    }

    Layout.fillWidth: true
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    SectionPanel {
        id: panel
        anchors.fill: parent
        label: ""
        filled: true
        fillColor: root.tintColor
        contentPad: Theme.spacingS

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Text {
                    Layout.fillWidth: true
                    text: root.label
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    opacity: Theme.opacityMuted
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: root.peak
                    radius: 3
                    color: Theme.withOpacity(Theme.foreground, 0.12)
                    implicitWidth: peakLabel.implicitWidth + 8
                    implicitHeight: peakLabel.implicitHeight + 4

                    Text {
                        id: peakLabel
                        anchors.centerIn: parent
                        text: "PEAK"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: Theme.fontBold
                        opacity: 0.72
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Text {
                    text: root.value
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize5xl
                    font.bold: Theme.fontBold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.trendLabel
                    color: root.trendUp ? Theme.accent : Theme.urgent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    font.bold: Theme.fontBold
                    opacity: 0.88
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.foregroundDivider
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS
                visible: root.topName !== ""

                Text {
                    text: "#1"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    font.bold: Theme.fontBold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.topName
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    elide: Text.ElideRight
                    opacity: 0.9
                }

                Text {
                    visible: root.topCount > 0
                    text: root.topCount + " scrobbles"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    opacity: Theme.opacityDisabled
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
