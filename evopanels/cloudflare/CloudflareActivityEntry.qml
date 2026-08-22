import QtQuick
import QtQuick.Layouts
import "../../commons"
import "../notifications"

Item {
    id: root

    required property var row
    property var host: null
    property bool showDivider: true

    Layout.fillWidth: true
    implicitHeight: entryRow.implicitHeight + 16 + (showDivider ? 1 : 0)

    readonly property string glyph: host ? host.rowGlyph(row) : ""
    readonly property string titleText: host ? host.rowTitle(row) : ""
    readonly property string statusText: host ? host.activityStatusLabel(row) : ""
    readonly property string timeText: host ? host.activityTimeLabel(row) : ""
    readonly property color statusColor: host ? host.activityStatusColor(row) : Theme.accent
    readonly property bool clickable: host ? host.rowClickable(row) : false

    RowLayout {
        id: entryRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: Theme.spacingM

        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            visible: root.glyph !== ""

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusM
                color: Qt.rgba(
                    root.statusColor.r,
                    root.statusColor.g,
                    root.statusColor.b,
                    0.14
                )
            }

            Text {
                anchors.centerIn: parent
                text: root.glyph
                color: root.statusColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
                font.bold: Theme.fontBold
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.titleText
            color: row && row.alarming ? Theme.urgent : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: host ? host.rowTitleFont : Theme.fontSizeM
            font.bold: Theme.fontBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        NotificationMetaPill {
            Layout.alignment: Qt.AlignVCenter
            visible: root.statusText !== ""
            text: root.statusText
            active: true
            activeFill: Qt.rgba(
                root.statusColor.r,
                root.statusColor.g,
                root.statusColor.b,
                0.16
            )
            activeText: root.statusColor
            fontSize: Theme.fontSizeS
        }

        NotificationMetaPill {
            Layout.alignment: Qt.AlignVCenter
            visible: root.timeText !== ""
            text: root.timeText
            active: false
            inactiveFill: Theme.foregroundGhost
            inactiveText: Theme.foreground
            inactiveOpacity: Theme.opacityMuted
            fontSize: Theme.fontSizeS
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: showDivider
        height: 1
        color: Theme.foregroundDivider
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (host)
                host.openRow(row)
        }
    }
}
