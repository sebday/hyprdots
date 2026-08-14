import QtQuick

Item {
    id: root

    property string label: ""
    property int contentPad: 10
    property color frameBorder: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    property color labelBackground: Theme.mantle
    property bool contentFill: false

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property int cornerRadius: 4
    readonly property int scaledPad: contentPad
    readonly property int labelTopOffset: hasLabel
        ? -Math.round(frameLabel.implicitHeight / 2)
        : 0
    readonly property int headerPad: hasLabel
        ? Math.round(frameLabel.implicitHeight / 2) + 4
        : 0
    readonly property int balancedBottomPad: hasLabel ? headerPad : 0
    readonly property int verticalChrome: scaledPad * 2 + headerPad
        + (contentFill ? balancedBottomPad : 0)

    implicitWidth: 200
    implicitHeight: contentFill
        ? (scaledPad * 2 + headerPad + balancedBottomPad)
        : (scaledPad * 2 + headerPad + balancedBottomPad + contentHost.childrenRect.height)

    Rectangle {
        z: 0
        anchors.fill: parent
        color: "transparent"
        border.color: root.frameBorder
        border.width: 1
        radius: root.cornerRadius
    }

    Item {
        id: labelHost
        z: 2
        visible: root.hasLabel
        x: root.scaledPad - labelPadH
        y: root.labelTopOffset
        width: frameLabel.implicitWidth + labelPadH * 2
        height: frameLabel.implicitHeight

        readonly property int labelPadH: 4

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
            font.pixelSize: Theme.panelSmallFontPixelSize
            font.bold: Theme.fontBold
            opacity: 0.72
        }
    }

    Item {
        id: contentHost
        z: 1
        clip: false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: root.contentFill ? parent.bottom : undefined
        anchors.leftMargin: scaledPad
        anchors.rightMargin: scaledPad
        anchors.topMargin: scaledPad + headerPad
        anchors.bottomMargin: scaledPad + (root.contentFill ? balancedBottomPad : 0)
        height: root.contentFill ? undefined : childrenRect.height
    }
}
