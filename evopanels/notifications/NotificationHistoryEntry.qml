import QtQuick
import QtQuick.Layouts
import "../../commons"
import "."

Item {
    id: root

    required property var entry
    property var host: null
    property bool showUnhide: false
    property bool showDivider: true

    signal removeRequested(var entry)
    signal openRequested(var entry)
    signal hideRequested(var entry)
    signal unhideRequested(var entry)

    readonly property var notifService: host && host.notifService ? host.notifService : null

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 16 + (showDivider ? 1 : 0)

    function markRead() {
        if (!notifService || !entry || entry.read === true)
            return
        if (typeof notifService.markEntryRead === "function")
            notifService.markEntryRead(entry.key)
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: Theme.spacingM

        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter

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

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: String(entry.title || "Notification")
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: host ? host.titleFont : Theme.fontSizeM
            font.bold: Theme.fontBold
            elide: Text.ElideRight
            maximumLineCount: 1
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
        z: -1
        cursorShape: entry.openUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.markRead()
            root.openRequested(entry)
        }
    }
}
