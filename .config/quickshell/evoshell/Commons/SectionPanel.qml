import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string labelAlign: "left"
    property int sectionSpacing: Theme.hoverPopupSectionSpacing
    property int labelFontSize: Theme.hoverPopupLabelFontPixelSize
    property int contentPad: Theme.hoverPopupContentPad
    property color legendBackground: Theme.mantle
    property real labelOpacity: 0.72
    property bool labelProminent: false
    property bool labelClickable: false

    signal labelClicked()

    Layout.fillWidth: true
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    default property alias sectionContent: innerCol.data

    FramedPanel {
        id: panel
        width: root.width
        label: root.label
        labelAlign: root.labelAlign
        labelFontSize: root.labelFontSize
        contentPad: root.contentPad
        labelBackground: root.legendBackground
        labelOpacity: root.labelOpacity
        labelProminent: root.labelProminent
        labelClickable: root.labelClickable
        contentFill: true
        onLabelClicked: root.labelClicked()

        ColumnLayout {
            id: innerCol
            width: parent.width
            spacing: root.sectionSpacing
        }
    }
}
