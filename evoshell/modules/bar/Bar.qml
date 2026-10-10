import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.commons
import "."
import "widgets"

Scope {
    id: root

    property var shell: null
    property var barConfig: ({})
    property var barWidgetRegistry: null

    // Bar host contract read by qs.ui BarWidget/Panel/PopupCard.
    readonly property bool vertical: position === "left" || position === "right"
    readonly property int barSize: Theme.barHeight
    readonly property string fontFamily: Theme.fontFamily
    readonly property color barForeground: Theme.foreground
    readonly property color foreground: barForeground
    readonly property color urgent: Theme.urgent
    readonly property bool foregroundAnimationEnabled: false

    function showTooltip(item, text) {}
    function hideTooltip(item) {}

    property var moduleSlots: []
    property var moduleSections: []
    property var barDragSource: null
    property var barDragTarget: null
    property bool barDragAfter: false
    property var barDragWindow: null
    property var barDragScreen: null
    property real barDragOffsetX: 0
    property real barDragOffsetY: 0
    property real barDragScreenX: 0
    property real barDragScreenY: 0
    property string barDragImageUrl: ""

    function registerModuleSection(section) {
        if (!section || moduleSections.indexOf(section) >= 0)
            return
        var next = moduleSections.slice()
        next.push(section)
        moduleSections = next
    }

    function unregisterModuleSection(section) {
        var next = []
        var i
        for (i = 0; i < moduleSections.length; i++) {
            if (moduleSections[i] && moduleSections[i] !== section)
                next.push(moduleSections[i])
        }
        moduleSections = next
    }

    function registerModuleSlot(slot) {
        if (!slot || moduleSlots.indexOf(slot) >= 0)
            return
        var next = moduleSlots.slice()
        next.push(slot)
        moduleSlots = next
    }

    function unregisterModuleSlot(slot) {
        var next = []
        var i
        for (i = 0; i < moduleSlots.length; i++) {
            if (moduleSlots[i] && moduleSlots[i] !== slot)
                next.push(moduleSlots[i])
        }
        moduleSlots = next
        if (barDragSource === slot)
            clearBarDrag()
    }

    function clearBarDrag() {
        barDragSource = null
        barDragTarget = null
        barDragAfter = false
        barDragWindow = null
        barDragScreen = null
        barDragOffsetX = 0
        barDragOffsetY = 0
        barDragScreenX = 0
        barDragScreenY = 0
        barDragImageUrl = ""
    }

    function barDragScreenPoint(scenePoint) {
        var x = scenePoint ? scenePoint.x : 0
        var y = scenePoint ? scenePoint.y : 0
        var window = barDragWindow
        if (!window || !window.screen)
            return { x: x, y: y }
        if (position === "bottom")
            y += Math.max(0, window.screen.height - window.height)
        else if (position === "right")
            x += Math.max(0, window.screen.width - window.width)
        return { x: x, y: y }
    }

    function captureBarDragGhost(slot) {
        var item = slot && slot.activeItem ? slot.activeItem : null
        barDragImageUrl = ""
        if (!item || typeof item.grabToImage !== "function")
            return
        var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
        var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
        item.grabToImage(function(result) {
            if (barDragSource !== slot || !result || !result.url)
                return
            barDragImageUrl = result.url
        }, Qt.size(grabWidth, grabHeight))
    }

    function sceneOrigin(item) {
        if (!item)
            return null
        try {
            return item.mapToItem(null, 0, 0)
        } catch (e) {
            return null
        }
    }

    function sameBarSurface(slot, sourceSlot) {
        if (!slot || !sourceSlot)
            return false
        if (slot.hostPanel && sourceSlot.hostPanel)
            return slot.hostPanel === sourceSlot.hostPanel
        return true
    }

    function sectionBounds(section) {
        var origin = sceneOrigin(section)
        if (!origin)
            return null
        return {
            region: section.region,
            x: origin.x,
            y: origin.y,
            width: section.width,
            height: section.height
        }
    }

    function dropRegionAt(axis, vertical, sourceSlot) {
        var center = null
        var i
        for (i = 0; i < moduleSections.length; i++) {
            var section = moduleSections[i]
            if (!section || section.region !== "center")
                continue
            if (sourceSlot && sourceSlot.hostPanel && section.barPanel !== sourceSlot.hostPanel)
                continue
            center = sectionBounds(section)
            break
        }
        if (!center)
            return ""
        var start = vertical ? center.y : center.x
        var size = vertical ? center.height : center.width
        if (!(size > 0))
            return ""
        if (axis < start)
            return "left"
        if (axis > start + size)
            return "right"
        return "center"
    }

    function nearestSlotDrop(rows, axis, vertical) {
        var best = null
        var bestDistance = Infinity
        var i
        for (i = 0; i < rows.length; i++) {
            var row = rows[i]
            var start = vertical ? row.y : row.x
            var size = vertical ? row.height : row.width
            if (!(size > 0))
                continue
            var beforeDistance = Math.abs(axis - start)
            var afterDistance = Math.abs(axis - (start + size))
            var after = afterDistance < beforeDistance
            var distance = after ? afterDistance : beforeDistance
            if (distance < bestDistance) {
                best = { slot: row.slot, after: after }
                bestDistance = distance
            }
        }
        return best
    }

    function dropCandidates(sourceSlot, region) {
        var rows = []
        var i
        for (i = 0; i < moduleSlots.length; i++) {
            var slot = moduleSlots[i]
            if (!slot || slot === sourceSlot || !sameBarSurface(slot, sourceSlot))
                continue
            if (region && slot.region !== region)
                continue
            if (!slot.visible || slot.width <= 0 || slot.height <= 0)
                continue
            var origin = sceneOrigin(slot)
            if (!origin)
                continue
            rows.push({
                slot: slot,
                x: origin.x,
                y: origin.y,
                width: slot.width,
                height: slot.height
            })
        }
        return rows
    }

    function moduleDropAtScene(scenePoint, sourceSlot) {
        var vertical = position === "left" || position === "right"
        var axis = vertical ? Number(scenePoint && scenePoint.y) : Number(scenePoint && scenePoint.x)
        if (!isFinite(axis))
            return null
        var region = dropRegionAt(axis, vertical, sourceSlot)
        var rows = region ? dropCandidates(sourceSlot, region) : []
        if (rows.length === 0)
            rows = dropCandidates(sourceSlot, "")
        return nearestSlotDrop(rows, axis, vertical)
    }

    function moveLayoutEntry(config, fromRegion, fromIndex, toRegion, toIndex) {
        if (!Util.isPlainObject(config.bar))
            config.bar = {}
        if (!Util.isPlainObject(config.bar.layout))
            config.bar.layout = {}
        if (!Array.isArray(config.bar.layout[fromRegion]))
            config.bar.layout[fromRegion] = []
        if (!Array.isArray(config.bar.layout[toRegion]))
            config.bar.layout[toRegion] = []
        var fromEntries = config.bar.layout[fromRegion]
        var toEntries = config.bar.layout[toRegion]
        if (fromIndex < 0 || fromIndex >= fromEntries.length)
            return false
        var moved = fromEntries[fromIndex]
        fromEntries.splice(fromIndex, 1)
        if (fromRegion === toRegion && fromIndex < toIndex)
            toIndex -= 1
        if (toIndex < 0)
            toIndex = 0
        if (toIndex > toEntries.length)
            toIndex = toEntries.length
        if (fromRegion === toRegion && fromIndex === toIndex) {
            fromEntries.splice(fromIndex, 0, moved)
            return false
        }
        toEntries.splice(toIndex, 0, moved)
        return true
    }

    function dropBarModule(sourceSlot, targetSlot, afterTarget) {
        if (!sourceSlot || !targetSlot || sourceSlot === targetSlot)
            return false
        if (!shell || typeof shell.mutateShellConfig !== "function")
            return false
        var fromRegion = sourceSlot.region
        var toRegion = targetSlot.region
        var fromIndex = sourceSlot.layoutIndex
        var toIndex = targetSlot.layoutIndex + (afterTarget ? 1 : 0)
        if (!fromRegion || !toRegion || fromIndex < 0 || targetSlot.layoutIndex < 0)
            return false
        shell.mutateShellConfig(function(config) {
            moveLayoutEntry(config, fromRegion, fromIndex, toRegion, toIndex)
        })
        return true
    }

    property var activePopout: null

    function requestPopout(owner) {
        if (shell && shell.hoverPanelId && typeof shell.hide === "function")
            shell.hide(shell.hoverPanelId)
        if (activePopout && activePopout !== owner && typeof activePopout.close === "function")
            activePopout.close()
        activePopout = owner
    }

    function releasePopout(owner) {
        if (activePopout === owner)
            activePopout = null
    }

    function moduleWidgets(pluginId) {
        var id = String(pluginId || "")
        var out = []
        var i
        for (i = 0; i < moduleSlots.length; i++) {
            var item = moduleSlots[i] && moduleSlots[i].activeItem
            if (item && String(item.moduleName || "") === id)
                out.push(item)
        }
        return out
    }

    // IPC targets are process-wide. When a bar exists on more than one screen,
    // only the configured output (or the first screen) should register them.
    function screenOwnsIpc(screenName) {
        var name = String(screenName || "")
        if (!name)
            return false
        var output = barOutput
        if (output)
            return name === output
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return false
        return name === String(screens[0].name || "")
    }

    function placementOutput() {
        var placements = barConfig && barConfig.placements
        if (!placements || placements.length === 0) return ""
        var last = placements[placements.length - 1]
        return last && last.output ? String(last.output).trim() : ""
    }

    function placementPosition() {
        var placements = barConfig && barConfig.placements
        if (!placements || placements.length === 0) return ""
        var last = placements[placements.length - 1]
        return last && last.position ? String(last.position) : ""
    }

    readonly property string position: {
        var p = barConfig && barConfig.position ? String(barConfig.position) : ""
        if (!p) p = placementPosition()
        return p || "bottom"
    }

    readonly property string barOutput: {
        if (barConfig && barConfig.output) return String(barConfig.output).trim()
        return placementOutput()
    }

    readonly property var barLayout: barConfig && barConfig.layout ? barConfig.layout : {}

    readonly property var barScreenModel: {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0) return []
        var output = barOutput
        if (!output) return screens
        var matched = []
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (s && String(s.name) === output) matched.push(s)
        }
        if (matched.length > 0) return matched
        return screens
    }

    Variants {
        model: root.barScreenModel

        PanelWindow {
            id: barPanel
            required property var modelData
            screen: modelData
            color: "transparent"
            implicitHeight: root.position === "top" || root.position === "bottom" ? Theme.barHeight : 0
            implicitWidth: root.position === "left" || root.position === "right" ? Theme.barHeight : 0

            anchors.top: root.position === "top"
            anchors.bottom: root.position === "bottom"
            anchors.left: root.position === "left" || root.position === "top" || root.position === "bottom"
            anchors.right: root.position === "right" || root.position === "top" || root.position === "bottom"

            WlrLayershell.namespace: "evo-bar"
            WlrLayershell.layer: WlrLayer.Top

            Rectangle {
                anchors.fill: parent
                color: Theme.background
                opacity: root.shell && root.shell.hoverPanelId ? 1.0 : Theme.surfaceOpacityInactive
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.shell && root.shell.hoverPanelId && typeof root.shell.hide === "function")
                        root.shell.hide(root.shell.hoverPanelId)
                    if (root.activePopout && typeof root.activePopout.close === "function")
                        root.activePopout.close()
                }
            }

            BarSection {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                sectionMargin: Theme.barGap
                region: "left"
                bar: root
                barPanel: barPanel
                shell: root.shell
                barConfig: root.barConfig
                widgetRegistry: root.barWidgetRegistry
                entries: Array.isArray(root.barLayout.left) ? root.barLayout.left : []
            }

            BarSection {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                region: "center"
                bar: root
                barPanel: barPanel
                shell: root.shell
                barConfig: root.barConfig
                widgetRegistry: root.barWidgetRegistry
                entries: Array.isArray(root.barLayout.center) ? root.barLayout.center : []
            }

            BarSection {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                sectionMargin: Theme.barGap
                region: "right"
                bar: root
                barPanel: barPanel
                shell: root.shell
                barConfig: root.barConfig
                widgetRegistry: root.barWidgetRegistry
                entries: Array.isArray(root.barLayout.right) ? root.barLayout.right : []
            }
        }
    }

    PanelWindow {
        id: dragGhost

        readonly property bool active: root.barDragSource !== null && root.barDragScreen !== null
        readonly property Item sourceItem: root.barDragSource ? root.barDragSource.activeItem : null

        visible: active
        screen: root.barDragScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "evo-bar-drag"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        mask: Region {}

        Image {
            visible: dragGhost.active && root.barDragImageUrl !== ""
            x: Math.round(root.barDragScreenX - root.barDragOffsetX)
            y: Math.round(root.barDragScreenY - root.barDragOffsetY)
            width: dragGhost.sourceItem ? Math.max(1, dragGhost.sourceItem.width) : 1
            height: dragGhost.sourceItem ? Math.max(1, dragGhost.sourceItem.height) : 1
            source: root.barDragImageUrl
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: 0.9
        }
    }
}
