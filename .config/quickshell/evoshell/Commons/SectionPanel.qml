import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property int sectionSpacing: Theme.tooltipSectionSpacing
    property int labelFontSize: Theme.tooltipLabelFontPixelSize
    property int contentPad: Theme.tooltipContentPad
    property color legendBackground: Theme.mantle

    Layout.fillWidth: true
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    default property alias sectionContent: innerCol.data

    FramedPanel {
        id: panel
        width: root.width
        label: root.label
        labelFontSize: root.labelFontSize
        contentPad: root.contentPad
        labelBackground: root.legendBackground
        contentFill: true

        ColumnLayout {
            id: innerCol
            width: parent.width
            spacing: root.sectionSpacing
        }
    }
}
