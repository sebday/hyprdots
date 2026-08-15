import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property int contentPad: 10
    property color frameBorder: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    property bool contentFill: false

    property int labelFontSize: Theme.panelSmallFontPixelSize

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property int cornerRadius: Theme.fieldsetCornerRadius
    readonly property int scaledPad: contentPad
    readonly property int labelGap: hasLabel ? 6 : 0
    readonly property int contentWidth: Math.max(contentHost.childrenRect.width, 1)
    readonly property int contentHeight: Math.max(contentHost.childrenRect.height, 1)

    implicitWidth: root.contentFill
        ? (parent ? parent.width : column.implicitWidth)
        : Math.max(frameLabel.implicitWidth, contentWidth + scaledPad * 2)
    implicitHeight: (hasLabel ? frameLabel.implicitHeight + labelGap : 0)
        + contentHeight + scaledPad * 2

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        width: root.contentFill && parent ? parent.width : undefined
        spacing: root.labelGap

        Text {
            id: frameLabel
            visible: root.hasLabel
            Layout.fillWidth: true
            text: root.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.labelFontSize
            font.bold: Theme.fontBold
            opacity: 0.72
        }

        Item {
            id: frameBox
            Layout.fillWidth: true
            Layout.preferredWidth: root.contentFill ? -1 : root.contentWidth + root.scaledPad * 2
            Layout.minimumWidth: root.contentFill ? 0 : root.contentWidth + root.scaledPad * 2
            Layout.preferredHeight: root.contentHeight + root.scaledPad * 2
            Layout.minimumHeight: root.contentHeight + root.scaledPad * 2
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: root.frameBorder
                border.width: 1
                radius: root.cornerRadius
            }

            Item {
                id: contentHost
                x: root.scaledPad
                y: root.scaledPad
                width: root.contentFill
                    ? Math.max(1, frameBox.width - root.scaledPad * 2)
                    : root.contentWidth
                height: root.contentHeight
            }
        }
    }
}
