import QtQuick

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string layerNamespace: "evo-hover"
    property int contentWidth: 420
    property int contentMargin: Theme.tooltipMargin
    property int minContentHeight: 0

    readonly property bool barOnTop: shell && shell.barConfig
        && String(shell.barConfig.position) === "top"
    readonly property int contentTopPad: barOnTop ? Theme.barTooltipTopPad : contentMargin
    readonly property int contentBottomPad: contentMargin

    default property alias moduleContent: moduleSlot.data

    readonly property Item module: moduleSlot.children.length > 0 ? moduleSlot.children[0] : null
    readonly property int bodyWidth: Math.max(0, root.contentWidth - root.contentMargin * 2)
    readonly property int bodyHeight: {
        if (!module || module.implicitHeight === undefined)
            return 0
        return Math.max(root.minContentHeight, module.implicitHeight)
    }

    function open(payloadJson) {
        opened = true
        if (module && typeof module.onActivated === "function")
            module.onActivated()
    }

    function close() {
        opened = false
        if (module && typeof module.onDeactivated === "function")
            module.onDeactivated()
    }

    BarHoverPopup {
        shell: root.shell
        opened: root.opened
        layerNamespace: root.layerNamespace
        contentMargin: root.contentMargin
        contentTopMargin: root.contentTopPad
        contentWidth: root.contentWidth
        contentHeight: root.bodyHeight + root.contentTopPad + root.contentBottomPad

        Item {
            id: moduleSlot
            anchors.fill: parent
        }
    }

    Binding {
        target: root.module
        property: "host"
        value: root
        when: root.module !== null
    }

    Binding {
        target: root.module
        property: "tooltipWidth"
        value: root.bodyWidth
        when: root.module !== null
    }
}
