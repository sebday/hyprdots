import QtQuick

Item {
    id: root

    property string text: ""
    property int fontSize: Theme.fontSizeXs
    property color textColor: Theme.foreground
    property color fill: Theme.withOpacity(Theme.foreground, 0.08)
    property real textOpacity: 0.72
    property bool alignCenter: false
    property bool fieldsetLegend: true
    property color fieldsetFill: Theme.mantle

    visible: root.text !== ""
    width: implicitWidth
    height: implicitHeight
    implicitWidth: root.alignCenter && parent && parent.width > 0
        ? parent.width
        : pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Rectangle {
        id: pill
        anchors.left: root.alignCenter ? undefined : parent.left
        anchors.horizontalCenter: root.alignCenter ? parent.horizontalCenter : undefined
        radius: height / 2
        color: root.fieldsetLegend ? root.fieldsetFill : root.fill
        implicitWidth: labelText.implicitWidth + 12
        implicitHeight: labelText.implicitHeight + (root.fieldsetLegend ? 8 : 6)
        width: implicitWidth
        height: implicitHeight

        Text {
            id: labelText
            anchors.centerIn: parent
            text: root.text
            color: root.textColor
            opacity: root.textOpacity
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
            font.bold: Theme.fontBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
