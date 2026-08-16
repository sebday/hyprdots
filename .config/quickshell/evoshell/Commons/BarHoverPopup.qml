import QtQuick

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string layerNamespace: "evo-hover"
    property int contentWidth: 420
    property int contentMargin: Theme.hoverPopupMargin
    property int minContentHeight: 0

    readonly property bool barOnTop: shell && shell.barConfig
        && String(shell.barConfig.position) === "top"
    readonly property int contentTopPad: barOnTop ? Theme.barHoverTopPad : contentMargin
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
        if (module && typeof module.bootstrapFromCache === "function")
            module.bootstrapFromCache()
        opened = true
        if (module && typeof module.onActivated === "function")
            module.onActivated()
    }

    function close() {
        opened = false
        if (module && typeof module.onDeactivated === "function")
            module.onDeactivated()
    }

    BarHoverOverlay {
        shell: root.shell
        opened: root.opened
        layerNamespace: root.layerNamespace
        contentMargin: root.contentMargin
        contentTopMargin: root.contentTopPad
        contentWidth: root.contentWidth
        contentHeight: root.bodyHeight + root.contentTopPad + root.contentBottomPad

        Item {
            anchors.fill: parent

            Item {
                id: moduleSlot
                anchors.fill: parent
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                enabled: root.opened && root.module && typeof root.module.stepVolume === "function"
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0) root.module.stepVolume(1)
                    else if (wheel.angleDelta.y < 0) root.module.stepVolume(-1)
                    wheel.accepted = true
                }
            }
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
        property: "shell"
        value: root.shell
        when: root.module !== null
    }

    Binding {
        target: root.module
        property: "hoverPopupWidth"
        value: root.bodyWidth
        when: root.module !== null
    }
}
