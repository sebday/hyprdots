import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string value: ""
    property string label: ""
    property color valueColor: Theme.accent
    property int valueFontSize: Theme.fontSize5xl
    property int labelFontSize: Theme.fontSizeXs
    property color labelPillFill: Theme.withOpacity(Theme.foreground, 0.08)
    property int contentPad: 10
    property bool clickable: false

    signal clicked()

    Layout.fillWidth: true
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    SectionPanel {
        id: panel
        anchors.fill: parent
        label: ""
        filled: true
        contentPad: root.contentPad

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.value
                color: root.valueColor
                font.family: Theme.fontFamily
                font.pixelSize: root.valueFontSize
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Item {
                Layout.fillWidth: true
                visible: root.label !== ""
                implicitHeight: labelPill.implicitHeight

                HoverPopupLabelPill {
                    id: labelPill
                    width: parent.width
                    alignCenter: true
                    text: root.label
                    fontSize: root.labelFontSize
                    fill: root.labelPillFill
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
