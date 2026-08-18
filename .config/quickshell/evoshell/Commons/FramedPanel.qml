import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string labelAlign: "left"
    property int contentPad: Theme.panelContentPad
    property color frameBorder: Theme.foregroundBorder
    property bool contentFill: false
    property int labelFontSize: Theme.fontSizeS
    property color labelBackground: Theme.mantle
    property bool filled: false
    property color fillColor: Theme.panelMantle
    property int labelPadH: Theme.panelLabelPadH
    property real labelOpacity: Theme.opacitySecondary
    property bool labelProminent: false
    property bool labelClickable: false
    property int labelGap: Theme.spacingM
    property Item legendOverlay: null

    signal labelClicked()

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property bool hasLegendOverlay: legendOverlay && legendOverlay.visible
    readonly property int legendOverlayHeight: hasLegendOverlay ? legendOverlay.implicitHeight : 0
    readonly property int legendTopInset: hasLegendOverlay ? 4 : 0
    readonly property int legendOverlap: legendOverlayHeight > 0
        ? Math.ceil(legendOverlayHeight / 2) + legendTopInset : 0
    readonly property int cornerRadius: Theme.fieldsetCornerRadius
    readonly property int scaledPad: contentPad
    readonly property int contentWidth: Math.max(contentHost.childrenRect.width, 1)
    readonly property int contentHeight: Math.max(contentHost.childrenRect.height, 1)
    readonly property int labelRowHeight: hasLabel ? frameLabel.implicitHeight + labelGap : 0
    readonly property int legendContentGap: hasLegendOverlay ? Math.max(Theme.spacingS, Math.ceil(legendOverlayHeight / 2)) : 0
    readonly property int verticalChrome: scaledPad * 2 + labelRowHeight + legendContentGap
    readonly property int frameHeight: contentHeight + verticalChrome

    implicitWidth: root.contentFill
        ? (parent ? parent.width : contentWidth + scaledPad * 2)
        : Math.max(contentWidth + scaledPad * 2,
                   hasLabel ? frameLabel.implicitWidth + scaledPad * 2 : 0)
    implicitHeight: root.contentFill
        ? Math.max(frameHeight + legendOverlap, 32)
        : frameHeight + legendOverlap

    clip: false

    Item {
        id: frameBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.legendOverlap
        anchors.bottom: root.contentFill ? parent.bottom : undefined
        height: root.contentFill ? undefined : root.frameHeight

        Rectangle {
            id: frameRect
            anchors.fill: parent
            color: root.filled ? root.fillColor : "transparent"
            border.color: root.filled ? "transparent" : root.frameBorder
            border.width: root.filled ? 0 : 1
            radius: root.cornerRadius
        }

        Rectangle {
            id: legendBorderMask
            visible: root.hasLegendOverlay
            z: 1
            x: root.scaledPad - 6
            y: -1
            width: root.legendOverlayWidth + 12
            height: 3
            color: root.labelBackground
        }

        ColumnLayout {
            id: frameColumn
            anchors.fill: parent
            anchors.leftMargin: root.scaledPad
            anchors.rightMargin: root.scaledPad
            anchors.bottomMargin: root.scaledPad
            anchors.topMargin: root.scaledPad + root.legendContentGap
            spacing: root.labelGap

            Text {
                id: frameLabel
                visible: root.hasLabel
                Layout.fillWidth: true
                horizontalAlignment: root.labelAlign === "center"
                    ? Text.AlignHCenter
                    : Text.AlignLeft
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelProminent
                    ? Math.max(8, root.labelFontSize - 1)
                    : Math.max(8, root.labelFontSize - 2)
                font.bold: Theme.fontBold
                opacity: root.labelOpacity
            }

            Item {
                id: contentHost
                Layout.fillWidth: true
                Layout.fillHeight: root.contentFill
                implicitHeight: root.contentFill ? 0 : root.contentHeight
            }
        }

        MouseArea {
            anchors.left: frameColumn.left
            anchors.right: frameColumn.right
            anchors.top: frameColumn.top
            height: frameLabel.visible ? frameLabel.implicitHeight : 0
            visible: root.labelClickable && frameLabel.visible
            cursorShape: Qt.PointingHandCursor
            onClicked: root.labelClicked()
        }
    }

    readonly property int legendOverlayWidth: hasLegendOverlay ? legendOverlay.implicitWidth : 0

    Item {
        id: legendAnchor
        visible: root.hasLegendOverlay
        x: frameBox.x + root.scaledPad
        y: frameBox.y
        width: root.legendOverlayWidth
        height: 0
    }

    onLegendOverlayChanged: {
        legendOverlayConn.target = legendOverlay
        syncLegendOverlay()
    }

    onLegendOverlayHeightChanged: syncLegendOverlay()

    onLegendOverlayWidthChanged: {
        legendBorderMask.width = root.legendOverlayWidth + 12
    }

    Connections {
        id: legendOverlayConn
        ignoreUnknownSignals: true
        function onImplicitHeightChanged() { root.syncLegendOverlay() }
        function onImplicitWidthChanged() { root.syncLegendOverlay() }
        function onVisibleChanged() { root.syncLegendOverlay() }
    }

    function syncLegendOverlay() {
        if (!root.hasLegendOverlay)
            return
        legendOverlay.parent = root
        legendOverlay.x = legendAnchor.x
        legendOverlay.y = legendAnchor.y - legendOverlay.implicitHeight / 2
        legendOverlay.z = 2
        legendBorderMask.width = legendOverlay.implicitWidth + 12
    }

    Component.onCompleted: syncLegendOverlay()
}
