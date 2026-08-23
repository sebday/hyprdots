import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../commons"
import "../../pluginManifest.js" as PluginManifest

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property var trayOverrides: {
        if (bar && bar.barConfig && bar.barConfig.trayWidgets)
            return bar.barConfig.trayWidgets
        return ({})
    }

    function mergeWidgetSettings(name, baseValue) {
        var over = trayOverrides[name]
        if ((name === "volume" || name === "media") && over === undefined && trayOverrides.audio === false)
            return false
        if (over === false)
            return false
        if (over && typeof over === "object") {
            if (baseValue && typeof baseValue === "object") {
                var merged = {}
                var key
                for (key in baseValue)
                    merged[key] = baseValue[key]
                for (key in over)
                    merged[key] = over[key]
                return merged
            }
            return over
        }
        return baseValue
    }

    readonly property var orderedTrayWidgets: {
        if (shell && shell.trayWidgetOrder)
            return shell.trayWidgetOrder
        return PluginManifest.defaultTrayWidgetOrder(shell ? shell.pluginOverlay : ({}))
    }

    readonly property var trayWidgetNames: orderedTrayWidgets.slice()

    function baseWidgetSettings(name) {
        if ((name === "volume" || name === "media") && settings && settings.audio !== undefined)
            return settings.audio
        if (settings && settings[name] !== undefined)
            return settings[name]
        return undefined
    }

    readonly property var effectiveSettings: {
        var out = {}
        var names = root.trayWidgetNames
        var i, name, key
        if (settings) {
            for (key in settings)
                out[key] = settings[key]
        }
        for (i = 0; i < names.length; i++) {
            name = names[i]
            if (name in trayOverrides || out[name] !== undefined || baseWidgetSettings(name) !== undefined)
                out[name] = mergeWidgetSettings(name, baseWidgetSettings(name))
        }
        return out
    }

    readonly property real dpr: barPanel ? barPanel.devicePixelRatio : 1.0
    readonly property int trayIconSize: 18
    readonly property int traySpacing: 12
    readonly property int trayIconSource: Math.max(trayIconSize, Math.round(trayIconSize * dpr))
    readonly property int trayCellWidth: trayIconSize + traySpacing
    readonly property bool showWeather: effectiveSettings.weather !== false
    readonly property bool showCursor: effectiveSettings.cursor !== false
    readonly property bool showGithub: effectiveSettings.github != null && effectiveSettings.github !== false
    readonly property bool showStocks: effectiveSettings.stocks != null && effectiveSettings.stocks !== false
    readonly property bool showCloudflare: effectiveSettings.cloudflare != null && effectiveSettings.cloudflare !== false
    readonly property bool showHomeAssistant: effectiveSettings.homeAssistant != null && effectiveSettings.homeAssistant !== false
    readonly property bool showVolume: effectiveSettings.volume !== false
    readonly property bool showMedia: effectiveSettings.media !== false
    readonly property bool showNotifications: effectiveSettings.notifications !== false
    readonly property bool showNetwork: effectiveSettings.network !== false
    readonly property bool showWorkspaces: {
        var chrome = bar && bar.barConfig && bar.barConfig.barWidgets ? bar.barConfig.barWidgets.workspaces : null
        return !chrome || chrome.enabled !== false
    }

    implicitWidth: trayRow.implicitWidth + Theme.barSectionGap
    implicitHeight: Theme.barHeight

    function traySlotActive(show, loader) {
        if (!show || !loader || !loader.item)
            return false
        if (loader.item.trayHasContent !== undefined)
            return loader.item.trayHasContent
        return true
    }

    function evoshellScript(name) {
        return Util.evoshellScript(
            root.shell ? root.shell.home : Quickshell.env("HOME"),
            root.shell,
            name)
    }

    function mergeSettings(base, fallbackHover) {
        var out = {}
        if (base && typeof base === "object") {
            for (var key in base)
                out[key] = base[key]
        }
        if (!out.onHover && fallbackHover)
            out.onHover = fallbackHover
        if (!out.exec && fallbackHover === "evo.panels.cursor") {
            out.exec = evoshellScript("evo-bar-cursor-usage-bar")
            if (!out.interval)
                out.interval = 300
            if (!out.onClickRight)
                out.onClickRight = evoshellScript("evo-bar-cursor-usage") + " open"
        }
        if (!out.exec && fallbackHover === "evo.panels.weather")
            out.exec = evoshellScript("evo-bar-weather-bar")
        out.trayMode = true
        out.trayIconSize = root.trayIconSize
        out.trayCellWidth = root.trayCellWidth
        return out
    }

    function wireBarWidget(item, entrySettings, fallbackHover) {
        if (!item) return
        if ("bar" in item) item.bar = root.bar
        if ("barPanel" in item) item.barPanel = root.barPanel
        if ("shell" in item) item.shell = root.shell
        if ("settings" in item) item.settings = mergeSettings(entrySettings, fallbackHover)
        if (typeof item.restartPolling === "function") item.restartPolling()
    }

    function trayHoverPanelId(trayItem) {
        if (!trayItem)
            return ""
        var key = String(trayItem.id || trayItem.title || "").toLowerCase()
        if (key.indexOf("insync") >= 0)
            return "evo.panels.insync"
        if (key.indexOf("steam") >= 0)
            return "evo.panels.steam"
        return ""
    }

    function setTrayHoverPanel(trayItem, trayCell, active) {
        var popupId = root.trayHoverPanelId(trayItem)
        if (!popupId || !root.shell)
            return
        if (active)
            root.shell.hoverEnter(popupId, trayCell, root.barPanel)
        else
            root.shell.hoverLeave(popupId)
    }

    function openSteamClient() {
        Util.dismissHoverPanelFromBar(root.shell, "evo.panels.steam")
        Quickshell.execDetached([Util.evoshellScript(root.shell ? root.shell.home : Quickshell.env("HOME"), root.shell, "evo-bar-steam"), "open"])
    }

    function slotComponent(widgetId) {
        switch (widgetId) {
        case "workspaces": return workspacesSlotComp
        case "volume": return volumeSlotComp
        case "media": return mediaSlotComp
        case "weather": return weatherSlotComp
        case "github": return githubSlotComp
        case "cursor": return cursorSlotComp
        case "notifications": return notificationsSlotComp
        case "stocks": return stocksSlotComp
        case "cloudflare": return cloudflareSlotComp
        case "homeAssistant": return homeAssistantSlotComp
        case "network": return networkSlotComp
        default:
            if (shell && shell.extensionTrayWidgets && shell.extensionTrayWidgets[widgetId])
                return extensionSlotComp
            return null
        }
    }

    function wireTraySlot(widgetId, slot) {
        if (!slot)
            return
        switch (widgetId) {
        case "workspaces":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.workspaces, "evo.panels.workspaces")
            break
        case "volume":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.volume, "evo.panels.media.volume")
            break
        case "media":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.media, "evo.panels.media.now-playing")
            break
        case "weather":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.weather, "evo.panels.weather")
            break
        case "github":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.github, "evo.panels.github")
            break
        case "cursor":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.cursor, "evo.panels.cursor")
            break
        case "notifications":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.notifications, "evo.panels.notifications")
            break
        case "stocks":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.stocks, "evo.panels.stocks")
            break
        case "cloudflare":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.cloudflare, "evo.panels.cloudflare")
            break
        case "homeAssistant":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.homeAssistant, "evo.panels.homeassistant")
            break
        case "network":
            if (slot.loader && slot.loader.item)
                wireBarWidget(slot.loader.item, effectiveSettings.network, "evo.panels.network.stats")
            break
        default:
            if (slot.trayLoader && slot.trayLoader.item)
                wireBarWidget(slot.trayLoader.item, effectiveSettings[widgetId], slot.hoverFallback)
            break
        }
    }

    function rewireTrayWidgets() {
        var i, loader
        for (i = 0; i < trayOrderRepeater.count; i++) {
            loader = trayOrderRepeater.itemAt(i)
            if (!loader || !loader.item)
                continue
            wireTraySlot(loader.widgetId, loader.item)
        }
    }

    onSettingsChanged: rewireTrayWidgets()
    onTrayOverridesChanged: rewireTrayWidgets()
    onShellChanged: rewireTrayWidgets()
    onOrderedTrayWidgetsChanged: rewireTrayWidgets()

    TrayContextMenu {
        id: trayContextMenu
        bar: root.bar
        barPanel: root.barPanel
    }

    Component { id: commandComp; CommandWidget {} }
    Component { id: githubComp; GitHubWidget {} }
    Component { id: stocksComp; StocksWidget {} }
    Component { id: cloudflareComp; CloudflareWidget {} }
    Component { id: homeAssistantComp; HomeAssistantWidget {} }
    Component { id: mediaComp; MediaWidget {} }
    Component { id: volumeComp; VolumeWidget {} }
    Component { id: notificationsComp; NotificationsWidget {} }
    Component { id: networkComp; NetworkWidget {} }
    Component { id: workspacesComp; WorkspacesWidget {} }

    Component {
        id: workspacesSlotComp
        Item {
            property alias loader: workspacesLoader
            readonly property bool slotActive: root.traySlotActive(root.showWorkspaces, workspacesLoader)
            implicitWidth: slotActive && workspacesLoader.item ? workspacesLoader.item.implicitWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: workspacesLoader
                anchors.verticalCenter: parent.verticalCenter
                active: root.showWorkspaces
                sourceComponent: workspacesComp
                onLoaded: root.wireBarWidget(
                    item,
                    root.effectiveSettings.workspaces,
                    "evo.panels.workspaces")
            }
        }
    }

    Component {
        id: volumeSlotComp
        Item {
            property alias loader: volumeLoader
            readonly property bool slotActive: root.traySlotActive(root.showVolume, volumeLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: volumeLoader
                anchors.fill: parent
                active: root.showVolume
                sourceComponent: volumeComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.volume, "evo.panels.media.volume")
            }
        }
    }

    Component {
        id: mediaSlotComp
        Item {
            property alias loader: mediaLoader
            readonly property bool slotActive: root.traySlotActive(root.showMedia, mediaLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: mediaLoader
                anchors.fill: parent
                active: root.showMedia
                sourceComponent: mediaComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.media, "evo.panels.media.now-playing")
            }
        }
    }

    Component {
        id: weatherSlotComp
        Item {
            property alias loader: weatherLoader
            readonly property bool slotActive: root.traySlotActive(root.showWeather, weatherLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: weatherLoader
                anchors.fill: parent
                active: root.showWeather
                sourceComponent: commandComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.weather, "evo.panels.weather")
            }
        }
    }

    Component {
        id: githubSlotComp
        Item {
            property alias loader: githubLoader
            readonly property bool slotActive: root.traySlotActive(root.showGithub, githubLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: githubLoader
                anchors.fill: parent
                active: root.showGithub
                sourceComponent: githubComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.github, "evo.panels.github")
            }
        }
    }

    Component {
        id: cursorSlotComp
        Item {
            property alias loader: cursorLoader
            readonly property bool slotActive: root.traySlotActive(root.showCursor, cursorLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: cursorLoader
                anchors.fill: parent
                active: root.showCursor
                sourceComponent: commandComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.cursor, "evo.panels.cursor")
            }
        }
    }

    Component {
        id: notificationsSlotComp
        Item {
            property alias loader: notificationsLoader
            readonly property bool slotActive: root.traySlotActive(root.showNotifications, notificationsLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: notificationsLoader
                anchors.fill: parent
                active: root.showNotifications
                sourceComponent: notificationsComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.notifications, "evo.panels.notifications")
            }
        }
    }

    Component {
        id: stocksSlotComp
        Item {
            property alias loader: stocksLoader
            readonly property bool slotActive: root.traySlotActive(root.showStocks, stocksLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: stocksLoader
                anchors.fill: parent
                active: root.showStocks
                sourceComponent: stocksComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.stocks, "evo.panels.stocks")
            }
        }
    }

    Component {
        id: cloudflareSlotComp
        Item {
            property alias loader: cloudflareLoader
            readonly property bool slotActive: root.traySlotActive(root.showCloudflare, cloudflareLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: cloudflareLoader
                anchors.fill: parent
                active: root.showCloudflare
                sourceComponent: cloudflareComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.cloudflare, "evo.panels.cloudflare")
            }
        }
    }

    Component {
        id: homeAssistantSlotComp
        Item {
            property alias loader: homeAssistantLoader
            readonly property bool slotActive: root.traySlotActive(root.showHomeAssistant, homeAssistantLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: homeAssistantLoader
                anchors.fill: parent
                active: root.showHomeAssistant
                sourceComponent: homeAssistantComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.homeAssistant, "evo.panels.homeassistant")
            }
        }
    }

    Component {
        id: networkSlotComp
        Item {
            property alias loader: networkLoader
            readonly property bool slotActive: root.traySlotActive(root.showNetwork, networkLoader)
            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: networkLoader
                anchors.fill: parent
                active: root.showNetwork
                sourceComponent: networkComp
                onLoaded: root.wireBarWidget(item, root.effectiveSettings.network, "evo.panels.network.stats")
            }
        }
    }

    Component {
        id: extensionSlotComp
        Item {
            property string widgetId: ""
            readonly property var widgetMeta: root.shell.extensionTrayWidgets[widgetId] || ({})
            readonly property string hoverFallback: widgetMeta.onHover ? String(widgetMeta.onHover) : ""
            readonly property bool showWidget: {
                var over = root.effectiveSettings[widgetId]
                return over != null && over !== false
            }
            readonly property bool slotActive: root.traySlotActive(showWidget, trayLoader)

            implicitWidth: slotActive ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: implicitWidth > 0

            Loader {
                id: trayLoader
                anchors.fill: parent
                active: parent.showWidget
                source: root.shell ? root.shell.pluginUrl(parent.widgetMeta) : ""
                onLoaded: root.wireBarWidget(item, root.effectiveSettings[parent.widgetId], parent.hoverFallback)
            }
        }
    }

    Row {
        id: trayRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        spacing: root.traySpacing
        height: Theme.barHeight

        Repeater {
            id: trayOrderRepeater
            model: root.orderedTrayWidgets

            delegate: Loader {
                required property string modelData
                readonly property string widgetId: modelData
                active: sourceComponent !== null
                sourceComponent: root.slotComponent(widgetId)
                width: item ? item.implicitWidth : 0
                height: Theme.barHeight
                visible: width > 0

                onLoaded: {
                    if (item.widgetId !== undefined)
                        item.widgetId = widgetId
                    root.wireTraySlot(widgetId, item)
                }
            }
        }

        Repeater {
            model: SystemTray.items

            Item {
                id: trayCell
                required property var modelData
                readonly property bool sniSlotActive: traySni.trayHasContent
                width: sniSlotActive ? root.trayCellWidth : 0
                height: Theme.barHeight
                visible: sniSlotActive

                TraySniWidget {
                    id: traySni
                    anchors.centerIn: parent
                    trayItem: modelData
                    iconSize: root.trayIconSize
                    iconSourceSize: root.trayIconSource
                }

                MouseArea {
                    id: sniMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onContainsMouseChanged: root.setTrayHoverPanel(modelData, trayCell, containsMouse)
                    onClicked: function(mouse) {
                        if (!modelData) return
                        if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                            return
                        }
                        if (mouse.button === Qt.RightButton) {
                            var popupId = root.trayHoverPanelId(modelData)
                            if (popupId && Util.pinHoverPanelFromBarIfActive(root.shell, popupId))
                                return
                            if (modelData.hasMenu) {
                                trayContextMenu.open(modelData.menu, trayCell)
                                return
                            }
                        }
                        if (modelData.onlyMenu && modelData.hasMenu) {
                            trayContextMenu.open(modelData.menu, trayCell)
                            return
                        }
                        if (mouse.button === Qt.LeftButton
                                && root.trayHoverPanelId(modelData) === "evo.panels.steam") {
                            root.openSteamClient()
                            return
                        }
                        modelData.activate()
                    }
                }

            }
        }
    }
}
