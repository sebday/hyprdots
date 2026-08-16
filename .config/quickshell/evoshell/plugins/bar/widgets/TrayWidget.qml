import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../../Commons"

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
    readonly property bool showAudio: settings.audio !== false
    readonly property bool showNetwork: settings.network !== false
    readonly property bool showTransmission: settings.transmission != null && settings.transmission !== false

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

    function rewireTrayWidgets() {
        if (weatherLoader.item) wireBarWidget(weatherLoader.item, settings.weather, "evo.weather")
        if (githubLoader.item) wireBarWidget(githubLoader.item, settings.github, "evo.github")
        if (cursorLoader.item) wireBarWidget(cursorLoader.item, settings.cursor, "evo.cursor")
        if (stocksLoader.item) wireBarWidget(stocksLoader.item, settings.stocks, "evo.stocks")
        if (cloudflareLoader.item) wireBarWidget(cloudflareLoader.item, settings.cloudflare, "evo.cloudflare")
        if (transmissionLoader.item) wireBarWidget(transmissionLoader.item, settings.transmission, "evo.transmission")
        if (networkLoader.item) wireBarWidget(networkLoader.item, settings.network, "evo.network")
        if (mediaLoader.item) wireBarWidget(mediaLoader.item, settings.audio, "evo.media")
        if (volumeLoader.item) wireBarWidget(volumeLoader.item, settings.audio, "evo.volume")
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
    Component { id: mediaComp; MediaWidget {} }
    Component { id: volumeComp; VolumeWidget {} }
    Component { id: networkComp; NetworkWidget {} }
    Component { id: transmissionComp; TransmissionWidget {} }

    Row {
        id: trayRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.traySpacing
        height: Theme.barHeight

        Item {
            width: root.showWeather ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showWeather

            Loader {
                id: weatherLoader
                anchors.fill: parent
                active: root.showWeather
                sourceComponent: commandComp
                onLoaded: root.wireBarWidget(item, root.settings.weather, "evo.weather")
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
                onLoaded: root.wireBarWidget(item, root.settings.github, "evo.github")
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
                onLoaded: root.wireBarWidget(item, root.settings.cursor, "evo.cursor")
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
                onLoaded: root.wireBarWidget(item, root.settings.stocks, "evo.stocks")
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
                onLoaded: root.wireBarWidget(item, root.settings.cloudflare, "evo.cloudflare")
            }
        }

        Item {
            width: root.showTransmission ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showTransmission

            Loader {
                id: transmissionLoader
                anchors.fill: parent
                active: root.showTransmission
                sourceComponent: transmissionComp
                onLoaded: root.wireBarWidget(item, root.settings.transmission, "evo.transmission")
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
                onLoaded: root.wireBarWidget(item, root.settings.network, "evo.network")
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
                onLoaded: root.wireBarWidget(item, root.settings.audio, "evo.media")
            }
        }

        Item {
            width: root.showAudio ? root.trayCellWidth : 0
            height: Theme.barHeight
            visible: root.showAudio

            Loader {
                id: volumeLoader
                anchors.fill: parent
                active: root.showAudio
                sourceComponent: volumeComp
                onLoaded: root.wireBarWidget(item, root.settings.audio, "evo.volume")
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
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: function(mouse) {
                        if (!modelData) return
                        if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate()
                            return
                        }
                        if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                            trayContextMenu.open(modelData.menu, trayCell)
                            return
                        }
                        if (modelData.onlyMenu && modelData.hasMenu) {
                            trayContextMenu.open(modelData.menu, trayCell)
                            return
                        }
                        modelData.activate()
                    }
                }
            }
        }
    }
}
