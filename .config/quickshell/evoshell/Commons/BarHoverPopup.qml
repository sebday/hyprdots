import QtQuick
import "."

Item {
    id: root

    property var shell: null
    property string pluginId: ""
    readonly property string effectivePluginId: {
        if (pluginId)
            return pluginId
        if (layerNamespace)
            return layerNamespace.replace("-", ".")
        return ""
    }
    property bool opened: false
    property bool revealed: false
    property bool pinned: false
    property var pinnedAnchorItem: null
    property var pinnedAnchorWindow: null
    property string layerNamespace: "evo-hover"
    property int contentWidth: Theme.overlayWidthDefault
    property int contentMargin: Theme.hoverPopupMargin
    property int minContentHeight: 0

    readonly property bool barOnTop: shell && shell.barConfig
        && String(shell.barConfig.position) === "top"
    readonly property int contentTopPad: barOnTop ? Theme.barHoverContentTopPad : Theme.hoverPopupTopPad
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

    function togglePin() {
        if (pinned)
            unpin()
        else
            pin()
    }

    function pin() {
        if (pinned)
            return
        if (shell) {
            pinnedAnchorItem = shell.popupAnchorItem
            pinnedAnchorWindow = shell.popupAnchorWindow
        }
        pinned = true
        revealed = true
        if (shell && effectivePluginId)
            shell.pinHoverPopup(effectivePluginId)
    }

    function unpin() {
        if (!pinned)
            return
        pinned = false
        pinnedAnchorItem = null
        pinnedAnchorWindow = null
        if (shell && effectivePluginId)
            shell.unpinHoverPopup(effectivePluginId)
        close()
    }

    function open(payloadJson) {
        if (pinned && opened) {
            revealed = true
            return
        }
        revealMaxTimer.stop()
        revealed = false
        if (module && typeof module.bootstrapFromCache === "function")
            module.bootstrapFromCache()
        opened = true
        if (shell && typeof shell.popupHoverEnter === "function"
                && shell.peekHoverId !== effectivePluginId)
            shell.popupHoverEnter()
        if (module && typeof module.onActivated === "function")
            module.onActivated()
        Qt.callLater(tryReveal)
        revealMaxTimer.start()
    }

    function close() {
        if (pinned) {
            pinned = false
            pinnedAnchorItem = null
            pinnedAnchorWindow = null
            if (shell && effectivePluginId)
                shell.unpinHoverPopup(effectivePluginId)
        }
        revealMaxTimer.stop()
        revealed = false
        opened = false
        if (module && typeof module.onDeactivated === "function")
            module.onDeactivated()
    }

    onBodyHeightChanged: if (opened && !revealed) Qt.callLater(tryReveal)

    onRevealedChanged: {
        if (revealed && opened && hoverOverlay.pointerInside)
            Qt.callLater(function() { keySurface.forceActiveFocus() })
    }

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
        id: hoverOverlay
        shell: root.shell
        opened: root.opened
        revealed: root.revealed
        anchorItem: root.pinned
            ? root.pinnedAnchorItem
            : (root.opened && root.shell ? root.shell.popupAnchorItem : null)
        anchorWindow: root.pinned
            ? root.pinnedAnchorWindow
            : (root.opened && root.shell ? root.shell.popupAnchorWindow : null)
        barPosition: root.shell && root.shell.barConfig && root.shell.barConfig.position
            ? String(root.shell.barConfig.position)
            : "bottom"
        keyboardFocusEnabled: root.opened && root.revealed && hoverOverlay.pointerInside
        layerNamespace: root.layerNamespace
        contentMargin: root.contentMargin
        contentTopMargin: root.contentTopPad
        contentWidth: root.contentWidth
        contentHeight: root.bodyHeight + root.contentTopPad + root.contentBottomPad
            + Theme.hoverPopupBorderWidth * 2

        onRevealedHoverEntered: {
            if (root.opened && root.revealed && hoverOverlay.pointerInside)
                keySurface.forceActiveFocus()
        }

        onEscapePressed: {
            if (root.shell && root.effectivePluginId)
                root.shell.hide(root.effectivePluginId)
            else
                root.close()
        }

        onPinPressed: root.togglePin()

        Connections {
            target: hoverOverlay
            function onPointerInsideChanged() {
                if (!hoverOverlay.pointerInside)
                    keySurface.focus = false
                else if (root.opened && root.revealed)
                    keySurface.forceActiveFocus()
            }
        }

        Item {
            id: keySurface
            anchors.fill: parent
            focus: root.opened && root.revealed && hoverOverlay.pointerInside

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space && (event.modifiers & Qt.MetaModifier)) {
                    if (root.shell && typeof root.shell.toggleSystemMenu === "function")
                        root.shell.toggleSystemMenu()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Escape) {
                    if (root.shell && root.effectivePluginId)
                        root.shell.hide(root.effectivePluginId)
                    else
                        root.close()
                    event.accepted = true
                }
            }

            Item {
                id: moduleSlot
                anchors.fill: parent
            }

            MouseArea {
                anchors.fill: parent
                z: 1
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
