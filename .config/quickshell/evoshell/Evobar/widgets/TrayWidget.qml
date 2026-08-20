import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})

    readonly property real dpr: barPanel ? barPanel.devicePixelRatio : 1.0
    readonly property int trayIconSize: 18
    readonly property int traySpacing: 12
    readonly property int trayIconSource: Math.max(trayIconSize, Math.round(trayIconSize * dpr))
    readonly property int trayCellWidth: trayIconSize + traySpacing
    readonly property bool showWeather: settings.weather !== false
    readonly property bool showCursor: settings.cursor !== false
    readonly property bool showGithub: settings.github != null && settings.github !== false
    readonly property bool showStocks: settings.stocks != null && settings.stocks !== false
    readonly property bool showCloudflare: settings.cloudflare != null && settings.cloudflare !== false
    readonly property bool showHomeAssistant: settings.homeAssistant != null && settings.homeAssistant !== false
    readonly property bool showAudio: settings.audio !== false
    readonly property bool showNotifications: settings.notifications !== false
    readonly property bool showNetwork: settings.network !== false

    implicitWidth: trayRow.implicitWidth + Theme.barSectionGap
    implicitHeight: Theme.barHeight

    function mergeSettings(base, fallbackHover) {
        var out = {}
        if (base && typeof base === "object") {
            for (var key in base)
                out[key] = base[key]
        }
        if (!out.onHover && fallbackHover)
            out.onHover = fallbackHover
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

    function trayHoverPopupId(trayItem) {
        if (!trayItem)
            return ""
        var key = String(trayItem.id || trayItem.title || "").toLowerCase()
        if (key.indexOf("insync") >= 0)
            return "evo.bar.popups.insync"
        if (key.indexOf("steam") >= 0)
            return "evo.bar.steam"
        return ""
    }

    function setTrayHoverPopup(trayItem, trayCell, active) {
        var popupId = root.trayHoverPopupId(trayItem)
        if (!popupId || !root.shell)
            return
        if (active)
            root.shell.hoverEnter(popupId, trayCell, root.barPanel)
        else
            root.shell.hoverLeave(popupId)
    }

    function openSteamClient() {
        Util.dismissHoverPopupFromBar(root.shell, "evo.bar.steam")
        Quickshell.execDetached(["bash", "-lc", Quickshell.env("HOME") + "/.local/bin/evo-bar-steam open"])
    }

    function rewireTrayWidgets() {
        if (weatherLoader.item) wireBarWidget(weatherLoader.item, settings.weather, "evo.bar.popups.weather")
        if (githubLoader.item) wireBarWidget(githubLoader.item, settings.github, "evo.bar.popups.github")
        if (cursorLoader.item) wireBarWidget(cursorLoader.item, settings.cursor, "evo.bar.popups.cursor-usage")
        if (stocksLoader.item) wireBarWidget(stocksLoader.item, settings.stocks, "evo.bar.popups.stocks")
        if (cloudflareLoader.item) wireBarWidget(cloudflareLoader.item, settings.cloudflare, "evo.bar.popups.cloudflare")
        if (homeAssistantLoader.item) wireBarWidget(homeAssistantLoader.item, settings.homeAssistant, "evo.bar.popups.home-assistant")
        if (networkLoader.item) wireBarWidget(networkLoader.item, settings.network, "evo.bar.network.stats")
        if (mediaLoader.item) wireBarWidget(mediaLoader.item, settings.audio, "evo.bar.media.now-playing")
        if (volumeLoader.item) wireBarWidget(volumeLoader.item, settings.audio, "evo.bar.media.volume")
        if (notificationsLoader.item) wireBarWidget(notificationsLoader.item, settings.notifications, "evo.bar.popups.notifications")
    }

    onSettingsChanged: rewireTrayWidgets()
    onShellChanged: rewireTrayWidgets()

    TrayContextMenu {
        id: trayContextMenu
        bar: root.bar
        barPanel: root.barPanel
    }

    Component { id: commandComp; CommandWidget {} }
    Component { id: githubComp; GithubWidget {} }
    Component { id: stocksComp; StocksWidget {} }
    Component { id: cloudflareComp; CloudflareWidget {} }
    Component { id: homeAssistantComp; HomeAssistantWidget {} }
    Component { id: mediaComp; MediaWidget {} }
    Component { id: volumeComp; VolumeWidget {} }
    Component { id: notificationsComp; NotificationsWidget {} }
    Component { id: networkComp; NetworkWidget {} }

    Row {
        id: trayRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        spacing: root.traySpacing
        height: Theme.barHeight

        Item {
            width: root.showAudio ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showAudio

            Loader {
                id: volumeLoader
                anchors.fill: parent
                active: root.showAudio
                sourceComponent: volumeComp
                onLoaded: root.wireBarWidget(item, root.settings.audio, "evo.bar.media.volume")
            }
        }

        Item {
            width: root.showWeather ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showWeather

            Loader {
                id: weatherLoader
                anchors.fill: parent
                active: root.showWeather
                sourceComponent: commandComp
                onLoaded: root.wireBarWidget(item, root.settings.weather, "evo.bar.popups.weather")
            }
        }

        Item {
            width: root.showGithub ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showGithub

            Loader {
                id: githubLoader
                anchors.fill: parent
                active: root.showGithub
                sourceComponent: githubComp
                onLoaded: root.wireBarWidget(item, root.settings.github, "evo.bar.popups.github")
            }
        }

        Item {
            width: root.showCursor ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showCursor

            Loader {
                id: cursorLoader
                anchors.fill: parent
                active: root.showCursor
                sourceComponent: commandComp
                onLoaded: root.wireBarWidget(item, root.settings.cursor, "evo.bar.popups.cursor-usage")
            }
        }

        Item {
            width: root.showNotifications ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showNotifications

            Loader {
                id: notificationsLoader
                anchors.fill: parent
                active: root.showNotifications
                sourceComponent: notificationsComp
                onLoaded: root.wireBarWidget(item, root.settings.notifications, "evo.bar.popups.notifications")
            }
        }

        Item {
            width: root.showStocks ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showStocks

            Loader {
                id: stocksLoader
                anchors.fill: parent
                active: root.showStocks
                sourceComponent: stocksComp
                onLoaded: root.wireBarWidget(item, root.settings.stocks, "evo.bar.popups.stocks")
            }
        }

        Item {
            width: root.showCloudflare ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showCloudflare

            Loader {
                id: cloudflareLoader
                anchors.fill: parent
                active: root.showCloudflare
                sourceComponent: cloudflareComp
                onLoaded: root.wireBarWidget(item, root.settings.cloudflare, "evo.bar.popups.cloudflare")
            }
        }

        Item {
            width: root.showHomeAssistant ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showHomeAssistant

            Loader {
                id: homeAssistantLoader
                anchors.fill: parent
                active: root.showHomeAssistant
                sourceComponent: homeAssistantComp
                onLoaded: root.wireBarWidget(item, root.settings.homeAssistant, "evo.bar.popups.home-assistant")
            }
        }

        Item {
            width: root.showNetwork ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showNetwork

            Loader {
                id: networkLoader
                anchors.fill: parent
                active: root.showNetwork
                sourceComponent: networkComp
                onLoaded: root.wireBarWidget(item, root.settings.network, "evo.bar.network.stats")
            }
        }

        Item {
            width: root.showAudio ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showAudio

            Loader {
                id: mediaLoader
                anchors.fill: parent
                active: root.showAudio
                sourceComponent: mediaComp
                onLoaded: root.wireBarWidget(item, root.settings.audio, "evo.bar.media.now-playing")
            }
        }

        Repeater {
            model: SystemTray.items

            Item {
                id: trayCell
                required property var modelData
                width: root.trayCellWidth
                height: Theme.barHeight

                TraySniWidget {
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
                    onContainsMouseChanged: root.setTrayHoverPopup(modelData, trayCell, containsMouse)
                    onClicked: function(mouse) {
                        if (!modelData) return
                        if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                            return
                        }
                        if (mouse.button === Qt.RightButton) {
                            var popupId = root.trayHoverPopupId(modelData)
                            if (popupId && Util.pinHoverPopupFromBarIfActive(root.shell, popupId))
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
                                && root.trayHoverPopupId(modelData) === "evo.bar.steam") {
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
