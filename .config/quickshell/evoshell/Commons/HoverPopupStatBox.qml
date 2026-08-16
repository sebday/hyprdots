import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string value: ""
    property string label: ""
    property color valueColor: Theme.accent
    property int valueFontSize: Theme.hoverPopupTitleFontPixelSize + 2
    property int labelFontSize: Theme.hoverPopupHintFontPixelSize
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
            spacing: 2

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

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
                opacity: 0.55
                elide: Text.ElideRight
                maximumLineCount: 1
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
