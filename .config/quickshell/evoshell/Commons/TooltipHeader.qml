import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string value: ""
    property string href: ""
    property string iconUrl: ""
    property string iconFallback: ""
    property int iconSize: 32
    property int titleFont: Theme.tooltipTitleFontPixelSize
    property int detailFont: Theme.tooltipLabelFontPixelSize

    Layout.fillWidth: true
    implicitHeight: headerRow.implicitHeight
    implicitWidth: headerRow.implicitWidth

    readonly property bool hasIcon: root.iconUrl !== "" || root.iconFallback !== ""

    readonly property string primary: {
        var parts = String(root.value).split("\n")
        return parts[0] || ""
    }

    readonly property string secondary: {
        var parts = String(root.value).split("\n")
        return parts.slice(1).join(" · ")
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
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            Layout.maximumWidth: root.iconSize
            Layout.maximumHeight: root.iconSize
            Layout.alignment: Qt.AlignTop
            visible: root.hasIcon
            clip: true

            Text {
                anchors.centerIn: parent
                visible: !root.iconUrl || favicon.status !== Image.Ready
                text: root.iconFallback
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.titleFont
                font.bold: Theme.fontBold
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
                sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
            }
        }

        ColumnLayout {
            id: headerCol
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.primary
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.titleFont
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
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
