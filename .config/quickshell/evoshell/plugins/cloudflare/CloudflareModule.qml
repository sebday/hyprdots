import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "Api.js" as Api
import "Model.js" as Model

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property var cf: shell ? shell.serviceFor("evo.cloudflare") : null
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int titleFont: Theme.hoverPopupLabelFontPixelSize

    property double nowMs: Date.now()

    readonly property var rows: {
        if (!cf)
            return []
        var touch = cf.lastRefreshMs + Number(cf.analytics.loaded) + cf.workers.length
        void touch
        return buildRows()
    }

    readonly property var groupedSections: groupedSectionsFromRows()

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

    function groupedSectionsFromRows() {
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

    function heroMeta() {
        if (!cf)
            return ""
        if (!cf.configLoaded)
            return "Reading wrangler credentials"
        if (!cf.loggedIn)
            return "Not logged in — run wrangler login"
        if (cf.lastError !== "")
            return cf.lastError
        if (cf.accountId === "")
            return "Resolving account"
        var parts = []
        if (cf.workers.length)
            parts.push(cf.workers.length + " workers")
        if (cf.pages.length)
            parts.push(cf.pages.length + " pages")
        if (cf.buckets.length)
            parts.push(cf.buckets.length + " buckets")
        if (cf.zones.length)
            parts.push(cf.zones.length + " zones")
        return parts.length ? parts.join(" · ") : "No resources"
    }

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

            HoverPopupHeader {
                Layout.fillWidth: true
                iconFallback: "󰠞"
                titleFont: root.titleFont
                detailFont: root.hintFont
                value: {
                    if (!cf)
                        return "Cloudflare\nLoading…"
                    var title = cf.accountName !== "" ? cf.accountName : "Cloudflare"
                    var meta = root.heroMeta()
                    return title + (meta ? "\n" + meta : "")
                }
            }

            Text {
                Layout.fillWidth: true
                visible: cf && cf.actionStatus !== ""
                text: cf ? cf.actionStatus : ""
                color: Theme.foreground
                opacity: 0.65
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                font.bold: Theme.fontBold
                wrapMode: Text.WordWrap
            }
        }

        Repeater {
            model: root.groupedSections

            SectionPanel {
                id: sectionItem
                required property var modelData
                Layout.fillWidth: true
                label: root.sectionLabel(modelData.title)
                sectionSpacing: 8
                contentPad: Theme.hoverPopupContentPad
                visible: modelData.rows.length > 0

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.sectionStatColumns(modelData.title)
                    columnSpacing: 8
                    rowSpacing: 8
                    visible: root.sectionUsesStatGrid(modelData.title)

                    Repeater {
                        model: modelData.rows

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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: !root.sectionUsesStatGrid(sectionItem.modelData.title)

                    Repeater {
                        model: modelData.rows

                        Item {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: rowInner.implicitHeight + 4

                            RowLayout {
                                id: rowInner
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    visible: root.rowGlyph(modelData) !== ""
                                    text: root.rowGlyph(modelData)
                                    color: modelData.alarming ? Theme.urgent : Theme.foreground
                                    opacity: 0.72
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.bodyFont
                                    font.bold: Theme.fontBold
                                    Layout.preferredWidth: 20
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.rowTitle(modelData)
                                        color: modelData.alarming ? Theme.urgent : Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.titleFont
                                        font.bold: Theme.fontBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: root.rowDetail(modelData) !== ""
                                        text: root.rowDetail(modelData)
                                        color: Theme.foreground
                                        opacity: 0.68
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.hintFont
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                    }
                                }

                                Text {
                                    visible: modelData.kind === "group"
                                    text: "›"
                                    color: Theme.foreground
                                    opacity: 0.45
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.hintFont
                                    font.bold: Theme.fontBold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.rowClickable(modelData)
                                hoverEnabled: enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.openRow(modelData)
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: cf && cf.loggedIn && root.rows.length === 0
            text: cf && cf.busy ? "Loading…" : "No data"
            color: Theme.foreground
            opacity: 0.55
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
