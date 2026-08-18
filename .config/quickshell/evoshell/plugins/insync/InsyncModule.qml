import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property string cacheKey: "evo.insync"
    readonly property string accountCachePath: (Quickshell.env("HOME") || "") + "/.local/state/evoshell/insync-accounts.json"
    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/evo-insync popup"
    readonly property string insyncBin: Quickshell.env("HOME") + "/.local/bin/evo-insync"
    readonly property int hintFont: Theme.fontSizeL
    readonly property int titleFont: Theme.fontSize2xl
    readonly property int fileFont: Theme.fontSizeS
    readonly property int fileDetailFont: Theme.fontSizeXs
    readonly property int actionIconFont: Theme.fontSizeL

    property bool loading: true
    property bool filesLoading: false
    property bool ok: false
    property string errorText: ""
    property string statusText: ""
    property bool paused: false
    property var accounts: []
    property var files: []
    property var errors: []

    implicitHeight: column.implicitHeight

    readonly property bool isSyncing: root.files.length > 0 && !root.paused && !root.loading

    readonly property string statusLine: {
        if (loading)
            return "Loading…"
        if (errorText)
            return errorText
        if (paused)
            return "Paused"
        if (isSyncing)
            return "Syncing"
        if (statusText)
            return statusText
        return "Idle"
    }

    readonly property color statusPillFill: {
        if (errorText)
            return Theme.withOpacity(Theme.urgent, 0.14)
        if (paused)
            return Theme.withOpacity(Theme.foreground, 0.08)
        if (isSyncing)
            return Theme.withOpacity(Theme.accent, 0.16)
        return Theme.withOpacity(Theme.foreground, 0.08)
    }

    readonly property color statusPillTextColor: {
        if (errorText)
            return Theme.urgent
        if (isSyncing)
            return Theme.accent
        return Theme.foreground
    }

    function providerIconSource(provider) {
        var p = String(provider || "").toLowerCase()
        if (p.indexOf("google") >= 0)
            return Util.iconSourceForName("google-drive")
        if (p.indexOf("onedrive") >= 0)
            return Util.iconSourceForName("ms-onedrive")
        if (p.indexOf("dropbox") >= 0)
            return Util.iconSourceForName("dropbox")
        return Util.iconSourceForName(String(provider || ""))
    }

    component InsyncProviderPill: Rectangle {
        id: pill

        property string text: ""
        property string iconUrl: ""
        property color fill: Theme.withOpacity(Theme.foreground, 0.08)
        property color textColor: Theme.foreground
        property int fontSize: Theme.fontSizeS
        property int iconSize: pill.fontSize + 2

        readonly property int padH: 10
        readonly property int padV: 5

        radius: height / 2
        color: fill
        implicitWidth: pillRow.implicitWidth + padH * 2
        implicitHeight: pillRow.implicitHeight + padV * 2

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Item {
                Layout.preferredWidth: pill.iconSize
                Layout.preferredHeight: pill.iconSize

                Image {
                    id: providerIcon
                    anchors.fill: parent
                    visible: pill.iconUrl !== "" && status === Image.Ready
                    source: pill.iconUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    sourceSize: Qt.size(pill.iconSize * 2, pill.iconSize * 2)
                }

                Text {
                    anchors.centerIn: parent
                    visible: pill.iconUrl === "" || providerIcon.status !== Image.Ready
                    text: "󰖟"
                    color: pill.textColor
                    opacity: Theme.opacityMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: pill.iconSize
                }
            }

            Text {
                text: pill.text
                color: pill.textColor
                font.family: Theme.fontFamily
                font.pixelSize: pill.fontSize
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    function basename(path) {
        var p = String(path || "")
        var idx = p.lastIndexOf("/")
        return idx >= 0 ? p.slice(idx + 1) : p
    }

    function formatBytes(n) {
        n = Number(n) || 0
        if (n < 1024) return Math.round(n) + " B"
        if (n < 1048576) return (n / 1024).toFixed(1) + " KB"
        if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB"
        return (n / 1073741824).toFixed(2) + " GB"
    }

    function applyAccountFields(json) {
        if (!json || typeof json !== "object")
            return false
        ok = json.ok === true
        errorText = String(json.error || "")
        statusText = String(json.status || "")
        paused = json.paused === true
        accounts = Array.isArray(json.accounts) ? json.accounts : []
        errors = Array.isArray(json.errors) ? json.errors : []
        loading = false
        return true
    }

    function applyFiles(json) {
        if (!json || typeof json !== "object")
            return
        files = Array.isArray(json.files) ? json.files : []
        filesLoading = false
    }

    function applyPayload(json, fromCache) {
        if (!json || typeof json !== "object")
            return
        applyAccountFields(json)
        if (!fromCache)
            applyFiles(json)
        publishCache(json)
    }

    function publishCache(json) {
        if (!cacheKey || !shell || !json)
            return
        Util.hoverPopupCacheWrite(shell, cacheKey, {
            ok: json.ok === true,
            error: String(json.error || ""),
            status: String(json.status || ""),
            paused: json.paused === true,
            accounts: Array.isArray(json.accounts) ? json.accounts : [],
            errors: Array.isArray(json.errors) ? json.errors : [],
        })
    }

    function bootstrapFromDiskCache() {
        accountCacheFile.reload()
        var raw = String(accountCacheFile.text() || "").trim()
        if (!raw)
            return false
        try {
            applyPayload(JSON.parse(raw), true)
            return accounts.length > 0 || errorText !== "" || statusText !== ""
        } catch (e) {
            return false
        }
    }

    function bootstrapFromCache() {
        if (cacheKey && shell) {
            var cached = Util.hoverPopupCacheRead(shell, cacheKey)
            if (cached) {
                applyPayload(cached, true)
                return true
            }
        }
        return bootstrapFromDiskCache()
    }

    function onActivated() {
        bootstrapFromCache()
        if (accounts.length === 0 && !errorText)
            loading = true
        files = []
        filesLoading = true
        refresh()
        pollTimer.start()
    }

    function onDeactivated() {
        pollTimer.stop()
        if (popupProc.running)
            popupProc.running = false
        if (actionProc.running)
            actionProc.running = false
    }

    function refresh() {
        if (!script || popupProc.running)
            return
        popupProc.running = true
    }

    function runAction(subcmd) {
        if (actionProc.running)
            return
        actionProc.command = [root.insyncBin, subcmd]
        actionProc.running = true
    }

    FileView {
        id: accountCacheFile
        path: root.accountCachePath
        watchChanges: false
    }

    Process {
        id: popupProc
        command: ["bash", "-lc", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(text || "").trim()
                if (!raw) {
                    root.loading = false
                    return
                }
                try {
                    root.applyPayload(JSON.parse(raw), false)
                } catch (e) {
                    root.loading = false
                    root.filesLoading = false
                    root.errorText = "Parse error"
                }
            }
        }
        onExited: {
            root.loading = false
            root.filesLoading = false
        }
    }

    Process {
        id: actionProc
        onExited: root.refresh()
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        onTriggered: root.refresh()
    }

    onShellChanged: bootstrapFromCache()
    Component.onCompleted: bootstrapFromCache()

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        FramedPanel {
            Layout.fillWidth: true
            label: ""
            contentPad: Theme.hoverPopupContentPad

            Item {
                width: parent.width
                implicitHeight: insyncTopCol.implicitHeight

                ColumnLayout {
                    id: insyncTopCol
                    width: parent.width
                    spacing: Theme.hoverPopupSectionSpacing

                    HoverPopupHeader {
                        Layout.fillWidth: true
                        iconFallback: "󰓦"
                        titleFont: root.titleFont
                        detailFont: root.hintFont
                        value: "Insync"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Text {
                            text: "Status:"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            font.bold: Theme.fontBold
                            opacity: Theme.opacitySecondary
                        }

                        HoverPopupLabelPill {
                            text: root.statusLine
                            fontSize: Theme.fontSizeS
                            textColor: root.statusPillTextColor
                            fill: root.statusPillFill
                            textOpacity: root.errorText || root.isSyncing ? 1 : 0.72
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS
                        visible: root.accounts.length > 0

                        Repeater {
                            model: root.accounts

                            InsyncProviderPill {
                                required property var modelData
                                text: String(modelData.provider || "Account")
                                iconUrl: root.providerIconSource(modelData.provider)
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        SectionPanel {
            Layout.fillWidth: true
            label: ""
            sectionSpacing: 8
            contentPad: Theme.hoverPopupContentPad
            visible: root.files.length > 0 || root.filesLoading
                || (!root.loading && root.errors.length === 0 && !root.errorText)

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                visible: root.filesLoading && root.files.length === 0

                Text {
                    anchors.centerIn: parent
                    text: "󰇘"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.titleFont
                    opacity: Theme.opacityEmphasis
                    transformOrigin: Item.Center

                    RotationAnimation on rotation {
                        running: root.filesLoading && root.files.length === 0
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS
                visible: root.files.length > 0

                Repeater {
                    model: root.files.slice(0, 5)

                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: root.basename(modelData.path)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: root.fileFont
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                var action = String(modelData.action || "")
                                var pct = Number(modelData.percent || 0)
                                if (modelData.total > 0)
                                    return action + " · " + root.formatBytes(modelData.done)
                                        + " / " + root.formatBytes(modelData.total)
                                        + " · " + Math.round(pct) + "%"
                                return action + (modelData.detail ? " · " + String(modelData.detail) : "")
                            }
                            color: Theme.foreground
                            opacity: Theme.opacitySecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: root.fileDetailFont
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 4
                            visible: Number(modelData.total || 0) > 0

                            CycleProgressBar {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                barWidth: width
                                progress: Math.max(0, Math.min(1, Number(modelData.percent || 0) / 100))
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.loading && root.files.length === 0 && !root.filesLoading
                text: root.ok ? "Nothing syncing" : "Insync unavailable"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFont
                opacity: Theme.opacityHover
            }
        }

        SectionPanel {
            Layout.fillWidth: true
            label: "Errors"
            sectionSpacing: 8
            contentPad: Theme.hoverPopupContentPad
            visible: root.errors.length > 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: root.errors

                    Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: String(modelData)
                        color: Theme.urgent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: actionRow.implicitHeight

            RowLayout {
                id: actionRow
                anchors.right: parent.right
                spacing: 16

                Item {
                    implicitWidth: pauseRow.implicitWidth
                    implicitHeight: pauseRow.implicitHeight

                RowLayout {
                    id: pauseRow
                    spacing: Theme.spacingS

                    Text {
                        text: root.paused ? "󰐊" : "󰏤"
                        color: pauseBtn.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.actionIconFont
                        font.bold: Theme.fontBold
                    }

                    Text {
                        text: root.paused ? "Resume" : "Pause"
                        color: pauseBtn.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        font.bold: Theme.fontBold
                    }
                }

                MouseArea {
                    id: pauseBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runAction(root.paused ? "resume" : "pause")
                }
            }

            Item {
                implicitWidth: showRow.implicitWidth
                implicitHeight: showRow.implicitHeight

                RowLayout {
                    id: showRow
                    spacing: Theme.spacingS

                    Text {
                        text: "󰍉"
                        color: showBtn.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.actionIconFont
                        font.bold: Theme.fontBold
                    }

                    Text {
                        text: "Show"
                        color: showBtn.containsMouse ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.hintFont
                        font.bold: Theme.fontBold
                    }
                }

                MouseArea {
                    id: showBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["insync", "show"])
                }
            }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.errorText !== "" && root.errors.length === 0
            text: root.errorText
            color: Theme.urgent
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            wrapMode: Text.WordWrap
        }
    }
}
