import QtQuick
import QtQuick.Layouts

// In-flow fieldset legend: pill on the left, horizontal rule to the right.
Item {
    id: root

    property color lineColor: Theme.fieldsetBorderColor
    property color legendBackground: Theme.mantle
    property int legendInset: Theme.fieldsetLegendInset

    default property alias legend: legendHost.data

    readonly property bool hasLegend: legendHost.children.length > 0
        && legendHost.children[0].visible
    readonly property int legendHeight: hasLegend ? legendHost.children[0].implicitHeight : 0

    implicitWidth: line.width
    implicitHeight: Math.max(legendHeight, Theme.fieldsetLegendMinHeight)

    Rectangle {
        id: line
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.fieldsetBorderWidth
        color: root.lineColor
    }

    Item {
        id: legendHost
        anchors.left: parent.left
        anchors.leftMargin: root.legendInset
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height

        onChildrenChanged: syncLegendFill()
    }

    function syncLegendFill() {
        for (var i = 0; i < legendHost.children.length; i++) {
            var child = legendHost.children[i]
            if (child && child.fieldsetFill !== undefined)
                child.fieldsetFill = root.legendBackground
        }
    }

    function releaseLegend(target) {
        while (legendHost.children.length > 0)
            legendHost.children[0].parent = target || null
    }

    function adoptLegend(item) {
        releaseLegend(null)
        if (!item || item.fieldsetLegend !== true || !item.visible)
            return false
        item.parent = legendHost
        syncLegendFill()
        return true
    }

    onLegendBackgroundChanged: syncLegendFill()
}
