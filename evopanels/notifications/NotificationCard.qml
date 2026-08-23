import QtQuick
import "../../commons"
import "."

Item {
    id: root

    property string coverArt: ""
    property int artRev: 0
    property string fallbackIcon: "󰎆"
    property var fields: ({})
    property int artSize: Theme.notificationArtSize
    property int imageFillMode: Image.PreserveAspectCrop

    signal artError(string source)
    signal artReady(string source)

    readonly property string artSource: {
        if (!root.coverArt)
            return ""
        if (root.coverArt.indexOf("data:image/") === 0)
            return root.coverArt
        var base = Util.fileUrl(root.coverArt)
        if (!root.artRev)
            return base
        var sep = base.indexOf("?") >= 0 ? "&" : "?"
        return base + sep + "rev=" + root.artRev
    }

    readonly property bool showHeart: root.fields.showHeart
    readonly property int heartSize: Math.round(root.artSize * 0.62)
    readonly property int heartReserve: root.showHeart ? heartSize + 8 : 0

    width: Theme.notificationWidth
    implicitHeight: innerRow.height + Theme.notificationMediaPad * 2

    Row {
        id: innerRow
        x: Theme.notificationPadding
        y: Theme.notificationMediaPad
        width: parent.width - Theme.notificationPadding * 2
        height: Math.max(root.artSize, textCol.height)
        spacing: 16

        Item {
            width: root.artSize
            height: root.artSize
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                radius: Theme.panelCornerRadius
            }

            Text {
                anchors.centerIn: parent
                visible: root.artSource === "" || artImage.status !== Image.Ready
                text: root.fallbackIcon
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(root.artSize * 0.45)
                font.bold: Theme.fontBold
            }

            Image {
                id: artImage
                anchors.fill: parent
                visible: root.artSource !== "" && status === Image.Ready
                source: root.artSource
                fillMode: root.imageFillMode
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
                sourceSize: Qt.size(root.artSize, root.artSize)
                onStatusChanged: {
                    if (status === Image.Error)
                        root.artError(root.artSource)
                    else if (status === Image.Ready)
                        root.artReady(root.artSource)
                }
            }
        }

        Column {
            id: textCol
            width: parent.width - root.artSize - parent.spacing - root.heartReserve
                - (root.heartReserve > 0 ? parent.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            Text {
                width: parent.width
                visible: root.fields.kicker !== undefined && root.fields.kicker !== ""
                text: root.fields.kicker || ""
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize4xl
                font.bold: Theme.fontBold
                font.letterSpacing: 1
                elide: Text.ElideRight
                maximumLineCount: 1
                opacity: Theme.opacityEmphasis
            }

            Text {
                width: parent.width
                text: root.fields.title || ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize2xl
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                visible: root.fields.subtitle !== undefined && root.fields.subtitle !== ""
                text: root.fields.subtitle || ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.fields.subtitleFontSize !== undefined
                    ? root.fields.subtitleFontSize
                    : Theme.fontSizeL
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                opacity: root.fields.subtitleOpacity !== undefined
                    ? root.fields.subtitleOpacity
                    : 0.82
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS
                visible: String(root.fields.genre || "").trim() !== ""
                    || String(root.fields.year || "").trim() !== ""

                NotificationMetaPill {
                    text: String(root.fields.genre || "").trim()
                    active: true
                    activeFill: Theme.withOpacity(Theme.accent, 0.18)
                    activeText: Theme.accent
                    fontSize: Theme.fontSizeS
                }

                NotificationMetaPill {
                    text: String(root.fields.year || "").trim()
                    active: false
                    inactiveFill: Theme.foregroundGhost
                    inactiveText: Theme.foreground
                    inactiveOpacity: Theme.opacityMuted
                    fontSize: Theme.fontSizeS
                }
            }

            Text {
                width: parent.width
                visible: root.fields.footer !== undefined && root.fields.footer !== ""
                text: root.fields.footer || ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize4xl
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                maximumLineCount: 1
                opacity: Theme.opacityMuted
            }
        }

        Item {
            width: root.heartReserve
            height: parent.height
            visible: root.showHeart

            Text {
                anchors.centerIn: parent
                text: "󰋑"
                color: root.fields.liked ? Theme.urgent : Theme.foreground
                opacity: root.fields.liked ? 1 : 0.28
                font.family: Theme.fontFamily
                font.pixelSize: root.heartSize
                font.bold: Theme.fontBold
            }
        }
    }
}
