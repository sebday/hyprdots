import QtQuick

Item {
    id: root

    property string label: ""
    property int contentPad: 10
    property int cornerRadius: 4
    property color frameBorder: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    property color veilColor: Theme.panelBackground
    property int labelTopOffset: -7
    property int contentTopExtra: 10
    property bool contentFill: false

    default property alias content: contentHost.data

    readonly property int headerPad: label !== "" ? contentTopExtra : 0
    implicitHeight: contentFill
        ? (contentPad * 2 + headerPad)
        : (contentPad * 2 + headerPad + contentHost.childrenRect.height)
    implicitWidth: 200

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.frameBorder
        border.width: 1
        radius: root.cornerRadius
    }

    Rectangle {
        visible: root.label !== ""
        x: root.contentPad - 2
        y: root.labelTopOffset
        width: frameLabel.width + 10
        height: frameLabel.implicitHeight
        color: root.veilColor

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
        clip: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: root.contentFill ? parent.bottom : undefined
        anchors.leftMargin: contentPad
        anchors.rightMargin: contentPad
        anchors.topMargin: contentPad + headerPad
        anchors.bottomMargin: root.contentFill ? contentPad : 0
        height: root.contentFill ? undefined : childrenRect.height
    }
}
