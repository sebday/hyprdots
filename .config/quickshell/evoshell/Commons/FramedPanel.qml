import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string labelAlign: "left"
    property int contentPad: 10
    property color frameBorder: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    property bool contentFill: false
    property int labelFontSize: Theme.panelSmallFontPixelSize
    property color labelBackground: Theme.mantle
    property int labelPadH: 6
    property real labelOpacity: 0.72
    property bool labelProminent: false
    property bool labelClickable: false
    property int labelGap: 8

    signal labelClicked()

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property int cornerRadius: Theme.fieldsetCornerRadius
    readonly property int scaledPad: contentPad
    readonly property int contentWidth: Math.max(contentHost.childrenRect.width, 1)
    readonly property int contentHeight: Math.max(contentHost.childrenRect.height, 1)
    readonly property int labelRowHeight: hasLabel ? frameLabel.implicitHeight + labelGap : 0
    readonly property int frameHeight: contentHeight + scaledPad * 2 + labelRowHeight

    implicitWidth: root.contentFill
        ? (parent ? parent.width : contentWidth + scaledPad * 2)
        : Math.max(contentWidth + scaledPad * 2,
                   hasLabel ? frameLabel.implicitWidth + scaledPad * 2 : 0)
    implicitHeight: frameHeight

    Item {
        id: frameBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.frameHeight

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: root.frameBorder
            border.width: 1
            radius: root.cornerRadius
        }

        Column {
            id: frameColumn
            x: root.scaledPad
            y: root.scaledPad
            width: root.contentFill
                ? Math.max(1, frameBox.width - root.scaledPad * 2)
                : root.contentWidth
            spacing: root.labelGap

            Text {
                id: frameLabel
                visible: root.hasLabel
                width: parent.width
                horizontalAlignment: root.labelAlign === "center"
                    ? Text.AlignHCenter
                    : Text.AlignLeft
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelProminent
                    ? root.labelFontSize
                    : Math.max(8, root.labelFontSize - 1)
                font.bold: Theme.fontBold
                opacity: root.labelOpacity
            }

            Item {
                id: contentHost
                width: parent.width
                height: root.contentHeight
            }
        }

        MouseArea {
            anchors.left: frameColumn.left
            anchors.right: frameColumn.right
            anchors.top: frameColumn.top
            height: frameLabel.visible ? frameLabel.implicitHeight : 0
            visible: root.labelClickable && frameLabel.visible
            cursorShape: Qt.PointingHandCursor
            onClicked: root.labelClicked()
        }
    }
}
