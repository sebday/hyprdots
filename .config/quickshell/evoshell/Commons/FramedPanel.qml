import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string labelAlign: "left"
    property int contentPad: Theme.panelContentPad
    property int legendPad: -1
    property color frameBorder: Theme.foregroundBorder
    property bool contentFill: false
    property int labelFontSize: Theme.fontSizeS
    property color labelBackground: Theme.background
    property bool filled: false
    property color fillColor: Theme.panelMantle
    property int labelPadH: Theme.panelLabelPadH
    property real labelOpacity: Theme.opacitySecondary
    property bool labelProminent: false
    property bool labelClickable: false
    property int labelGap: Theme.spacingM
    property Item legendOverlay: null
    property Item legendOverlayParent: null

    signal labelClicked()

    default property alias content: contentHost.data

    readonly property bool hasLabel: label !== ""
    readonly property bool hasLegendOverlay: legendOverlay && legendOverlay.visible
    readonly property int legendOverlayHeight: hasLegendOverlay ? legendOverlay.implicitHeight : 0
    readonly property int legendTopInset: hasLegendOverlay ? 4 : 0
    readonly property int legendLineOverlap: 7
    readonly property int legendOverlap: legendOverlayHeight > 0
        ? legendOverlayHeight + legendTopInset - legendLineOverlap : 0
    readonly property int cornerRadius: Theme.fieldsetCornerRadius
    readonly property int scaledPad: contentPad
    readonly property int resolvedLegendPad: legendPad >= 0 ? legendPad : scaledPad
    readonly property int contentWidth: Math.max(contentHost.childrenRect.width, 1)
    readonly property int contentHeight: Math.max(contentHost.childrenRect.height, 1)
    readonly property int labelRowHeight: hasLabel ? frameLabel.implicitHeight + labelGap : 0
    readonly property int legendContentGap: hasLegendOverlay ? Theme.spacingS : 0
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
            y: -1
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
        x: frameBox.x + root.resolvedLegendPad
        y: frameBox.y
        width: Math.max(root.legendOverlayWidth, 1)
        height: Math.max(root.legendOverlayHeight, 1)
    }

    onLegendOverlayChanged: {
        legendOverlayConn.target = legendOverlay
        syncLegendOverlay()
    }

    onLegendOverlayParentChanged: Qt.callLater(syncLegendOverlay)

    onLegendOverlayHeightChanged: syncLegendOverlay()

    onLegendOverlayWidthChanged: Qt.callLater(syncLegendOverlay)

    Connections {
        target: frameBox
        function onYChanged() { Qt.callLater(root.syncLegendOverlay) }
        function onXChanged() { Qt.callLater(root.syncLegendOverlay) }
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
        var overlayParent = root.legendOverlayParent || root
        legendOverlay.parent = overlayParent
        var anchorPos = legendAnchor.mapToItem(overlayParent, 0, 0)
        legendOverlay.x = anchorPos.x
        legendOverlay.y = anchorPos.y - legendOverlay.implicitHeight + root.legendLineOverlap
        legendOverlay.z = 10
        legendBorderMask.x = legendAnchor.x - frameBox.x
        legendBorderMask.width = legendOverlay.implicitWidth
    }

    onContentHeightChanged: Qt.callLater(syncLegendOverlay)
    onLegendOverlapChanged: Qt.callLater(syncLegendOverlay)
    onResolvedLegendPadChanged: Qt.callLater(syncLegendOverlay)

    Component.onCompleted: syncLegendOverlay()
}
