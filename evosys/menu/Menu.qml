import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../commons"
import "../settings"
import "MenuEntries.js" as MenuEntries

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string filterText: ""
    property string mode: "power"
    property string submenu: ""
    property int menuTabIndex: 0
    property var commandEntries: []
    property var dynamicEntries: []
    property string dynamicEntryKind: ""
    property var visibleEntries: []
    property var cachedApps: []
    property var appIconMap: ({})
    property int appIconEpoch: 0
    property bool dynamicLoading: false
    property int selectedIndex: 0
    property real previewAreaMaxWidth: 1600
    property real previewAreaMaxHeight: 900

    readonly property bool powerMenuMode: mode === "power" && !submenu
    readonly property bool runnerMenuMode: mode === "runner" && !submenu
    readonly property bool previewTileMode: submenu === "themes" || submenu === "wallpaper"
    readonly property bool boxTileMode: previewTileMode
    readonly property bool framedMode: !previewTileMode
    readonly property bool sectionMenuMode: powerMenuMode && menuTabIndex === 0
    readonly property bool showMainMenuTabs: powerMenuMode
    readonly property bool showSettingsTab: powerMenuMode && menuTabIndex > 0
    readonly property var sectionColumnOrder: ["programs", "games", "panels", "right"]
    readonly property var mainTabModel: [
        { label: "Evoshell", icon: "󰣇" },
        { label: "Settings", icon: "󰒠" },
        { label: "Integrations", icon: "󰒓" },
        { label: "Home Assistant", icon: "󰠵" }
    ]
    property var sectionLayoutPrograms: []
    property var sectionLayoutGames: []
    property var sectionLayoutPanels: []
    property var sectionLayoutRight: []
    readonly property string previewFallbackIcon: submenu === "wallpaper" ? "󰏘" : "󰸌"
    readonly property int tileWidth: 160
    readonly property int tileHeight: 160
    readonly property int powerTileWidth: 136
    readonly property int powerTileHeight: 124
    readonly property int powerGridColumns: 5
    readonly property int powerHeaderHeight: 104
    readonly property int powerLogoFont: Theme.fontSize8xl * 2
    readonly property int powerTileIconSize: 52
    readonly property int tileSpacing: 24
    readonly property int tileIconSize: 64
    readonly property int previewTileWidth: 296
    readonly property int previewTileHeight: 204
    readonly property int previewImageHeight: 192
    readonly property real previewDpr: 2
    readonly property int listIconSize: 40
    readonly property int programEntryFontSize: Theme.fontSizeS
    readonly property int listFontSize: Theme.fontSize6xl
    readonly property int listRowHeight: 72
    readonly property int listFilterHeight: 38
    readonly property int listFilterFontSize: Theme.fontSizeL
    readonly property int previewMenuMargin: 48
    readonly property int appIconSourceSize: 128
    readonly property string menuHeaderIcon: "󰣇"
    readonly property string menuHeaderTitle: "Evo shell"
    readonly property string menuHeaderSubtitle: "Programs · games · panels · session"

    readonly property int previewGridColumns: 5
    readonly property int previewColumnCount: gridColumnCount
    readonly property int activeTileWidth: previewTileMode ? previewTileWidth : tileWidth
    readonly property int activeTileHeight: previewTileMode ? previewTileHeight : tileHeight

    property int sizingEntryCount: 0

    readonly property int gridColumnCount: {
        var n = sizingEntryCount
        if (n <= 0) return 1
        if (previewTileMode)
            return Math.max(1, Math.min(n, previewGridColumns))
        var maxW = panel.previewAreaMaxWidth
        var cols = Math.floor((maxW + tileSpacing) / (activeTileWidth + tileSpacing))
        return Math.max(1, Math.min(n, cols))
    }

    readonly property int gridRowCount: {
        var n = sizingEntryCount
        if (n <= 0) return 1
        return Math.ceil(n / gridColumnCount)
    }

    readonly property int gridWidth: {
        var cols = gridColumnCount
        if (cols <= 0) return activeTileWidth
        return cols * activeTileWidth + (cols - 1) * tileSpacing
    }

    readonly property int gridHeight: {
        var rows = gridRowCount
        if (rows <= 0) return activeTileHeight
        return rows * activeTileHeight + (rows - 1) * tileSpacing
    }

    readonly property int menuOuterTopInset: Theme.overlayTopInset
    readonly property int menuOuterInset: Theme.overlaySideInset
    readonly property int menuFieldsetPad: Theme.hoverPanelContentPad
    readonly property int menuLegendChrome: 20
    readonly property int menuChromeHeight: menuOuterTopInset + menuOuterInset + menuFieldsetPad * 2 + menuLegendChrome
    readonly property int menuChromeWidth: menuOuterInset * 2 + menuFieldsetPad * 2

    readonly property int styledMenuViewportHeight: {
        var chrome = menuChromeHeight
        var available = Math.max(powerTileHeight + tileSpacing,
            panel.previewAreaMaxHeight - chrome)
        return Math.min(gridHeight, available)
    }

    readonly property int previewRowCount: gridRowCount
    readonly property int previewGridWidth: gridWidth
    readonly property int previewGridHeight: gridHeight

    readonly property int tileRowWidth: {
        var n = sizingEntryCount
        if (n <= 0) return tileWidth
        return n * tileWidth + (n - 1) * tileSpacing
    }

    readonly property int previewRowWidth: {
        var n = sizingEntryCount
        if (n <= 0) return previewTileWidth
        return n * previewTileWidth + (n - 1) * tileSpacing
    }

    readonly property int boxRowWidth: previewTileMode ? gridWidth : tileRowWidth
    readonly property int boxRowHeight: previewTileMode ? gridHeight : tileHeight
    readonly property int styledMenuHostHeight: styledMenuViewportHeight + menuChromeHeight

    readonly property string home: Quickshell.env("HOME")
    readonly property string evoshellBin: shell ? shell.evoshellBin : Util.evoshellBinPath(home, null)
    readonly property string placeholderText: {
        if (submenu === "bindings") return "Search bindings…"
        if (submenu === "shell") return "Search shell commands…"
        if (runnerMenuMode) return "Launch a program…"
        if (mode === "power") return "Search programs and system…"
        return "Search…"
    }

    readonly property bool infoListMode: submenu === "bindings" || submenu === "shell"
    readonly property int framedMenuWidth: root.runnerMenuMode
        ? Theme.clipboardPanelWidth
        : Theme.systemPanelWidth
    readonly property int infoListFontSize: Theme.fontSizeS
    readonly property int infoListRowHeight: 40
    readonly property int powerLinkRowHeight: 36
    readonly property int powerLinkIconSize: 18
    readonly property int powerSectionChrome: 36
    readonly property int powerSectionSpacing: Theme.hoverPanelSectionSpacing
    readonly property int framedFilterChromeHeight: listFilterHeight
    readonly property int framedColumnSpacing: Theme.hoverPanelSectionSpacing
    readonly property int infoDetailHeight: 96
    readonly property var selectedFiles: {
        var list = visibleEntries
        if (!infoListMode || list.length === 0)
            return []
        var idx = Math.max(0, Math.min(selectedIndex, list.length - 1))
        var raw = String(list[idx].files || "").trim()
        if (!raw)
            return []
        return raw.split("|").map(function(f) { return f.trim() }).filter(function(f) { return f.length > 0 })
    }
    readonly property string selectedDetail: {
        var list = visibleEntries
        if (!infoListMode || list.length === 0)
            return ""
        var idx = Math.max(0, Math.min(selectedIndex, list.length - 1))
        return String(list[idx].detail || "").trim()
    }
    readonly property bool infoDetailVisible: infoListMode
        && (selectedDetail.length > 0 || selectedFiles.length > 0)
    readonly property int framedHeaderChromeHeight: menuFieldsetPad * 2 + menuLegendChrome
        + framedFilterChromeHeight + framedColumnSpacing
    readonly property int framedChromeHeight: framedHeaderChromeHeight
        + (infoDetailVisible ? infoDetailHeight + framedColumnSpacing : 0)
    readonly property int framedListMaxHeight: Math.max(
        120,
        previewAreaMaxHeight - menuOuterTopInset - menuOuterInset - framedChromeHeight)
    readonly property int screenHeight: panel.height > 0 ? panel.height : 1080
    readonly property bool fixedFramedMenuHeight: powerMenuMode || runnerMenuMode
    readonly property int framedMenuPanelHeight: Math.round(screenHeight * 0.4)
    readonly property int framedMenuColumnHeight: framedMenuPanelHeight - menuOuterTopInset - menuOuterInset
    readonly property int powerMenuTabBarHeight: Theme.fontSizeS + 8
    readonly property int powerMenuViewportHeight: Math.max(
        160,
        framedMenuColumnHeight - powerMenuTabBarHeight - framedColumnSpacing)
    readonly property int runnerFieldsetChromeHeight: menuFieldsetPad * 2 + menuLegendChrome + framedColumnSpacing
    readonly property int runnerViewportHeight: Math.max(
        160,
        framedMenuColumnHeight - runnerFieldsetChromeHeight)
    readonly property int framedListHeight: {
        if (infoListMode) {
            var infoRows = Math.max(visibleEntries.length, 1)
            return Math.min(infoRows * infoListRowHeight, framedListMaxHeight)
        }
        var rows = Math.max(visibleEntries.length, 1)
        return Math.min(rows * listRowHeight, framedListMaxHeight)
    }

    function shortenMenuPath(path) {
        var p = String(path || "")
        if (p.indexOf(home) === 0)
            return "~" + p.slice(home.length)
        return p
    }

    function focusSearchField() {
        if (root.framedMode)
            menuHost.forceActiveFocus()
        else if (root.previewTileMode)
            menuHost.forceActiveFocus()
    }

    function appendFilterText(text) {
        if (!text)
            return
        root.filterText = root.filterText + text
        if (filterField.text !== root.filterText)
            filterField.text = root.filterText
    }

    function trimFilterText() {
        if (root.filterText.length === 0)
            return
        root.filterText = root.filterText.slice(0, -1)
        if (filterField.text !== root.filterText)
            filterField.text = root.filterText
    }

    function activateMainMenuTab(index) {
        var tab = Math.max(0, Math.min(root.mainTabModel.length - 1, index))
        if (tab === root.menuTabIndex)
            return
        root.menuTabIndex = tab
        root.onMainMenuTabActivated(tab)
    }

    function cycleMainMenuTab(backward) {
        if (!root.showMainMenuTabs)
            return
        var count = root.mainTabModel.length
        var next = backward
            ? (root.menuTabIndex + count - 1) % count
            : (root.menuTabIndex + 1) % count
        root.activateMainMenuTab(next)
    }

    function parseMenuTabIndex(payload) {
        if (!payload || payload.tab === undefined || payload.tab === null)
            return 0
        var tab = payload.tab
        if (typeof tab === "number")
            return Math.max(0, Math.min(3, tab))
        var name = String(tab).toLowerCase()
        if (name === "settings" || name === "1")
            return 1
        if (name === "integrations" || name === "2")
            return 2
        if (name === "homeassistant" || name === "ha" || name === "3")
            return 3
        return 0
    }

    function onMainMenuTabActivated(index) {
        if (index > 0) {
            embeddedSettings.onActivated()
            if (index === 3)
                embeddedSettings.loadHaDiscovery()
        } else if (powerMenuMode) {
            focusSearchField()
        }
    }

    function open(payloadJson) {
        try {
            var payload = JSON.parse(payloadJson || "{}")
            mode = String(payload.mode || "power")
            submenu = String(payload.submenu || "")
            menuTabIndex = mode === "runner" ? 0 : parseMenuTabIndex(payload)
        } catch (e) {
            mode = "power"
            submenu = ""
            menuTabIndex = 0
        }
        filterText = ""
        if (filterField.text !== "")
            filterField.text = ""
        selectedIndex = 0
        refreshCommandEntries()
        if (submenu) loadDynamicEntries(submenu)
        else dynamicEntries = []
        if (mode === "power" || mode === "runner") {
            rebuildAppCache()
            syncVisibleEntries()
        } else {
            syncVisibleEntries()
        }
        opened = true
        Qt.callLater(function() {
            root.previewAreaMaxWidth = panel.previewAreaMaxWidth
            root.previewAreaMaxHeight = panel.previewAreaMaxHeight
            if (menuTabIndex > 0)
                onMainMenuTabActivated(menuTabIndex)
            else
                root.focusSearchField()
        })
    }

    function dismiss() {
        if (shell) shell.hide("evo.sys.menu")
        else close()
    }

    function reopen(payloadJson) {
        if (!opened)
            return false
        var parsed = { mode: mode, submenu: submenu, tab: menuTabIndex }
        try {
            parsed = JSON.parse(payloadJson || "{}")
        } catch (e) {}
        var nextMode = String(parsed.mode || mode)
        var nextSubmenu = String(parsed.submenu || "")
        var nextTab = nextMode === "runner" ? 0 : parseMenuTabIndex(parsed)
        if (nextMode === mode && nextSubmenu === submenu && nextTab === menuTabIndex)
            return false
        open(payloadJson)
        return true
    }

    function close() {
        if (!opened) return
        opened = false
        filterText = ""
        submenu = ""
        menuTabIndex = 0
        dynamicEntries = []
        dynamicEntryKind = ""
        selectedIndex = 0
    }

    function moveSelection(delta) {
        var count = visibleEntries.length
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        var next = selectedIndex + delta
        if (next < 0) next = count - 1
        else if (next >= count) next = 0
        selectedIndex = next
        if (framedMode && !sectionMenuMode)
            entryList.positionViewAtIndex(selectedIndex, ListView.Contain)
        else if (previewTileMode)
            ensureGridSelectionVisible()
        else if (sectionMenuMode)
            ensureSectionSelectionVisible()
    }

    function stampPowerSection(section, globalIndex) {
        if (!section)
            return { section: null, nextIndex: globalIndex }
        var entries = section.entries.map(MenuEntries.mapEntry)
        if (entries.length === 0)
            return { section: null, nextIndex: globalIndex }
        var stamped = []
        for (var j = 0; j < entries.length; j++) {
            var entry = entries[j]
            entry.globalIndex = globalIndex
            globalIndex++
            stamped.push(entry)
        }
        return {
            section: {
                title: section.title,
                icon: section.icon,
                entries: stamped
            },
            nextIndex: globalIndex
        }
    }

    function stampAppSection(section, globalIndex) {
        if (!section || !section.entries || section.entries.length === 0)
            return { section: null, nextIndex: globalIndex }
        var stamped = []
        for (var j = 0; j < section.entries.length; j++) {
            var entry = section.entries[j]
            stamped.push({
                kind: entry.kind,
                name: entry.name,
                id: entry.id,
                entryRef: entry.entryRef,
                iconSource: entry.iconSource || "",
                icon: entry.icon || "󰀻",
                globalIndex: globalIndex
            })
            globalIndex++
        }
        return {
            section: {
                title: section.title,
                icon: section.icon,
                entries: stamped
            },
            nextIndex: globalIndex
        }
    }

    function isGameApp(app) {
        if (!app || !app.entryRef || !app.entryRef.categories)
            return false
        var cats = app.entryRef.categories
        for (var i = 0; i < cats.length; i++) {
            var cat = String(cats[i] || "").toLowerCase()
            if (cat === "game" || cat.startsWith("game"))
                return true
        }
        return false
    }

    function sortedApps() {
        return cachedApps.slice().sort(function(a, b) {
            return String(a.name || "").localeCompare(String(b.name || ""))
        })
    }

    function appsByKind(games) {
        var apps = sortedApps()
        var out = []
        for (var i = 0; i < apps.length; i++) {
            if (isGameApp(apps[i]) === games)
                out.push(apps[i])
        }
        return out
    }

    function rebuildSectionMenuLayout() {
        if (!sectionMenuMode) {
            sectionLayoutPrograms = []
            sectionLayoutGames = []
            sectionLayoutPanels = []
            sectionLayoutRight = []
            rebuildSizingEntryCount()
            return
        }
        var extensionPanels = shell ? shell.extensionSystemMenuPanels : []
        var raw = MenuEntries.systemSectionLayout(home, evoshellBin, extensionPanels)
        var globalIndex = 0
        var programsResult = stampAppSection({
            title: "Programs",
            icon: "󰀻",
            entries: appsByKind(false)
        }, globalIndex)
        globalIndex = programsResult.nextIndex
        var gamesResult = stampAppSection({
            title: "Games",
            icon: "󰊗",
            entries: appsByKind(true)
        }, globalIndex)
        globalIndex = gamesResult.nextIndex
        var panelsResult = stampPowerSection(raw.panels, globalIndex)
        globalIndex = panelsResult.nextIndex
        var right = []
        for (var i = 0; i < raw.right.length; i++) {
            var result = stampPowerSection(raw.right[i], globalIndex)
            globalIndex = result.nextIndex
            if (result.section)
                right.push(result.section)
        }
        sectionLayoutPrograms = programsResult.section ? [programsResult.section] : []
        sectionLayoutGames = gamesResult.section ? [gamesResult.section] : []
        sectionLayoutPanels = panelsResult.section ? [panelsResult.section] : []
        sectionLayoutRight = right
        rebuildSizingEntryCount()
    }

    function sectionMenuLayout() {
        return {
            programs: sectionLayoutPrograms,
            games: sectionLayoutGames,
            panels: sectionLayoutPanels,
            right: sectionLayoutRight
        }
    }

    function sectionMenuEntries() {
        var layout = sectionMenuLayout()
        var sections = []
        for (var c = 0; c < sectionColumnOrder.length; c++)
            sections = sections.concat(layout[sectionColumnOrder[c]])
        return sections
    }

    function powerSectionEntries() {
        return sectionMenuEntries()
    }

    function layoutColumnSections(layout, column) {
        return layout[column] || []
    }

    function sectionPosFromGlobal(globalIdx) {
        var layout = sectionMenuLayout()
        var idx = 0
        for (var c = 0; c < sectionColumnOrder.length; c++) {
            var column = sectionColumnOrder[c]
            var sections = layoutColumnSections(layout, column)
            for (var s = 0; s < sections.length; s++) {
                var section = sections[s]
                for (var e = 0; e < section.entries.length; e++) {
                    if (idx === globalIdx)
                        return {
                            column: column,
                            sectionIndex: s,
                            entryIndex: e,
                            sections: sections
                        }
                    idx++
                }
            }
        }
        return null
    }

    function globalFromSectionPos(column, sectionIndex, entryIndex) {
        var layout = sectionMenuLayout()
        var idx = 0
        for (var c = 0; c < sectionColumnOrder.length; c++) {
            var col = sectionColumnOrder[c]
            var sections = layoutColumnSections(layout, col)
            if (col === column) {
                for (var s = 0; s < sectionIndex; s++)
                    idx += sections[s].entries.length
                return idx + entryIndex
            }
            for (var s2 = 0; s2 < sections.length; s2++)
                idx += sections[s2].entries.length
        }
        return 0
    }

    function sectionHeight(section) {
        if (!section || !section.entries)
            return powerSectionChrome
        return powerSectionChrome + section.entries.length * powerLinkRowHeight + 8
    }

    function columnEntryY(sections, sectionIndex, entryIndex) {
        var y = 0
        for (var s = 0; s < sectionIndex; s++)
            y += sectionHeight(sections[s]) + powerSectionSpacing
        return y + powerSectionChrome + entryIndex * powerLinkRowHeight
    }

    function columnFlatIndex(sections, sectionIndex, entryIndex) {
        var flat = 0
        for (var s = 0; s < sectionIndex; s++)
            flat += sections[s].entries.length
        return flat + entryIndex
    }

    function sectionPosFromColumnFlat(sections, column, flat) {
        var walk = 0
        for (var s = 0; s < sections.length; s++) {
            var count = sections[s].entries.length
            if (flat < walk + count)
                return globalFromSectionPos(column, s, flat - walk)
            walk += count
        }
        return -1
    }

    function columnEntryCount(sections) {
        var total = 0
        for (var s = 0; s < sections.length; s++)
            total += sections[s].entries.length
        return total
    }

    function moveSectionSelection(dx, dy) {
        if (visibleEntries.length <= 0)
            return
        var pos = sectionPosFromGlobal(selectedIndex)
        if (!pos)
            return

        var layout = sectionMenuLayout()

        if (dy !== 0) {
            var flat = columnFlatIndex(pos.sections, pos.sectionIndex, pos.entryIndex)
            var columnCount = columnEntryCount(pos.sections)
            if (columnCount <= 0)
                return
            flat = (flat + dy + columnCount) % columnCount
            var next = sectionPosFromColumnFlat(pos.sections, pos.column, flat)
            if (next >= 0)
                selectedIndex = next
            ensureSectionSelectionVisible()
            return
        }

        if (dx === 0)
            return

        var colIdx = sectionColumnOrder.indexOf(pos.column)
        if (colIdx < 0)
            return
        var step = dx > 0 ? 1 : -1
        for (var attempt = 0; attempt < sectionColumnOrder.length - 1; attempt++) {
            colIdx += step
            if (colIdx < 0 || colIdx >= sectionColumnOrder.length)
                return
            var otherColumn = sectionColumnOrder[colIdx]
            var otherSections = layoutColumnSections(layout, otherColumn)
            if (otherSections.length === 0 || columnEntryCount(otherSections) === 0)
                continue

            var currentY = columnEntryY(pos.sections, pos.sectionIndex, pos.entryIndex)
            var bestIdx = -1
            var bestDist = Infinity
            for (var os = 0; os < otherSections.length; os++) {
                for (var oe = 0; oe < otherSections[os].entries.length; oe++) {
                    var y = columnEntryY(otherSections, os, oe)
                    var dist = Math.abs(y - currentY)
                    if (dist < bestDist) {
                        bestDist = dist
                        bestIdx = globalFromSectionPos(otherColumn, os, oe)
                    }
                }
            }
            if (bestIdx >= 0) {
                selectedIndex = bestIdx
                ensureSectionSelectionVisible()
            }
            return
        }
    }

    function sectionSelectedRowY() {
        var layout = sectionMenuLayout()
        var idx = 0
        for (var c = 0; c < sectionColumnOrder.length; c++) {
            var column = sectionColumnOrder[c]
            var sections = layoutColumnSections(layout, column)
            for (var s = 0; s < sections.length; s++) {
                var section = sections[s]
                for (var e = 0; e < section.entries.length; e++) {
                    if (idx === selectedIndex)
                        return columnEntryY(sections, s, e)
                    idx++
                }
            }
        }
        return 0
    }

    function ensureSectionSelectionVisible() {
        if (!sectionMenuMode)
            return
        var itemTop = sectionSelectedRowY()
        var itemBottom = itemTop + powerLinkRowHeight
        if (itemTop < sectionListFlickable.contentY)
            sectionListFlickable.contentY = itemTop
        else if (itemBottom > sectionListFlickable.contentY + sectionListFlickable.height)
            sectionListFlickable.contentY = Math.max(0, itemBottom - sectionListFlickable.height)
    }

    function ensureGridSelectionVisible() {
        if (!previewTileMode)
            return
    }

    function moveGridSelection(dx, dy) {
        var count = visibleEntries.length
        if (count <= 0) {
            selectedIndex = 0
            return
        }
        var cols = gridColumnCount
        var rows = gridRowCount
        var row = Math.floor(selectedIndex / cols)
        var col = selectedIndex % cols

        if (dx !== 0) {
            if (dx > 0) {
                if (col < cols - 1 && selectedIndex + 1 < count)
                    selectedIndex++
                else
                    selectedIndex = (selectedIndex + 1) % count
            } else {
                if (col > 0)
                    selectedIndex--
                else
                    selectedIndex = (selectedIndex - 1 + count) % count
            }
            return
        }

        if (dy === 0) return
        var targetRow = row + dy
        if (targetRow < 0) targetRow = rows - 1
        else if (targetRow >= rows) targetRow = 0
        var targetIdx = targetRow * cols + col
        if (targetIdx >= count) targetIdx = count - 1
        selectedIndex = targetIdx
        ensureGridSelectionVisible()
    }

    function handlePreviewLeft() {
        if (previewTileMode) moveGridSelection(-1, 0)
        else if (sectionMenuMode) moveSectionSelection(-1, 0)
    }

    function handlePreviewRight() {
        if (previewTileMode) moveGridSelection(1, 0)
        else if (sectionMenuMode) moveSectionSelection(1, 0)
    }

    function handlePreviewUp() {
        if (previewTileMode) moveGridSelection(0, -1)
        else if (sectionMenuMode) moveSectionSelection(0, -1)
        else if (framedMode) moveSelection(-1)
    }

    function handlePreviewDown() {
        if (previewTileMode) moveGridSelection(0, 1)
        else if (sectionMenuMode) moveSectionSelection(0, 1)
        else if (framedMode) moveSelection(1)
    }

    function moveTileSelection(dx, dy) {
        var n = visibleEntries.length
        if (n <= 0) return
        if (dy !== 0) return
        if (dx !== 0)
            selectedIndex = (selectedIndex + dx % n + n) % n
    }

    function activateSelection() {
        var list = visibleEntries
        if (list.length === 0) return
        var idx = Math.max(0, Math.min(selectedIndex, list.length - 1))
        activateEntry(list[idx])
    }

    function handleEscapeKey() {
        if (submenu) {
            submenu = ""
            dynamicEntries = []
            dynamicEntryKind = ""
            filterText = ""
            selectedIndex = 0
        } else if (filterText.trim() !== "" && (root.powerMenuMode || root.runnerMenuMode)) {
            filterText = ""
            selectedIndex = 0
        } else if (showSettingsTab && embeddedSettings.weatherLocationPickerOpen) {
            embeddedSettings.weatherLocationPickerOpen = false
        } else {
            dismiss()
        }
    }

    function entrySearchOpacity(entry, index) {
        var q = filterText.trim()
        if (!q) return 1
        if (index === selectedIndex) return 1
        return MenuEntries.matchesQuery(entry, q) ? Theme.opacitySecondary : Theme.opacityMuted
    }

    function focusBestSearchMatch() {
        var q = filterText.trim()
        if (!q) {
            selectedIndex = 0
            return
        }
        selectedIndex = MenuEntries.bestMatchIndex(visibleEntries, q)
        if (sectionMenuMode)
            Qt.callLater(root.ensureSectionSelectionVisible)
        else if (framedMode && infoListMode && entryList)
            entryList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function handleActivateKey() {
        activateSelection()
    }

    onFilterTextChanged: {
        rebuildSectionMenuLayout()
        refreshVisibleEntries()
        focusBestSearchMatch()
    }
    onSelectedIndexChanged: {
        if (sectionMenuMode)
            Qt.callLater(root.ensureSectionSelectionVisible)
        else if (framedMode && infoListMode && entryList)
            entryList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }
    onSubmenuChanged: {
        selectedIndex = 0
        refreshVisibleEntries()
        rebuildSectionMenuLayout()
    }
    onModeChanged: {
        refreshCommandEntries()
        selectedIndex = 0
        refreshVisibleEntries()
        rebuildSectionMenuLayout()
    }
    onCommandEntriesChanged: refreshVisibleEntries()
    onDynamicEntriesChanged: {
        refreshVisibleEntries()
        if (filterText.trim() !== "")
            Qt.callLater(root.focusBestSearchMatch)
    }

    function refreshCommandEntries() {
        if (mode === "power") {
            commandEntries = MenuEntries.systemEntries(home, evoshellBin)
            return
        }
        commandEntries = []
    }

    function entryIconSource(entry) {
        if (!entry) return ""
        if (entry.iconSource)
            return entry.iconSource
        if (entry.id && root.appIconMap[entry.id])
            return root.appIconMap[entry.id]
        var iconName = ""
        if (entry.entryRef && entry.entryRef.icon)
            iconName = String(entry.entryRef.icon)
        if (iconName && root.appIconMap[iconName])
            return root.appIconMap[iconName]
        var src = Util.iconSourceForName(iconName)
        if (src)
            return src
        if (entry.id)
            return Util.iconSourceForName(String(entry.id))
        return ""
    }

    function applyAppIconMap(raw) {
        var map = {}
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var tab = line.indexOf("\t")
            if (tab === -1) continue
            map[line.slice(0, tab)] = line.slice(tab + 1)
        }
        root.appIconMap = map
        var rebuilt = []
        for (var j = 0; j < root.cachedApps.length; j++) {
            var app = root.cachedApps[j]
            rebuilt.push({
                kind: app.kind,
                name: app.name,
                id: app.id,
                entryRef: app.entryRef,
                iconSource: (app.id && map[app.id]) ? map[app.id] : (app.iconSource || "")
            })
        }
        root.cachedApps = rebuilt
        root.appIconEpoch++
        root.visibleEntries = root.filteredEntries()
        rebuildSectionMenuLayout()
    }

    function entryGlyphIcon(entry) {
        if (!entry) return "󰍉"
        if (entry.icon) return entry.icon
        return "󰍉"
    }

    function rebuildAppCache() {
        var list = []
        try {
            var values = DesktopEntries.applications.values || []
            for (var i = 0; i < values.length; i++) {
                var entry = values[i]
                if (!entry || !entry.id) continue
                var item = {
                    kind: "app",
                    name: String(entry.name || entry.id),
                    id: entry.id,
                    entryRef: entry,
                    iconSource: root.appIconMap[entry.id] || ""
                }
                list.push(item)
            }
        } catch (e) {
            console.warn("evo.sys.menu app list failed:", e)
        }
        cachedApps = list
        loadAppIcons()
        rebuildSectionMenuLayout()
    }

    function loadAppIcons() {
        var listScript = Util.evoshellScript(home, shell, "evo-menu-list")
        loadAppIconsProc.command = ["bash", "-lc",
            "test -x " + Util.shellQuote(listScript) + " && " +
            Util.shellQuote(listScript) + " icons"
        ]
        if (!loadAppIconsProc.running)
            loadAppIconsProc.running = true
    }

    function appEntries() {
        if (cachedApps.length === 0)
            rebuildAppCache()
        return cachedApps
    }

    function entryListsEqual(a, b) {
        if (!a || !b || a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) {
            if ((a[i].id || a[i].name) !== (b[i].id || b[i].name))
                return false
        }
        return true
    }

    function rebuildSizingEntryCount() {
        var q = filterText.trim()
        var count = 0
        if (submenu) {
            count = dynamicEntries.length
        } else if (mode === "power") {
            count = q === ""
                ? Math.max(cachedApps.length, commandEntries.length)
                : commandEntries.length
        } else if (mode === "runner") {
            count = visibleEntries.length
        } else {
            count = visibleEntries.length
        }
        sizingEntryCount = count
    }

    function syncVisibleEntries() {
        visibleEntries = filteredEntries()
        rebuildSizingEntryCount()
    }

    function refreshVisibleEntries() {
        syncVisibleEntries()
    }

    function filteredEntries() {
        if (submenu) {
            if (dynamicEntries.length === 0) return []
            return dynamicEntries.map(function(e) {
                if (root.infoListMode) {
                    return {
                        kind: "info",
                        name: e.name,
                        keys: e.keys || e.command || "",
                        detail: e.detail || "",
                        files: e.files || "",
                        icon: root.submenu === "bindings" ? "󰌌" : "󰆍"
                    }
                }
                return {
                    kind: "command",
                    name: e.name,
                    command: e.command,
                    submenu: e.submenu,
                    preview: e.preview || "",
                    icon: e.icon || ""
                }
            })
        }
        var out = []
        if (mode === "runner") {
            var apps = sortedApps()
            var query = filterText.trim()
            var runnerOut = []
            for (var r = 0; r < apps.length; r++) {
                if (query && !MenuEntries.matchesQuery(apps[r], query))
                    continue
                runnerOut.push(apps[r])
            }
            return runnerOut
        }
        if (mode === "power") {
            var sections = powerSectionEntries()
            var out = []
            for (var i = 0; i < sections.length; i++) {
                for (var j = 0; j < sections[i].entries.length; j++)
                    out.push(sections[i].entries[j])
            }
            return out
        }
        return []
    }

    function runCommand(cmd) {
        var command = String(cmd || "").trim()
        if (!command) return
        Quickshell.execDetached(["bash", "-lc", command])
        dismiss()
    }

    function launchDesktopEntry(entryRef, id) {
        // Quickshell execute() ignores runInTerminal; gtk-launch respects Terminal=true.
        if (entryRef && entryRef.runInTerminal)
            Quickshell.execDetached(["gtk-launch", String(id)])
        else if (entryRef && typeof entryRef.execute === "function")
            entryRef.execute()
        else
            Quickshell.execDetached(["gtk-launch", String(id)])
    }

    function activateEntry(entry) {
        if (!entry) return
        if (entry.kind === "app") {
            launchDesktopEntry(entry.entryRef, entry.id)
            dismiss()
            return
        }
        if (entry.kind === "submenu" && entry.submenu) {
            submenu = entry.submenu
            filterText = ""
            selectedIndex = 0
            loadDynamicEntries(entry.submenu)
            Qt.callLater(function() {
                root.previewAreaMaxWidth = panel.previewAreaMaxWidth
                root.previewAreaMaxHeight = panel.previewAreaMaxHeight
                if (entry.submenu === "themes" || entry.submenu === "wallpaper")
                    menuHost.forceActiveFocus()
                else
                    root.focusSearchField()
            })
            return
        }
        if (entry.kind === "mode" && entry.mode) {
            mode = String(entry.mode)
            submenu = ""
            filterText = ""
            selectedIndex = 0
            refreshCommandEntries()
            dynamicEntries = []
            if (mode === "power" || mode === "runner")
                rebuildAppCache()
            refreshVisibleEntries()
            Qt.callLater(function() {
                root.previewAreaMaxWidth = panel.previewAreaMaxWidth
                root.previewAreaMaxHeight = panel.previewAreaMaxHeight
                root.focusSearchField()
            })
            return
        }
        if (entry.kind === "info")
            return
        if (entry.command) runCommand(entry.command)
    }

    function warmPreviewCache() {
        var warmScript = Util.evoshellScript(home, shell, "evo-menu-warm")
        previewWarmProc.command = ["bash", "-lc", "test -x " + Util.shellQuote(warmScript) + " && " + Util.shellQuote(warmScript)]
        previewWarmProc.running = true
    }

    function loadDynamicEntries(kind) {
        dynamicLoading = true
        dynamicEntries = []
        dynamicEntryKind = kind
        var listScript = Util.evoshellScript(home, shell, "evo-menu-list")
        if (kind !== "themes" && kind !== "wallpaper" && kind !== "bindings" && kind !== "shell") {
            dynamicLoading = false
            dynamicEntryKind = ""
            return
        }
        dynamicProc.command = ["bash", "-lc",
            "test -x " + Util.shellQuote(listScript) + " && " +
            Util.shellQuote(listScript) + " " + kind
        ]
        dynamicProc.running = true
    }

    function parseDynamicLines(raw) {
        var lines = String(raw || "").split("\n")
        var out = []
        var infoMode = root.dynamicEntryKind === "bindings" || root.dynamicEntryKind === "shell"
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var tab = line.indexOf("\t")
            if (tab === -1) {
                out.push({ name: line, command: line, preview: "" })
            } else {
                var parts = line.split("\t")
                if (infoMode && parts.length >= 2) {
                    var isShell = root.dynamicEntryKind === "shell"
                    out.push({
                        name: parts[0] || "",
                        keys: parts[1] || "",
                        detail: parts.length >= 3 ? parts[2] || "" : "",
                        files: parts.length >= 4 ? parts[3] || "" : "",
                        internal: isShell && parts.length >= 5 && parts[4] === "1"
                    })
                } else if (parts.length === 2 && parts[1].indexOf("/") < 0 && parts[1].indexOf("evo-") !== 0) {
                    out.push({ name: parts[0] || "", keys: parts[1] || "" })
                } else {
                    out.push({
                        name: parts[0] || "",
                        command: parts[1] || "",
                        preview: parts[2] || ""
                    })
                }
            }
        }
        dynamicEntries = out
        dynamicLoading = false
        Qt.callLater(function() {
            root.previewAreaMaxWidth = panel.previewAreaMaxWidth
            root.previewAreaMaxHeight = panel.previewAreaMaxHeight
        })
    }

    component PowerMenuSection: SectionPanel {
        required property var sectionData

        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.alignment: Qt.AlignTop
        visible: sectionData !== null
        notchLegend: true
        legendText: sectionData ? sectionData.title : ""
        legendIcon: sectionData ? sectionData.icon : ""
        legendBackground: Theme.background
        label: ""
        sectionSpacing: 4

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: sectionData ? sectionData.entries : []

                Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.powerLinkRowHeight
                    radius: Theme.fieldsetCornerRadius
                    color: powerRowMouse.containsMouse || powerGlobalIndex === root.selectedIndex
                        ? Theme.withOpacity(Theme.panelMantle, 0.95)
                        : "transparent"
                    opacity: root.entrySearchOpacity(modelData, powerGlobalIndex)

                    readonly property int powerGlobalIndex: modelData.globalIndex

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Item {
                            Layout.preferredWidth: root.powerLinkIconSize
                            Layout.preferredHeight: root.powerLinkIconSize
                            Layout.alignment: Qt.AlignVCenter
                            readonly property string rowIconSource: {
                                if (modelData.kind !== "app")
                                    return ""
                                var _epoch = root.appIconEpoch
                                return root.entryIconSource(modelData)
                            }

                            Image {
                                id: rowIconImage
                                anchors.fill: parent
                                visible: parent.rowIconSource.length > 0
                                    && status !== Image.Error
                                source: Util.normalizeIconSource(parent.rowIconSource)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                cache: true
                                sourceSize: Qt.size(
                                    root.powerLinkIconSize * 2, root.powerLinkIconSize * 2)
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.kind !== "app"
                                    || parent.rowIconSource.length === 0
                                    || rowIconImage.status === Image.Error
                                text: modelData.icon || "󰍉"
                                color: powerGlobalIndex === root.selectedIndex
                                    ? Theme.accent : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: root.powerLinkIconSize
                                font.bold: Theme.fontBold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.name
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.programEntryFontSize
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: powerRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = powerGlobalIndex
                        onClicked: {
                            root.selectedIndex = powerGlobalIndex
                            root.activateEntry(modelData)
                        }
                    }
                }
            }
        }
    }

    Process {
        id: dynamicProc
        stdout: StdioCollector {
            onStreamFinished: root.parseDynamicLines(text)
        }
        onExited: root.dynamicLoading = false
    }

    Process {
        id: previewWarmProc
    }

    Process {
        id: loadAppIconsProc
        stdout: StdioCollector {
            onStreamFinished: root.applyAppIconMap(text)
        }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "evo-sys-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        readonly property real previewAreaMaxWidth: {
            var screenW = width > 0 ? width : (Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920)
            return Math.max(root.previewTileWidth * 3, screenW - root.previewMenuMargin * 2)
        }
        readonly property real previewAreaMaxHeight: {
            var screenH = height > 0 ? height : (Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080)
            return Math.max(root.previewTileHeight * 2, screenH - root.previewMenuMargin * 2)
        }

        onWidthChanged: {
            root.previewAreaMaxWidth = previewAreaMaxWidth
        }
        onHeightChanged: {
            root.previewAreaMaxHeight = previewAreaMaxHeight
        }
        Component.onCompleted: {
            root.previewAreaMaxWidth = previewAreaMaxWidth
            root.previewAreaMaxHeight = previewAreaMaxHeight
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Item {
            id: menuHost
            z: 1
            anchors.centerIn: parent
            width: root.framedMode
                ? root.framedMenuWidth
                : root.boxRowWidth
            height: root.framedMode
                ? (root.fixedFramedMenuHeight
                    ? root.framedMenuPanelHeight
                    : root.menuOuterTopInset + framedColumn.implicitHeight + root.menuOuterInset)
                : root.boxRowHeight
            focus: root.opened && (root.previewTileMode || root.framedMode)

            TextInput {
                id: filterField
                visible: false
                width: 0
                height: 0
                opacity: 0
                text: root.filterText
                onTextEdited: root.filterText = text
            }

            Keys.onEscapePressed: root.handleEscapeKey()
            Keys.onLeftPressed: root.handlePreviewLeft()
            Keys.onRightPressed: root.handlePreviewRight()
            Keys.onUpPressed: root.handlePreviewUp()
            Keys.onDownPressed: root.handlePreviewDown()
            Keys.onReturnPressed: root.handleActivateKey()
            Keys.onPressed: function(event) {
                if (!root.framedMode)
                    return
                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    if (!root.showMainMenuTabs)
                        return
                    root.cycleMainMenuTab(event.modifiers & Qt.ShiftModifier
                        || event.key === Qt.Key_Backtab)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Backspace) {
                    root.trimFilterText()
                    event.accepted = true
                    return
                }
                if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                    return
                var text = event.text
                if (!text || text.length === 0 || event.isAutoRepeat)
                    return
                root.appendFilterText(text)
                event.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                visible: root.framedMode
                color: Theme.background
                border.color: Theme.accent
                border.width: Theme.hoverPanelBorderWidth
                radius: 0
            }

            ColumnLayout {
                id: framedColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: root.framedMode ? root.menuOuterTopInset : 0
                anchors.leftMargin: root.framedMode ? root.menuOuterInset : 0
                anchors.rightMargin: root.framedMode ? root.menuOuterInset : 0
                spacing: root.framedColumnSpacing
                clip: false

                SettingsTabBar {
                    id: mainMenuTabs
                    visible: root.showMainMenuTabs
                    Layout.fillWidth: true
                    tabs: root.mainTabModel
                    currentIndex: root.menuTabIndex
                    onTabActivated: function(index) {
                        root.activateMainMenuTab(index)
                    }
                }

                SettingsModule {
                    id: embeddedSettings
                    visible: root.showSettingsTab
                    showTabBar: false
                    tabIndex: root.menuTabIndex - 1
                    menuFilterText: root.filterText
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    Layout.preferredHeight: root.powerMenuViewportHeight
                    Layout.maximumHeight: root.powerMenuViewportHeight
                    host: settingsHost
                    shell: root.shell
                }

                Text {
                    visible: root.framedMode && !root.showSettingsTab && root.dynamicLoading
                    text: "Loading…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFontSize
                    font.bold: Theme.fontBold
                }

                Text {
                    visible: (root.runnerMenuMode || root.sectionMenuMode) && !root.dynamicLoading && root.visibleEntries.length === 0
                    Layout.alignment: Qt.AlignHCenter
                    text: root.filterText.trim() === "" ? "No entries" : "No matches"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    font.bold: Theme.fontBold
                    opacity: Theme.opacityMuted
                }

                Flickable {
                    id: sectionListFlickable
                    visible: root.sectionMenuMode && root.visibleEntries.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.powerMenuViewportHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: sectionColumn.height

                    Item {
                        id: sectionColumn
                        width: parent.width
                        height: Math.max(
                            programsSectionsColumn.implicitHeight,
                            gamesSectionsColumn.implicitHeight,
                            panelsSectionsColumn.implicitHeight,
                            rightSectionsColumn.implicitHeight)

                        RowLayout {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: root.powerSectionSpacing

                            ColumnLayout {
                                id: programsSectionsColumn
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignTop
                                spacing: root.powerSectionSpacing

                                Repeater {
                                    model: root.sectionLayoutPrograms

                                    PowerMenuSection {
                                        required property var modelData
                                        sectionData: modelData
                                    }
                                }
                            }

                            ColumnLayout {
                                id: gamesSectionsColumn
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignTop
                                spacing: root.powerSectionSpacing

                                Repeater {
                                    model: root.sectionLayoutGames

                                    PowerMenuSection {
                                        required property var modelData
                                        sectionData: modelData
                                    }
                                }
                            }

                            ColumnLayout {
                                id: panelsSectionsColumn
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignTop
                                spacing: root.powerSectionSpacing

                                Repeater {
                                    model: root.sectionLayoutPanels

                                    PowerMenuSection {
                                        required property var modelData
                                        sectionData: modelData
                                    }
                                }
                            }

                            ColumnLayout {
                                id: rightSectionsColumn
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignTop
                                spacing: root.powerSectionSpacing

                                Repeater {
                                    model: root.sectionLayoutRight

                                    PowerMenuSection {
                                        required property var modelData
                                        sectionData: modelData
                                    }
                                }
                            }
                        }
                    }
                }

                SectionPanel {
                    visible: root.framedMode && !root.showSettingsTab && !root.sectionMenuMode
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    fillHeight: false
                    notchLegend: true
                    legendText: root.runnerMenuMode ? "Run"
                        : (root.submenu === "bindings" ? "Bindings" : "Shell commands")
                    legendIcon: root.runnerMenuMode ? "󰜎"
                        : (root.submenu === "bindings" ? "󰌌" : "󰆍")
                    legendBackground: Theme.background
                    label: ""
                    sectionSpacing: root.framedColumnSpacing

                    ListView {
                        id: entryList
                        visible: root.framedMode && !root.sectionMenuMode && !root.showSettingsTab
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.runnerMenuMode
                            ? root.runnerViewportHeight
                            : root.framedListHeight
                        clip: true
                        model: root.visibleEntries
                        currentIndex: root.selectedIndex

                        onCountChanged: if (root.selectedIndex >= count) root.selectedIndex = Math.max(0, count - 1)

                        delegate: Rectangle {
                            id: entryRow
                            required property var modelData
                            required property int index
                            width: entryList.width
                            height: entryRow.infoRow ? root.infoListRowHeight : root.listRowHeight
                            clip: false
                            radius: Theme.fieldsetCornerRadius
                            color: index === entryList.currentIndex || mouseArea.containsMouse ? Theme.panelMantle : "transparent"
                            opacity: root.entrySearchOpacity(modelData, index)

                            readonly property string appIconSource: {
                                var _epoch = root.appIconEpoch
                                return root.entryIconSource(modelData)
                            }
                            readonly property string glyphIcon: root.entryGlyphIcon(modelData)
                            readonly property bool infoRow: modelData.kind === "info"
                            readonly property string keysLabel: String(modelData.keys || "")
                            readonly property int rowFontSize: entryRow.infoRow
                                ? root.infoListFontSize
                                : (root.runnerMenuMode ? root.programEntryFontSize : root.listFontSize)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: entryRow.infoRow ? 16 : 12

                                Item {
                                    visible: !entryRow.infoRow
                                    Layout.preferredWidth: root.listIconSize
                                    Layout.preferredHeight: root.listIconSize
                                    Layout.alignment: Qt.AlignVCenter

                                    Image {
                                        anchors.fill: parent
                                        visible: entryRow.appIconSource.length > 0
                                        source: Util.normalizeIconSource(entryRow.appIconSource)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        asynchronous: true
                                        cache: true
                                        sourceSize: Qt.size(root.listIconSize * 2, root.listIconSize * 2)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: entryRow.appIconSource.length === 0
                                        text: entryRow.glyphIcon
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.listIconSize
                                        font.bold: Theme.fontBold
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: entryRow.infoRow ? 1 : 0
                                    Layout.alignment: Qt.AlignVCenter
                                    text: modelData.name
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: entryRow.rowFontSize
                                    font.bold: Theme.fontBold
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    visible: entryRow.infoRow && entryRow.keysLabel !== ""
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.alignment: Qt.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: entryRow.keysLabel
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: entryRow.rowFontSize
                                    font.bold: Theme.fontBold
                                    opacity: Theme.opacitySecondary
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = index
                                onClicked: {
                                    root.selectedIndex = index
                                    root.activateEntry(modelData)
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: infoDetailPanel
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.infoDetailVisible ? root.infoDetailHeight : 0
                        visible: root.infoDetailVisible
                        color: Theme.panelMantle
                        radius: Theme.fieldsetCornerRadius
                        clip: false

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 12
                            contentHeight: infoDetailColumn.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: infoDetailColumn
                                width: parent.width
                                spacing: 8

                                Text {
                                    width: parent.width
                                    visible: root.selectedDetail.length > 0
                                    text: root.selectedDetail
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    font.bold: Theme.fontBold
                                    wrapMode: Text.WordWrap
                                    opacity: Theme.opacityMuted
                                }

                                Text {
                                    width: parent.width
                                    visible: root.selectedFiles.length > 0
                                    text: {
                                        var lines = ["Related:"]
                                        for (var i = 0; i < root.selectedFiles.length; i++)
                                            lines.push("󰉋 " + root.shortenMenuPath(root.selectedFiles[i]))
                                        return lines.join("\n")
                                    }
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.bold: Theme.fontBold
                                    wrapMode: Text.WordWrap
                                    opacity: Theme.opacitySecondary
                                    lineHeight: 1.35
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.dynamicLoading && !root.framedMode
                    text: "Loading…"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.listFontSize
                    font.bold: Theme.fontBold
                }

                Flow {
                    id: previewFlow
                    visible: root.previewTileMode
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.previewGridWidth
                    Layout.preferredHeight: root.previewGridHeight
                    spacing: root.tileSpacing
                    flow: Flow.LeftToRight

                    Repeater {
                        model: root.visibleEntries

                        Rectangle {
                            required property var modelData
                            required property int index
                            width: root.previewTileWidth
                            height: root.previewTileHeight
                            color: Theme.overlaySurface
                            border.color: index === root.selectedIndex ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                            border.width: index === root.selectedIndex ? 2 : 1
                            opacity: root.entrySearchOpacity(modelData, index)

                            Item {
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true

                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    source: Util.fileUrl(modelData.preview)
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    cache: false
                                    mipmap: true
                                    sourceSize: Qt.size(
                                        Math.ceil(root.previewTileWidth * root.previewDpr),
                                        Math.ceil(root.previewImageHeight * root.previewDpr)
                                    )
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.overlaySurface
                                    visible: !modelData.preview || previewImage.status === Image.Error
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !modelData.preview || previewImage.status === Image.Error
                                    text: root.previewFallbackIcon
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.tileIconSize
                                    font.bold: Theme.fontBold
                                }
                            }

                            MouseArea {
                                id: previewMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.selectedIndex = index
                                    root.activateEntry(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: settingsHost
        property bool opened: root.opened
        property string activeModule: "settings"
        property bool settingsEmbedded: root.showSettingsTab
        function dismiss() { root.dismiss() }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            rebuildAppCache()
            if (sectionMenuMode || runnerMenuMode)
                syncVisibleEntries()
        }
    }

    Connections {
        target: shell
        function onPluginOverlayChanged() {
            rebuildSectionMenuLayout()
        }
    }

    Component.onCompleted: {
        refreshCommandEntries()
        rebuildSectionMenuLayout()
        rebuildSizingEntryCount()
        Qt.callLater(rebuildAppCache)
        Qt.callLater(warmPreviewCache)
    }
}
