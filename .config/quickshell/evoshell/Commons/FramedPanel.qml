import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property int contentPad: 10
    property color frameBorder: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    property bool contentFill: false
    property int labelFontSize: Theme.panelSmallFontPixelSize
    property color labelBackground: Theme.mantle
    property int labelPadH: 6

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property int cornerRadius: Theme.fieldsetCornerRadius
    readonly property int scaledPad: contentPad
    readonly property int contentWidth: Math.max(contentHost.childrenRect.width, 1)
    readonly property int contentHeight: Math.max(contentHost.childrenRect.height, 1)
    readonly property int labelHeight: hasLabel ? frameLabel.implicitHeight : 0
    readonly property int labelOverlap: hasLabel ? Math.ceil(labelHeight / 2) : 0
    readonly property int frameHeight: contentHeight + scaledPad * 2 + labelOverlap

    implicitWidth: root.contentFill
        ? (parent ? parent.width : contentWidth + scaledPad * 2)
        : Math.max(hasLabel ? frameLabel.implicitWidth + labelPadH * 2 + scaledPad * 2 : 0,
                   contentWidth + scaledPad * 2)
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

        Item {
            id: labelChip
            visible: root.hasLabel
            x: root.scaledPad
            y: -root.labelOverlap
            height: root.labelHeight
            width: frameLabel.implicitWidth + root.labelPadH * 2
            z: 1

            Rectangle {
                anchors.fill: parent
                color: root.labelBackground
            }

            Text {
                id: frameLabel
                anchors.centerIn: parent
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, root.labelFontSize - 1)
                font.bold: Theme.fontBold
                opacity: 0.72
            }
        }

        Item {
            id: contentHost
            x: root.scaledPad
            y: root.scaledPad + root.labelOverlap
            width: root.contentFill
                ? Math.max(1, frameBox.width - root.scaledPad * 2)
                : root.contentWidth
            height: root.contentHeight
        }
    }
}
