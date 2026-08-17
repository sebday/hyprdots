import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string value: ""
    property string href: ""
    property string iconUrl: ""
    property string iconFallback: ""
    property int iconSize: 0
    property int titleFont: Theme.fontSize2xl
    property int detailFont: Theme.fontSizeL

    Layout.fillWidth: true
    implicitHeight: headerRow.implicitHeight
    implicitWidth: headerRow.implicitWidth

    readonly property bool hasIcon: root.iconUrl !== "" || root.iconFallback !== ""

    readonly property int textBlockHeight: {
        var h = titleText.implicitHeight
        if (secondaryText.visible && secondaryText.text !== "")
            h += headerCol.spacing + secondaryText.implicitHeight
        return h
    }

    readonly property int resolvedIconSize: {
        if (!hasIcon)
            return 0
        if (iconSize > 0)
            return iconSize
        return Math.max(1, textBlockHeight)
    }

    readonly property string primary: {
        var parts = String(root.value).split("\n")
        return parts[0] || ""
    }

    readonly property string secondary: {
        var parts = String(root.value).split("\n")
        return parts.slice(1).join("\n")
    }

    function openUrl(url) {
        if (!url)
            return
        Quickshell.execDetached(["bash", "-lc", "xdg-open " + Util.shellQuote(url)])
    }

    RowLayout {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Item {
            Layout.preferredWidth: root.resolvedIconSize
            Layout.preferredHeight: root.resolvedIconSize
            Layout.maximumWidth: root.resolvedIconSize
            Layout.maximumHeight: root.resolvedIconSize
            Layout.alignment: Qt.AlignVCenter
            visible: root.hasIcon
            clip: true

            Text {
                anchors.fill: parent
                visible: !root.iconUrl || favicon.status !== Image.Ready
                text: root.iconFallback
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(root.titleFont, Math.round(root.resolvedIconSize * 0.82))
                font.bold: Theme.fontBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: 0.9
            }

            Image {
                id: favicon
                anchors.fill: parent
                visible: root.iconUrl !== "" && status === Image.Ready
                source: root.iconUrl
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(root.resolvedIconSize * 2, root.resolvedIconSize * 2)
            }
        }

        ColumnLayout {
            id: headerCol
            Layout.fillWidth: true
            spacing: 6

            Text {
                id: titleText
                Layout.fillWidth: true
                text: root.primary
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.titleFont
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                id: secondaryText
                Layout.fillWidth: true
                visible: root.secondary !== ""
                text: root.secondary
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.detailFont
                font.bold: Theme.fontBold
                opacity: 0.72
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: root.href !== ""
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openUrl(root.href)
    }
}
