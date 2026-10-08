import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.commons
import qs.ui
import "."

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPanelWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property var notifService: shell ? shell.serviceFor("evo.sys.notifications") : null
    readonly property var historyEntries: notifService ? (notifService.historyEntries || []) : []
    readonly property int titleFont: Theme.fontSizeM
    readonly property int maxListHeight: 420

    property string filterSource: "system"

    function isListed(item, filter) {
        if (!item)
            return false
        var hidden = item.hidden === true
        if (String(filter || "system") === "hidden")
            return hidden
        return !hidden
    }

    readonly property var filteredEntries: {
        var out = []
        var filter = String(filterSource || "system")
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (isListed(item, filter))
                out.push(item)
        }
        return out
    }

    readonly property string emptyListText: {
        if (filterSource === "hidden")
            return "No hidden notifications"
        if (filterSource === "system")
            return "No system notifications or warnings"
        return "No notifications"
    }

    readonly property bool hasClearableEntries: countSystem > 0

    function entryCount(filter) {
        var id = String(filter || "system")
        var n = 0
        for (var i = 0; i < historyEntries.length; i++) {
            if (isListed(historyEntries[i], id))
                n++
        }
        return n
    }

    readonly property int countSystem: entryCount("system")
    readonly property int countHidden: entryCount("hidden")

    implicitHeight: column.implicitHeight

    function onActivated() {
        if (notifService && typeof notifService.markAllRead === "function")
            notifService.markAllRead()
    }

    function onDeactivated() {
    }

    function formatTime(timestamp) {
        var ms = Number(timestamp || 0)
        if (!isFinite(ms) || ms <= 0)
            return ""
        var d = new Date(ms)
        if (isNaN(d.getTime()))
            return ""
        var now = new Date()
        var sameDay = d.getDate() === now.getDate()
            && d.getMonth() === now.getMonth()
            && d.getFullYear() === now.getFullYear()
        if (sameDay)
            return Qt.formatDateTime(d, "HH:mm")
        return Qt.formatDateTime(d, "ddd HH:mm")
    }

    function entryArtSource(item) {
        var art = ""
        if (item && item.image)
            art = String(item.image)
        else if (item && item.appIcon)
            art = String(item.appIcon)
        if (!art)
            return ""
        if (art.toLowerCase() === "evoshell" || art.indexOf("evoshell.svg") !== -1)
            return ""
        if (art.indexOf("evo.panels.player") !== -1)
            return Util.iconSourceForName("evo.panels.player")
        if (art.indexOf("data:image/") === 0)
            return art
        if (art.indexOf("?") !== -1 && art.indexOf("://") === -1)
            art = art.split("?")[0]
        if (art.indexOf("/") !== -1 || art.indexOf("://") !== -1)
            return Util.fileUrl(art)
        return Util.iconSourceForName(art)
    }

    function openEntry(item) {
        if (!notifService || !item)
            return
        if (typeof notifService.openHistoryEntry === "function")
            notifService.openHistoryEntry(item)
    }

    function removeEntry(item) {
        if (!notifService || !item)
            return
        if (typeof notifService.removeHistoryEntry === "function")
            notifService.removeHistoryEntry(item.key)
    }

    function hideEntry(item) {
        if (!notifService || !item)
            return
        if (typeof notifService.hideHistoryEntry === "function")
            notifService.hideHistoryEntry(item.key)
    }

    function unhideEntry(item) {
        if (!notifService || !item)
            return
        if (typeof notifService.unhideHistoryEntry === "function")
            notifService.unhideHistoryEntry(item.key)
    }

    function clearAll() {
        if (!notifService)
            return
        if (typeof notifService.clearHistory === "function")
            notifService.clearHistory()
    }

    Connections {
        target: root.host
        enabled: root.host !== null
        function onPinnedChanged() {
            if (root.host && root.host.pinned && root.notifService
                    && typeof root.notifService.markAllRead === "function")
                root.notifService.markAllRead()
        }
    }

    ColumnLayout {
        id: column
        width: root.hoverPanelWidth
        spacing: Theme.hoverPanelSectionSpacing

        PanelHero {
            Layout.fillWidth: true
            title: "Notifications"
            meta: root.countSystem === 1 ? "1 notification" : root.countSystem + " notifications"
            foreground: Theme.foreground
            fontFamily: Theme.fontFamily

            iconComponent: Component {
                Text {
                    textFormat: Text.PlainText
                    text: "󰂚"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.font.display
                    opacity: 0.92
                }
            }
        }

        SectionPanel {
            label: ""
            Layout.fillWidth: true
            contentPad: Theme.hoverPanelContentPad
            legendBackground: Theme.background

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.spacingS
                rowSpacing: Theme.spacingS

                Repeater {
                    model: [
                        { id: "system", label: "system", value: root.countSystem },
                        { id: "hidden", label: "hidden", value: root.countHidden }
                    ]

                    HoverPanelStatBox {
                        required property var modelData
                        value: String(modelData.value)
                        label: modelData.label
                        valueFontSize: Theme.fontSizeXl
                        special: root.filterSource === modelData.id
                        clickable: true
                        onClicked: root.filterSource = modelData.id
                    }
                }
            }
        }

        SectionPanel {
            Layout.fillWidth: true
            label: ""
            sectionSpacing: 8
            contentPad: Theme.hoverPanelContentPad
            legendBackground: Theme.background

            HoverPanelLabelPill {
                text: "Recent"
                icon: "󰋚"
                fontSize: Theme.font.caption
            }

            Text {
                Layout.fillWidth: true
                visible: root.filteredEntries.length === 0
                text: root.emptyListText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                font.bold: Theme.fontBold
                opacity: Theme.opacityDisabled
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(root.maxListHeight, listColumn.implicitHeight)
                visible: root.filteredEntries.length > 0
                clip: true

                Flickable {
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: listColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: listColumn
                        width: parent.width
                        spacing: 0

                        Repeater {
                            model: root.filteredEntries

                            NotificationHistoryEntry {
                                required property var modelData
                                required property int index
                                entry: modelData
                                host: root
                                showDivider: index < root.filteredEntries.length - 1
                                showUnhide: root.filterSource === "hidden"
                                onHideRequested: function(item) { root.hideEntry(item) }
                                onUnhideRequested: function(item) { root.unhideEntry(item) }
                                onRemoveRequested: function(item) { root.removeEntry(item) }
                                onOpenRequested: function(item) { root.openEntry(item) }
                            }
                        }
                    }
                }
            }

            HoverPanelLabelPill {
                Layout.alignment: Qt.AlignRight
                visible: root.hasClearableEntries
                clickable: root.hasClearableEntries
                text: "Clear"
                icon: "󰩺"
                fontSize: Theme.fontSizeXs
                textColor: Theme.urgent
                fill: Theme.fillNeutralSubtle
                textOpacity: Theme.opacitySecondary
                onClicked: root.clearAll()
            }
        }
    }
}
