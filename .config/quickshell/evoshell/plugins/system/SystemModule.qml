import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: shell ? String(shell.hoverPopupId || "") : ""
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int bodyFont: Theme.hoverPopupBodyFontPixelSize
    readonly property int hintFont: Theme.hoverPopupHintFontPixelSize
    readonly property int valueFont: Theme.fontPixelSize
    readonly property int labelWidth: 76

    property bool loading: false
    property var lines: []
    property string hostName: ""
    property string osName: ""
    property int cpuPercent: 0

    implicitHeight: column.implicitHeight

    readonly property string headerValue: {
        var parts = []
        if (hostName)
            parts.push(hostName)
        if (osName)
            parts.push(osName)
        return parts.join("\n")
    }

    function onActivated() {
        syncFromBar()
    }

    function bootstrapFromCache() {
        if (!cacheKey || !shell)
            return
        var cached = shell.hoverPopupDataFor(cacheKey)
        if (cached)
            applyPayload(cached)
    }

    function publishCache(json) {
        if (cacheKey && shell && json && typeof json === "object")
            shell.setHoverPopupData(cacheKey, json)
    }

    function syncFromBar() {
        var item = barSource
        if (item && item.loading) {
            if (lines.length === 0)
                loading = true
            return
        }
        if (item && item.lastPayload)
            applyPayload(item.lastPayload)
        else
            applyPayload(null)
    }

    function applyPayload(json) {
        loading = false
        if (!json || typeof json !== "object") {
            lines = []
            hostName = ""
            osName = ""
            cpuPercent = 0
            return
        }
        hostName = String(json.host || "")
        osName = String(json.os || "")
        cpuPercent = parseInt(json.cpuPercent, 10) || 0
        lines = Array.isArray(json.lines) ? json.lines : []
        publishCache(json)
    }

    onActiveChanged: if (active) syncFromBar()
    onBarSourceChanged: if (active) syncFromBar()

    Connections {
        target: root.barSource
        enabled: root.barSource !== null
        function onLastPayloadChanged() {
            if (root.active)
                root.syncFromBar()
        }
        function onLoadingChanged() {
            if (root.active)
                root.syncFromBar()
        }
    }

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        Text {
            Layout.fillWidth: true
            visible: root.loading
            text: "Loading system info…"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.bodyFont
            font.bold: Theme.fontBold
        }

        SectionPanel {
            label: ""
            visible: !root.loading && root.headerValue !== ""

            HoverPopupHeader {
                Layout.fillWidth: true
                iconFallback: "󰍛"
                value: root.headerValue
            }
        }

        SectionPanel {
            label: ""
            visible: !root.loading && root.lines.length > 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: root.lines

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.preferredWidth: root.labelWidth
                            text: String(modelData.label || "")
                            color: Theme.foreground
                            opacity: 0.55
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: String(modelData.value || "—")
                            color: {
                                if (modelData.label === "cpu")
                                    return Format.loadPercentColor(root.cpuPercent)
                                return Theme.foreground
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: root.valueFont
                            font.bold: Theme.fontBold
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }
                    }
                }
            }
        }
    }
}
