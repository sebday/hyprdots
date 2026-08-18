import QtQuick

Item {
    id: root

    property var shell: null
    property bool opened: false
    property bool revealed: false
    property string layerNamespace: "evo-hover"
    property int contentWidth: Theme.overlayWidthDefault
    property int contentMargin: Theme.hoverPopupMargin
    property int minContentHeight: 0

    readonly property bool barOnTop: shell && shell.barConfig
        && String(shell.barConfig.position) === "top"
    readonly property int contentTopPad: barOnTop ? Theme.barHoverTopPad : contentMargin
    readonly property int contentBottomPad: contentMargin
    readonly property int contentInset: root.contentMargin + Theme.hoverPopupBorderWidth

    default property alias moduleContent: moduleSlot.data

    readonly property Item module: moduleSlot.children.length > 0 ? moduleSlot.children[0] : null
    readonly property int bodyWidth: Math.max(0, root.contentWidth - root.contentInset * 2)
    readonly property int bodyHeight: {
        if (!module || module.implicitHeight === undefined)
            return 0
        return Math.max(root.minContentHeight, module.implicitHeight)
    }

    function moduleContentReady() {
        if (!module)
            return true
        if (module.contentReady !== undefined)
            return module.contentReady === true
        if (module.loading !== undefined && module.loading)
            return false
        if (module.mediaLoading !== undefined && module.mediaLoading)
            return false
        return true
    }

    function tryReveal() {
        if (!root.opened || root.revealed)
            return
        if (root.moduleContentReady()) {
            root.revealed = true
            revealMaxTimer.stop()
        }
    }

    function open(payloadJson) {
        revealMaxTimer.stop()
        revealed = false
        if (module && typeof module.bootstrapFromCache === "function")
            module.bootstrapFromCache()
        opened = true
        if (shell && typeof shell.popupHoverEnter === "function")
            shell.popupHoverEnter()
        if (module && typeof module.onActivated === "function")
            module.onActivated()
        Qt.callLater(tryReveal)
        revealMaxTimer.start()
    }

    function close() {
        revealMaxTimer.stop()
        revealed = false
        opened = false
        if (module && typeof module.onDeactivated === "function")
            module.onDeactivated()
    }

    onBodyHeightChanged: if (opened && !revealed) Qt.callLater(tryReveal)

    Connections {
        target: root.module
        enabled: root.module !== null
        function onLoadingChanged() {
            if (root.opened && !root.revealed)
                Qt.callLater(root.tryReveal)
        }
        function onMediaLoadingChanged() {
            if (root.opened && !root.revealed)
                Qt.callLater(root.tryReveal)
        }
    }

    Timer {
        id: revealMaxTimer
        interval: Theme.hoverPopupRevealMaxWait
        repeat: false
        onTriggered: {
            if (root.opened && !root.revealed)
                root.revealed = true
        }
    }

    BarHoverOverlay {
        shell: root.shell
        opened: root.opened
        revealed: root.revealed
        layerNamespace: root.layerNamespace
        contentMargin: root.contentMargin
        contentTopMargin: root.contentTopPad
        contentWidth: root.contentWidth
        contentHeight: root.bodyHeight + root.contentTopPad + root.contentBottomPad
            + Theme.hoverPopupBorderWidth * 2

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
                enabled: root.revealed && root.opened && root.module
                    && typeof root.module.stepVolume === "function"
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
