import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../commons"
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

    property string filterSource: "all"

    readonly property var filteredEntries: {
        var out = []
        var filter = String(filterSource || "all")
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (!item)
                continue
            var hidden = item.hidden === true
            if (filter === "hidden") {
                if (hidden)
                    out.push(item)
                continue
            }
            if (hidden)
                continue
            if (filter === "messages") {
                var src = String(item.source || "")
                if (src !== "telegram" && src !== "android")
                    continue
            } else if (filter === "web") {
                if (String(item.source || "") !== "web")
                    continue
            } else if (filter === "system") {
                var systemSrc = String(item.source || "")
                if (systemSrc !== "system" && systemSrc !== "shell" && systemSrc !== "journal")
                    continue
            } else if (filter !== "all" && String(item.source || "") !== filter) {
                continue
            }
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

    readonly property bool hasClearableEntries: {
        for (var i = 0; i < historyEntries.length; i++) {
            if (historyEntries[i] && historyEntries[i].hidden !== true)
                return true
        }
        return false
    }

    function entryCount(filter) {
        var id = String(filter || "all")
        var n = 0
        for (var i = 0; i < historyEntries.length; i++) {
            var item = historyEntries[i]
            if (!item)
                continue
            var hidden = item.hidden === true
            if (id === "hidden") {
                if (hidden)
                    n++
                continue
            }
            if (hidden)
                continue
            if (id === "messages") {
                var src = String(item.source || "")
                if (src === "telegram" || src === "android")
                    n++
            } else if (id === "web") {
                if (String(item.source || "") === "web")
                    n++
            } else if (id === "system") {
                var systemSrc = String(item.source || "")
                if (systemSrc === "system" || systemSrc === "shell" || systemSrc === "journal")
                    n++
            } else {
                n++
            }
        }
        return n
    }

    readonly property int countAll: entryCount("all")
    readonly property int countSystem: entryCount("system")
    readonly property int countMessages: entryCount("messages")
    readonly property int countWeb: entryCount("web")
    readonly property int countHidden: entryCount("hidden")

    implicitHeight: column.implicitHeight

    function onActivated() {
    }

    function onDeactivated() {
    }

    function formatTime(iso) {
        var raw = String(iso || "")
        if (!raw)
            return ""
        var d = new Date(raw)
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

    function sourceIcon(source) {
        if (notifService && typeof notifService.sourceIcon === "function")
            return notifService.sourceIcon(source)
        return "󰂚"
    }

    function entryArtSource(item) {
        var art = item && item.art ? String(item.art) : ""
        if (!art)
            return ""
        if (art.indexOf("evo.panels.player") !== -1)
            return Util.iconSourceForName("evo.panels.player")
        if (art.indexOf("data:image/") === 0)
            return art
        if (art.indexOf("/") !== -1 || art.indexOf("://") !== -1)
            return Util.fileUrl(art)
        var path = Quickshell.iconPath(art, true)
        return path ? Util.normalizeIconSource(path) : ""
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

        SectionPanel {
            label: ""
            Layout.fillWidth: true
            contentPad: Theme.hoverPanelContentPad
            legendBackground: Theme.background

            HoverPanelLabelPill {
                text: "Notifications"
                icon: "󰂚"
                fontSize: Theme.fontSizeS
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 5
                columnSpacing: Theme.spacingS
                rowSpacing: Theme.spacingS

                Repeater {
                    model: [
                        { id: "all", label: "all", value: root.countAll },
                        { id: "system", label: "system", value: root.countSystem },
                        { id: "web", label: "web", value: root.countWeb },
                        { id: "messages", label: "messages", value: root.countMessages },
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
                fontSize: Theme.fontSizeS
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
