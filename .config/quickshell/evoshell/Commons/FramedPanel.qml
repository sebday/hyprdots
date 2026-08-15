import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property int contentPad: 10
    property color frameBorder: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.32)
    property bool contentFill: false

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property int cornerRadius: 4
    readonly property int scaledPad: contentPad
    readonly property int labelGap: hasLabel ? 6 : 0

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        anchors.fill: root.contentFill ? parent : undefined
        width: root.contentFill ? undefined : parent.width
        spacing: root.labelGap

        Text {
            id: frameLabel
            visible: root.hasLabel
            Layout.fillWidth: true
            text: root.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelSmallFontPixelSize
            font.bold: Theme.fontBold
            opacity: 0.72
        }

        Item {
            id: frameBox
            Layout.fillWidth: true
            Layout.fillHeight: root.contentFill
            Layout.preferredHeight: root.contentFill
                ? -1
                : contentHost.childrenRect.height + root.scaledPad * 2

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: root.frameBorder
                border.width: 1
                radius: root.cornerRadius
            }

            Item {
                id: contentHost
                anchors.fill: parent
                anchors.margins: root.scaledPad
            }
        }
    }
}
