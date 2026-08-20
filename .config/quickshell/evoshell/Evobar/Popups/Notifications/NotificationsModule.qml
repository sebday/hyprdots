import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../Commons"
import "."

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property var notifService: shell ? shell.serviceFor("evo.sys.notifications") : null
    readonly property var historyEntries: notifService ? (notifService.historyEntries || []) : []
    readonly property int unreadCount: notifService ? (notifService.unreadCount || 0) : 0
    readonly property int hintFont: Theme.fontSizeL
    readonly property int titleFont: Theme.fontSizeXl
    readonly property int bodyFont: Theme.fontSizeM
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
            } else if (filter !== "all" && String(item.source || "") !== filter) {
                continue
            }
            out.push(item)
        }
        return out
    }

    readonly property string emptyListText: filterSource === "hidden"
        ? "No hidden notifications"
        : "No notifications"

    readonly property bool hasClearableEntries: {
        for (var i = 0; i < historyEntries.length; i++) {
            if (historyEntries[i] && historyEntries[i].hidden !== true)
                return true
        }
        return false
    }

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

    function sourceLabel(source) {
        if (notifService && typeof notifService.sourceLabel === "function")
            return notifService.sourceLabel(source)
        return String(source || "System")
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
        if (art.indexOf("data:image/") === 0)
            return art
        return Util.fileUrl(art)
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
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            label: ""
            Layout.fillWidth: true

            HoverPopupLabelPill {
                text: "Notifications"
                icon: "󰂚"
                fontSize: Theme.fontSizeS
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Repeater {
                    model: [
                        { id: "all", label: "All" },
                        { id: "system", label: "System" },
                        { id: "messages", label: "Messages" },
                        { id: "hidden", label: "Hidden" }
                    ]

                    NotificationMetaPill {
                        required property var modelData
                        text: modelData.label
                        active: root.filterSource === modelData.id
                        clickable: true
                        onClicked: root.filterSource = modelData.id
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.unreadCount > 0
                    text: root.unreadCount + " unread"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    font.bold: Theme.fontBold
                    opacity: Theme.opacitySecondary
                }

                Text {
                    visible: root.hasClearableEntries
                    text: "Clear"
                    color: Theme.urgent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.hintFont
                    font.bold: Theme.fontBold
                    opacity: Theme.opacitySecondary

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearAll()
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.filteredEntries.length === 0
            text: root.emptyListText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
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
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.filteredEntries

                        NotificationHistoryEntry {
                            required property var modelData
                            entry: modelData
                            host: root
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
    }
}
