import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string labelAlign: "left"
    property int sectionSpacing: Theme.hoverPopupSectionSpacing
    property int labelFontSize: Theme.fontSizeL
    property int contentPad: Theme.hoverPopupContentPad
    property int legendPad: -1
    property color legendBackground: Theme.mantle
    property bool filled: false
    property color fillColor: Theme.panelMantle
    property real labelOpacity: 0.72
    property bool labelProminent: false
    property bool labelClickable: false
    property bool fillHeight: false

    signal labelClicked()

    Layout.fillWidth: true
    Layout.fillHeight: fillHeight
    clip: false
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    default property alias sectionContent: innerCol.data

    function adoptFieldsetLegend() {
        if (panel.legendOverlay && panel.legendOverlay.fieldsetLegend === true) {
            panel.legendOverlay.fieldsetFill = root.legendBackground
            panel.labelBackground = root.legendBackground
            Qt.callLater(panel.syncLegendOverlay)
            return
        }
        for (var i = 0; i < innerCol.children.length; i++) {
            var child = innerCol.children[i]
            if (!child || child.fieldsetLegend !== true)
                continue
            child.fieldsetFill = root.legendBackground
            panel.legendOverlay = child
            panel.labelBackground = root.legendBackground
            Qt.callLater(panel.syncLegendOverlay)
            return
        }
        panel.legendOverlay = null
    }

    onVisibleChanged: if (visible) Qt.callLater(adoptFieldsetLegend)

    FramedPanel {
        id: panel
        anchors.fill: root.fillHeight ? parent : undefined
        width: root.fillHeight ? undefined : root.width
        label: root.label
        labelAlign: root.labelAlign
        labelFontSize: root.labelFontSize
        contentPad: root.contentPad
        legendPad: root.legendPad
        labelBackground: root.legendBackground
        filled: root.filled
        fillColor: root.fillColor
        labelOpacity: root.labelOpacity
        labelProminent: root.labelProminent
        labelClickable: root.labelClickable
        contentFill: true
        onLabelClicked: root.labelClicked()

        ColumnLayout {
            id: innerCol
            width: parent.width
            height: root.fillHeight ? parent.height : undefined
            spacing: root.sectionSpacing

            onChildrenChanged: Qt.callLater(root.adoptFieldsetLegend)
        }
    }

    Component.onCompleted: adoptFieldsetLegend()
}
