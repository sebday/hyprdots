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
    property bool filled: false
    property color fillColor: Theme.panelMantle
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
    readonly property int verticalChrome: scaledPad * 2 + labelRowHeight
    readonly property int frameHeight: contentHeight + verticalChrome

    implicitWidth: root.contentFill
        ? (parent ? parent.width : contentWidth + scaledPad * 2)
        : Math.max(contentWidth + scaledPad * 2,
                   hasLabel ? frameLabel.implicitWidth + scaledPad * 2 : 0)
    implicitHeight: root.contentFill ? Math.max(frameHeight, 32) : frameHeight

    Item {
        id: frameBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: root.contentFill ? parent.bottom : undefined
        height: root.contentFill ? undefined : root.frameHeight

        Rectangle {
            anchors.fill: parent
            color: root.filled ? root.fillColor : "transparent"
            border.color: root.filled ? "transparent" : root.frameBorder
            border.width: root.filled ? 0 : 1
            radius: root.cornerRadius
        }

        ColumnLayout {
            id: frameColumn
            anchors.fill: parent
            anchors.margins: root.scaledPad
            spacing: root.labelGap

            Text {
                id: frameLabel
                visible: root.hasLabel
                Layout.fillWidth: true
                horizontalAlignment: root.labelAlign === "center"
                    ? Text.AlignHCenter
                    : Text.AlignLeft
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelProminent
                    ? Math.max(8, root.labelFontSize - 1)
                    : Math.max(8, root.labelFontSize - 2)
                font.bold: Theme.fontBold
                opacity: root.labelOpacity
            }

            Item {
                id: contentHost
                Layout.fillWidth: true
                Layout.fillHeight: root.contentFill
                implicitHeight: root.contentFill ? 0 : root.contentHeight
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
