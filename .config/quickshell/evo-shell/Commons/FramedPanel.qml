import QtQuick

Item {
    id: root

    property string label: ""
    property int contentPad: 10
    property int cornerRadius: 4
    property color frameBorder: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    property color veilColor: Theme.panelVeil
    property int legendPadH: 0
    property int legendPadV: 0
    property bool contentFill: false

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property int labelTopOffset: hasLabel
        ? -Math.round(frameLabel.implicitHeight / 2)
        : 0
    readonly property int headerPad: hasLabel
        ? Math.round(frameLabel.implicitHeight / 2) + 4
        : 0
    readonly property int balancedBottomPad: hasLabel ? headerPad : 0

    implicitWidth: 200
    implicitHeight: contentFill
        ? (contentPad * 2 + headerPad + balancedBottomPad)
        : (contentPad * 2 + headerPad + balancedBottomPad + contentHost.childrenRect.height)

    Rectangle {
        z: 0
        anchors.fill: parent
        color: "transparent"
        border.color: root.frameBorder
        border.width: 1
        radius: root.cornerRadius
    }

    Text {
        id: frameLabel
        z: 2
        visible: root.hasLabel
        x: root.contentPad
        y: root.labelTopOffset
        text: root.label
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelSmallFontPixelSize
        font.bold: Theme.fontBold
        opacity: 0.72
    }

    // Label backdrop — exact text bounds by default so it does not cover rounded corners.
    Rectangle {
        z: 1
        visible: root.hasLabel
        x: frameLabel.x - root.legendPadH
        y: frameLabel.y - root.legendPadV
        width: frameLabel.implicitWidth + root.legendPadH * 2
        height: frameLabel.implicitHeight + root.legendPadV * 2
        color: root.veilColor
    }

    Item {
        id: contentHost
        z: 0
        clip: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: root.contentFill ? parent.bottom : undefined
        anchors.leftMargin: contentPad
        anchors.rightMargin: contentPad
        anchors.topMargin: contentPad + headerPad
        anchors.bottomMargin: root.contentFill ? (contentPad + balancedBottomPad) : 0
        height: root.contentFill ? undefined : childrenRect.height
    }
}
