import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string labelAlign: "left"
    property int sectionSpacing: Theme.hoverPanelSectionSpacing
    property int labelFontSize: Theme.fontSizeL
    property int contentPad: Theme.hoverPanelContentPad
    property int legendPad: -1
    property color legendBackground: Theme.background
    property bool filled: false
    property color fillColor: Theme.panelMantle
    property real labelOpacity: 0.72
    property bool labelProminent: false
    property bool labelClickable: false
    property bool fillHeight: false
    property bool notchLegend: false
    property string legendText: ""
    property string legendIcon: ""
    property bool legendClickable: false

    signal labelClicked()
    signal legendClicked()

    readonly property bool showNotchLegend: notchLegend
        && (legendText !== "" || legendIcon !== "")

    Layout.fillWidth: true
    Layout.fillHeight: fillHeight
    clip: false
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    readonly property int verticalChrome: panel.verticalChrome

    default property alias sectionContent: innerCol.data

    function syncLegendFill(child) {
        if (!child || child.fieldsetFill === undefined)
            return
        child.fieldsetFill = Qt.binding(function() { return root.legendBackground })
    }

    function adoptFieldsetLegend() {
        if (root.showNotchLegend) {
            root.syncLegendFill(notchLegendPill)
            panel.legendOverlay = notchLegendPill
            panel.labelBackground = root.legendBackground
            Qt.callLater(panel.syncLegendOverlay)
            return
        }
        if (panel.legendOverlay && panel.legendOverlay.fieldsetLegend === true) {
            root.syncLegendFill(panel.legendOverlay)
            panel.labelBackground = root.legendBackground
            Qt.callLater(panel.syncLegendOverlay)
            return
        }
        for (var i = 0; i < innerCol.children.length; i++) {
            var child = innerCol.children[i]
            if (!child || child.fieldsetLegend !== true)
                continue
            root.syncLegendFill(child)
            panel.legendOverlay = child
            panel.labelBackground = root.legendBackground
            Qt.callLater(panel.syncLegendOverlay)
            return
        }
        panel.legendOverlay = null
    }

    onLegendBackgroundChanged: adoptFieldsetLegend()
    onNotchLegendChanged: adoptFieldsetLegend()
    onLegendTextChanged: adoptFieldsetLegend()
    onLegendIconChanged: adoptFieldsetLegend()
    onVisibleChanged: if (visible) Qt.callLater(adoptFieldsetLegend)

    HoverPanelLabelPill {
        id: notchLegendPill
        visible: root.showNotchLegend
        text: root.legendText
        icon: root.legendIcon
        fieldsetLegend: true
        fieldsetFill: root.legendBackground
        fontSize: Theme.fontSizeS
        clickable: root.legendClickable
        onClicked: root.legendClicked()
    }

    FramedPanel {
        id: panel
        anchors.fill: root.fillHeight ? parent : undefined
        width: root.fillHeight ? undefined : root.width
        legendOverlayParent: root
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
