import QtQuick
import QtQuick.Layouts
import "../../../Commons"
import "."

Rectangle {
    id: root

    required property var entry
    property var host: null
    property bool showUnhide: false

    signal removeRequested(var entry)
    signal openRequested(var entry)
    signal hideRequested(var entry)
    signal unhideRequested(var entry)

    readonly property var notifService: host && host.notifService ? host.notifService : null

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 16
    radius: Theme.fieldsetCornerRadius
    color: entry.read === true
        ? Theme.foregroundGhost
        : Theme.withOpacity(Theme.accent, 0.08)
    border.width: 1
    border.color: entry.read === true
        ? Theme.foregroundDivider
        : Theme.withOpacity(Theme.accent, 0.28)

    function markRead() {
        if (!notifService || !entry || entry.read === true)
            return
        if (typeof notifService.markEntryRead === "function")
            notifService.markEntryRead(entry.key)
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 8
        spacing: Theme.spacingM

        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignTop

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusM
                color: Theme.withOpacity(Theme.accent, 0.12)
            }

            Image {
                id: entryArt
                anchors.fill: parent
                anchors.margins: 2
                visible: host && host.entryArtSource(entry) !== "" && status === Image.Ready
                source: host ? host.entryArtSource(entry) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
            }

            Text {
                anchors.centerIn: parent
                visible: !host || host.entryArtSource(entry) === "" || entryArt.status !== Image.Ready
                text: host ? host.sourceIcon(entry.source) : "󰂚"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
                font.bold: Theme.fontBold
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: String(entry.title || "Notification")
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: host ? host.titleFont : Theme.fontSizeXl
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true
                visible: String(entry.body || "") !== ""
                text: String(entry.body || "")
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: host ? host.bodyFont : Theme.fontSizeM
                font.bold: Theme.fontBold
                opacity: Theme.opacitySecondary
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        NotificationMetaPill {
            Layout.alignment: Qt.AlignVCenter
            text: host ? host.sourceLabel(entry.source) : String(entry.source || "System")
            active: true
            activeFill: Theme.withOpacity(Theme.accent, 0.12)
            activeText: Theme.accent
            fontSize: Theme.fontSizeS
        }

        NotificationMetaPill {
            Layout.alignment: Qt.AlignVCenter
            text: host ? host.formatTime(entry.at) : ""
            active: false
            inactiveFill: Theme.foregroundGhost
            inactiveText: Theme.foreground
            inactiveOpacity: Theme.opacityMuted
            fontSize: Theme.fontSizeS
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.showUnhide ? "󰈈" : "󰈉"
            color: Theme.foreground
            opacity: Theme.opacityMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.bold: Theme.fontBold

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.showUnhide)
                        root.unhideRequested(entry)
                    else
                        root.hideRequested(entry)
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "󰅖"
            color: Theme.foreground
            opacity: Theme.opacityMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.bold: Theme.fontBold

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeRequested(entry)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: entry.openUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.markRead()
            root.openRequested(entry)
        }
    }
}
