import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../Commons"
import "."
import "Api.js" as Api
import "Model.js" as Model

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property var cf: shell ? shell.serviceFor("evo.bar.popups.cloudflare") : null
    readonly property string accountLegendLabel: {
        if (!cf)
            return "day.marketing"
        void cf.accountName
        void cf.accountId
        if (cf.accountName !== "")
            return cf.accountName
        return "day.marketing"
    }
    readonly property string accountLegendLogo: {
        var host = root.accountLegendLabel
        if (!host || host.indexOf(".") < 0)
            return ""
        return "https://www.google.com/s2/favicons?domain=" + encodeURIComponent(host) + "&sz=32"
    }
    readonly property int bodyFont: Theme.fontSize3xl
    readonly property int hintFont: Theme.fontSizeL
    readonly property int titleFont: Theme.fontSize2xl
    readonly property int rowTitleFont: Theme.fontSizeM
    readonly property int statFont: Theme.fontSizeXl

    property double nowMs: Date.now()

    readonly property var rows: {
        if (!cf)
            return []
        void cf.lastRefreshMs
        void cf.loggedIn
        void cf.accountId
        void cf.refreshing
        void cf.analyticsRefreshing
        void cf.workers.length
        void cf.pages.length
        void cf.buckets.length
        void cf.databases.length
        void cf.namespaces.length
        void cf.queues.length
        void cf.zones.length
        void cf.analytics.loaded
        void cf.analytics.workerRequests
        void cf.analytics.workerErrors
        void cf.analytics.r2Bytes
        void cf.analytics.d1RowsRead
        return buildRows()
    }

    readonly property var groupedSections: {
        var sourceRows = root.rows
        void sourceRows.length
        return groupedSectionsFromRows(sourceRows)
    }

    readonly property var usageSection: {
        var sections = root.groupedSections
        void sections.length
        for (var i = 0; i < sections.length; i++) {
            if (String(sections[i].title || "").toUpperCase() === "USAGE")
                return sections[i]
        }
        return { title: "USAGE", rows: [] }
    }

    readonly property var resourcesSection: {
        var sections = root.groupedSections
        void sections.length
        for (var i = 0; i < sections.length; i++) {
            if (String(sections[i].title || "").toUpperCase() === "RESOURCES")
                return sections[i]
        }
        return { title: "RESOURCES", rows: [] }
    }

    readonly property var attentionSection: {
        var sections = root.groupedSections
        void sections.length
        for (var i = 0; i < sections.length; i++) {
            if (String(sections[i].title || "").toUpperCase() === "NEEDS ATTENTION")
                return sections[i]
        }
        return { title: "NEEDS ATTENTION", rows: [] }
    }

    readonly property var recentGroupedSection: {
        var sections = root.groupedSections
        void sections.length
        for (var i = 0; i < sections.length; i++) {
            if (String(sections[i].title || "").toUpperCase() === "RECENT ACTIVITY")
                return sections[i]
        }
        return { title: "", rows: [] }
    }

    readonly property bool hasDisplaySections:
        root.usageSection.rows.length > 0
        || root.resourcesSection.rows.length > 0
        || root.attentionSection.rows.length > 0
        || root.recentGroupedSection.rows.length > 0

    implicitHeight: column.implicitHeight

    function buildRows() {
        if (!cf)
            return []
        return Model.buildRows(cf.resourceState(), cf.analytics, {
            deployRows: cf.deployRows,
            overviewDeployRows: cf.overviewDeployRows,
            limits: cf.limits,
            filter: "",
            route: "",
            tokenRows: Api.tokenShortcuts()
        })
    }

    function groupedSectionsFromRows(sourceRows) {
        var rows = sourceRows || []
        var out = []
        var currentKey = null
        var current = null
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            var key = String(row.section !== undefined ? row.section : "")
            if (key !== currentKey) {
                currentKey = key
                var title = String(row.sectionTitle || row.section || "")
                if (!title && row.kind === "group" && row.target === "token")
                    title = "CREATE A TOKEN"
                current = { title: title, key: key, rows: [] }
                out.push(current)
            }
            if (current)
                current.rows.push(row)
        }
        return out.filter(function(section) {
            return String(section.title || "") !== "CREATE A TOKEN"
        })
    }

    function sectionLabel(title) {
        var t = String(title || "").trim()
        if (!t)
            return ""
        var upper = t.toUpperCase()
        if (upper === "USAGE" || upper === "RESOURCES" || upper === "RECENT ACTIVITY")
            return ""
        return t.split(" ").map(function(word) {
            if (!word)
                return ""
            return word.charAt(0) + word.slice(1).toLowerCase()
        }).join(" ")
    }

    function sectionStatColumns(title) {
        return String(title || "") === "USAGE" ? 2 : 3
    }

    function sectionUsesStatGrid(title) {
        var t = String(title || "")
        return t === "USAGE" || t === "RESOURCES"
    }

    function onActivated() {
        nowMs = Date.now()
        if (cf) {
            cf.refresh()
            if (!cf.analytics.loaded)
                cf.refreshAnalytics()
        }
        tickTimer.start()
    }

    function onDeactivated() {
        tickTimer.stop()
    }

    function bootstrapFromCache() {}

    function openRow(row) {
        if (!row || !cf)
            return
        if (row.kind === "usage")
            cf.refreshAnalytics()
        else if (row.kind === "empty" || row.kind === "note")
            return
        else if (row.kind === "group") {
            if (row.target === "token")
                cf.openUrl(Api.dashAccount("/api-tokens"))
            else if (row.target === "worker")
                cf.openUrl(Api.dashAccount("/workers"))
            else if (row.target === "pages")
                cf.openUrl(Api.dashAccount("/pages"))
            else if (row.target === "r2")
                cf.openUrl(Api.dashAccount("/r2"))
            else if (row.target === "d1")
                cf.openUrl(Api.dashAccount("/workers/d1"))
            else if (row.target === "kv")
                cf.openUrl(Api.dashAccount("/workers/kv"))
            else if (row.target === "queue")
                cf.openUrl(Api.dashAccount("/workers/queues"))
            else if (row.target === "zone")
                cf.openUrl(Api.dashAccount("/zones"))
        } else if (row.liveUrl)
            cf.openUrl(row.liveUrl)
        else
            cf.openUrl(Api.dashUrlFor(row))
    }

    function rowGlyph(row) {
        if (!row)
            return ""
        if (row.kind === "deploy")
            return Model.glyphFor(row.target === "pages" ? "pages" : "worker")
        if (row.kind === "group")
            return Model.glyphFor(row.target === "token" ? "token" : row.target)
        return Model.glyphFor(row.kind)
    }

    function rowTitle(row) {
        if (!row)
            return ""
        if (row.kind === "usage")
            return String(row.title || "")
        if (row.kind === "group" && row.target === "token")
            return String(row.name || "Create a token")
        if (row.kind === "group")
            return String(row.name || "")
        return String(row.name || row.title || "")
    }

    function rowDetail(row) {
        if (!row)
            return ""
        if (row.kind === "usage")
            return String(row.detail || "")
        if (row.kind === "deploy")
            return String(row.status || "") + (row.via ? " · " + row.via : "")
                + " · " + Model.relativeTime(row.whenMs, root.nowMs)
        if (row.kind === "token")
            return String(row.hint || "")
        if (row.kind === "group")
            return String(row.detail || "")
        return String(row.detail || "")
    }

    function statValue(row) {
        if (!row)
            return "—"
        if (row.kind === "usage")
            return usageStatValue(row)
        if (row.kind === "group")
            return String(row.count !== undefined ? row.count : "—")
        return "—"
    }

    function usageStatValue(row) {
        if (!cf || !cf.analytics || !cf.analytics.loaded)
            return "—"
        if (row.metered && row.percent >= 0)
            return Math.round(row.percent * 100) + "%"
        var a = cf.analytics
        switch (String(row.id || "")) {
        case "worker-requests":
            return Model.formatCount(a.workerRequests)
        case "worker-errors":
            return Model.formatCount(a.workerErrors)
        case "r2-storage":
            return Model.formatBytes(a.r2Bytes)
        case "d1-reads":
            return Model.formatCount(a.d1RowsRead)
        default:
            return "—"
        }
    }

    function usageStatLabel(row) {
        if (!row)
            return ""
        switch (String(row.id || "")) {
        case "worker-requests":
            return "24h requests"
        case "worker-errors":
            return "24h errors"
        case "r2-storage":
            if (!cf || !cf.analytics || !cf.analytics.loaded)
                return "R2 objects"
            return Model.formatCount(cf.analytics.r2Objects) + " R2 objects"
        case "d1-reads":
            return "24h D1 reads"
        default:
            return ""
        }
    }

    function statLabel(row) {
        if (!row)
            return ""
        if (row.kind === "usage")
            return usageStatLabel(row)
        if (row.kind === "group")
            return String(row.name || "")
        return ""
    }

    function statValueColor(row) {
        if (!row)
            return Theme.accent
        if (row.alarming || (row.kind === "usage" && row.metered && row.percent >= 0.9))
            return Theme.urgent
        return Theme.accent
    }

    function rowClickable(row) {
        return row && row.selectable !== false
            && row.kind !== "empty"
            && row.kind !== "note"
    }

    function deployStatusLabel(row) {
        if (!row || row.kind !== "deploy")
            return ""
        if (row.failed)
            return "Failed"
        if (row.building)
            return "Building"
        var status = String(row.status || "deployed").toLowerCase()
        if (status === "deployed" || status === "success")
            return "Deployed"
        return status.charAt(0).toUpperCase() + status.slice(1)
    }

    function deployStatusColor(row) {
        if (!row)
            return Theme.foreground
        if (row.failed || row.alarming)
            return Theme.urgent
        if (row.building)
            return Theme.accent
        return Theme.accent
    }

    function deployMetaLine(row) {
        if (!row || row.kind !== "deploy")
            return ""
        var parts = []
        parts.push(row.target === "pages" ? "Pages" : "Worker")
        if (row.via)
            parts.push(String(row.via))
        var time = deployTimeLabel(row)
        if (time)
            parts.push(time)
        return parts.join(" · ")
    }

    function deployTimeLabel(row) {
        if (!row || row.kind !== "deploy" || !row.whenMs)
            return ""
        return Model.relativeTime(row.whenMs, root.nowMs)
    }

    function activityMetaLine(row) {
        if (!row)
            return ""
        if (row.kind === "deploy")
            return deployMetaLine(row)
        return rowDetail(row)
    }

    function activityStatusLabel(row) {
        if (!row)
            return ""
        if (row.kind === "deploy")
            return deployStatusLabel(row)
        if (row.alarming)
            return "Alert"
        return ""
    }

    function activityTimeLabel(row) {
        if (!row)
            return ""
        if (row.kind === "deploy")
            return deployTimeLabel(row)
        return ""
    }

    function activityStatusColor(row) {
        if (!row)
            return Theme.foreground
        if (row.kind === "deploy")
            return deployStatusColor(row)
        if (row.alarming)
            return Theme.urgent
        return Theme.accent
    }

    Timer {
        id: tickTimer
        interval: 30000
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        SectionPanel {
            Layout.fillWidth: true
            label: ""
            sectionSpacing: 8
            contentPad: Theme.hoverPopupContentPad
            legendBackground: Theme.background

            HoverPopupLabelPill {
                text: root.accountLegendLabel
                icon: "󰠞"
                fontSize: Theme.fontSizeS
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                visible: root.usageSection.rows.length > 0

                Repeater {
                    model: root.usageSection.rows

                    HoverPopupStatBox {
                        required property var modelData
                        value: root.statValue(modelData)
                        label: root.statLabel(modelData)
                        valueColor: root.statValueColor(modelData)
                        clickable: root.rowClickable(modelData)
                        onClicked: root.openRow(modelData)
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8
                visible: root.resourcesSection.rows.length > 0

                Repeater {
                    model: root.resourcesSection.rows

                    HoverPopupStatBox {
                        required property var modelData
                        value: root.statValue(modelData)
                        label: root.statLabel(modelData)
                        valueColor: root.statValueColor(modelData)
                        clickable: root.rowClickable(modelData)
                        onClicked: root.openRow(modelData)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: cf && cf.actionStatus !== ""
                text: cf ? cf.actionStatus : ""
                color: Theme.foreground
                opacity: Theme.opacityHover
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                font.bold: Theme.fontBold
                wrapMode: Text.WordWrap
            }
        }

        SectionPanel {
            Layout.fillWidth: true
            visible: root.attentionSection.rows.length > 0
            label: root.sectionLabel(root.attentionSection.title)
            sectionSpacing: 8
            contentPad: Theme.hoverPopupContentPad
            legendBackground: Theme.background

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.attentionSection.rows

                    CloudflareActivityEntry {
                        required property var modelData
                        required property int index
                        row: modelData
                        host: root
                        showDivider: index < root.attentionSection.rows.length - 1
                    }
                }
            }
        }

        SectionPanel {
            Layout.fillWidth: true
            label: ""
            visible: root.recentGroupedSection.rows.length > 0
            sectionSpacing: 8
            contentPad: Theme.hoverPopupContentPad
            legendBackground: Theme.background

            HoverPopupLabelPill {
                text: "Recent"
                icon: "󰋚"
                fontSize: Theme.fontSizeS
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.recentGroupedSection.rows

                    CloudflareActivityEntry {
                        required property var modelData
                        required property int index
                        row: modelData
                        host: root
                        showDivider: index < root.recentGroupedSection.rows.length - 1
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: cf && cf.lastError !== "" && !root.hasDisplaySections
            text: cf.lastError
            color: Theme.urgent
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            visible: cf && cf.lastError === "" && !root.hasDisplaySections
            text: cf && cf.busy ? "Loading…" : (cf && cf.loggedIn ? "No data" : "Not logged in")
            color: Theme.foreground
            opacity: Theme.opacityMuted
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
