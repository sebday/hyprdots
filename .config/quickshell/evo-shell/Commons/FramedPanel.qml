import QtQuick

Item {
    id: root

    property string label: ""
    property int contentPad: 10
    property int cornerRadius: Theme.panelCornerRadius
    property color frameBorder: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    property int legendPadH: 0
    property int legendPadV: 0
    property bool contentFill: false

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property int scaledPad: contentPad
    readonly property int labelTopOffset: hasLabel
        ? -Math.round(frameLabel.implicitHeight / 2)
        : 0
    readonly property int headerPad: hasLabel
        ? Math.round(frameLabel.implicitHeight / 2) + 4
        : 0
    readonly property int balancedBottomPad: hasLabel ? headerPad : 0
    readonly property int labelGapLeft: hasLabel
        ? Math.max(0, frameLabel.x - legendPadH)
        : 0
    readonly property int labelGapRight: hasLabel
        ? Math.min(width, frameLabel.x + frameLabel.width + legendPadH)
        : 0
    readonly property int verticalChrome: scaledPad * 2 + headerPad
        + (contentFill ? balancedBottomPad : 0)

    implicitWidth: 200
    implicitHeight: contentFill
        ? (scaledPad * 2 + headerPad + balancedBottomPad)
        : (scaledPad * 2 + headerPad + balancedBottomPad + contentHost.childrenRect.height)

    Rectangle {
        visible: !root.hasLabel
        z: 0
        anchors.fill: parent
        color: "transparent"
        border.color: root.frameBorder
        border.width: 1
        radius: root.cornerRadius
    }

    Rectangle {
        visible: root.hasLabel && root.cornerRadius > 0
        z: 0
        anchors.fill: parent
        color: "transparent"
        border.color: root.frameBorder
        border.width: 1
        radius: root.cornerRadius
    }

    // Square fieldsets: gap the top border so the label sits on the panel bg (no veil).
    Item {
        visible: root.hasLabel && root.cornerRadius === 0
        z: 0
        anchors.fill: parent

        Rectangle {
            x: 0
            y: 0
            width: root.labelGapLeft
            height: 1
            color: root.frameBorder
        }

        Rectangle {
            y: 0
            width: Math.max(0, parent.width - root.labelGapRight)
            height: 1
            anchors.right: parent.right
            color: root.frameBorder
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.frameBorder
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: root.frameBorder
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: root.frameBorder
        }
    }

    Text {
        id: frameLabel
        z: 2
        visible: root.hasLabel
        x: root.scaledPad
        y: root.labelTopOffset
        text: root.label
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelSmallFontPixelSize
        font.bold: Theme.fontBold
        opacity: 0.72
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
