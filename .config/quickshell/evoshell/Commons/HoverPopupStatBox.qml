import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string value: ""
    property string label: ""
    property string icon: ""
    property color valueColor: Theme.accent
    property color iconColor: Theme.foreground
    property bool customFill: false
    property color customFillColor: Theme.panelMantle
    property int valueFontSize: Theme.fontSize5xl
    property int iconFontSize: Theme.fontSize6xl
    property int labelFontSize: Theme.fontSizeS
    property int contentPad: Theme.panelContentPad
    property bool clickable: false
    property bool special: false

    readonly property bool hasIcon: root.icon !== ""

    signal clicked()

    Layout.fillWidth: true
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    SectionPanel {
        id: panel
        anchors.fill: parent
        label: ""
        filled: true
        fillColor: root.customFill
            ? root.customFillColor
            : (root.special
                ? Theme.withOpacity(Theme.accent, 0.14)
                : Theme.panelMantle)
        contentPad: root.contentPad

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing2

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: root.hasIcon
                spacing: Theme.spacingS

                Text {
                    text: root.icon
                    color: root.iconColor
                    font.family: Theme.fontFamily
                    font.pixelSize: root.iconFontSize
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: 1
                }

                Text {
                    text: root.value
                    color: root.special ? Theme.accent : root.valueColor
                    font.family: Theme.fontFamily
                    font.pixelSize: root.valueFontSize
                    font.bold: Theme.fontBold
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.hasIcon
                horizontalAlignment: Text.AlignHCenter
                text: root.value
                color: root.special ? Theme.accent : root.valueColor
                font.family: Theme.fontFamily
                font.pixelSize: root.valueFontSize
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.label
                visible: root.label !== ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
                font.bold: root.special ? Theme.fontBold : false
                opacity: root.special ? 0.82 : Theme.opacityMuted
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.special
        radius: Theme.fieldsetCornerRadius
        color: "transparent"
        border.color: Theme.withOpacity(Theme.accent, 0.45)
        border.width: 1
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
