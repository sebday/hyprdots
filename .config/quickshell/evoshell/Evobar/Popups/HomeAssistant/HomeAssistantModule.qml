import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../Commons"
import "Api.js" as Api
import "Model.js" as Model

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property var ha: shell ? shell.serviceFor("evo.bar.popups.home-assistant") : null
    readonly property bool contentReady: !ha || ha.lastRefreshMs > 0 || (ha.lastError !== "" && ha.data)
    readonly property int hintFont: Theme.fontSizeL
    readonly property int statFont: Theme.fontSizeXl

    property double nowMs: Date.now()

    readonly property var temperatures: ha ? ha.temperatures : []
    readonly property var cameras: ha ? ha.cameras : []
    readonly property var lights: ha ? ha.lights : []
    readonly property var lightAreas: Model.groupLightsByArea(root.lights)
    readonly property var lightAreaColumns: Model.distributeIntoColumns(root.lightAreas, 3)
    readonly property int layoutColumnCount: 4
    readonly property int layoutColumnGap: Theme.spacingM
    readonly property int layoutColumnWidth: Math.max(0, Math.floor(
        (root.hoverPopupWidth - root.layoutColumnGap * (root.layoutColumnCount - 1))
        / root.layoutColumnCount))

    component LightAreaFieldset: SectionPanel {
        id: areaPanel
        required property var areaData
        Layout.fillWidth: true
        label: ""
        sectionSpacing: 8
        contentPad: Theme.hoverPopupContentPad
        legendBackground: Theme.background

        HoverPopupLabelPill {
            text: String(areaPanel.areaData.area || "Lights")
            icon: "󰌵"
            fontSize: Theme.fontSizeS
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            Repeater {
                model: areaPanel.areaData.lights

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    readonly property string entityId: String(modelData.entityId || "")
                    readonly property bool isOn: modelData.on === true
                    readonly property int brightnessPct: {
                        var n = parseInt(modelData.brightnessPct, 10)
                        return isNaN(n) ? 0 : n
                    }
                    readonly property bool available: modelData.available !== false

                    property int draftBrightness: brightnessPct

                    onBrightnessPctChanged: draftBrightness = brightnessPct

                    ToggleRow {
                        Layout.fillWidth: true
                        label: String(modelData.name || modelData.entityId || "Light")
                        detail: isOn ? (draftBrightness + "%") : "Off"
                        checked: isOn
                        enabled: available && ha && !ha.acting
                        onToggled: {
                            if (!ha)
                                return
                            ha.toggleLight(entityId, !isOn, Math.max(draftBrightness, 1))
                        }
                    }

                    SliderSetting {
                        Layout.fillWidth: true
                        visible: isOn
                        label: "Brightness"
                        value: draftBrightness
                        minimum: 1
                        maximum: 100
                        step: 1
                        valueSuffix: "%"
                        enabled: available && ha && !ha.acting
                        onValueEdited: function(next) {
                            draftBrightness = next
                        }
                        onValueCommitted: function(next) {
                            if (!ha)
                                return
                            ha.toggleLight(entityId, true, next)
                        }
                    }
                }
            }
        }
    }

    implicitHeight: column.implicitHeight

    function onActivated() {
        nowMs = Date.now()
        if (ha) {
            ha.popupActive = true
            ha.refresh()
        }
        tickTimer.start()
    }

    function onDeactivated() {
        if (ha)
            ha.popupActive = false
        tickTimer.stop()
    }

    function bootstrapFromCache() {}

    function fmtTemp(row) {
        return Model.formatTemperature(row ? row.value : null, row ? row.unit : "°C")
    }

    function snapshotUrl(entityId) {
        if (!ha)
            return ""
        var snap = ha.snapshotFor(entityId)
        return snap ? snap.url : ""
    }

    function snapshotAge(entityId) {
        if (!ha)
            return ""
        var snap = ha.snapshotFor(entityId)
        return snap ? Model.relativeTime(snap.updatedAt, root.nowMs) : ""
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

        Text {
            Layout.fillWidth: true
            visible: ha && ha.actionStatus !== ""
            text: ha ? ha.actionStatus : ""
            color: Theme.foreground
            opacity: Theme.opacityHover
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            font.bold: Theme.fontBold
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: fieldsetRow.implicitHeight

            Row {
                id: fieldsetRow
                width: parent.width
                spacing: root.layoutColumnGap

                ColumnLayout {
                    id: climateCamerasColumn
                    width: root.layoutColumnWidth
                    spacing: Theme.spacingM
                    clip: true

                SectionPanel {
                    Layout.fillWidth: true
                    label: ""
                    sectionSpacing: 8
                    contentPad: Theme.hoverPopupContentPad
                    legendBackground: Theme.background

                    HoverPopupLabelPill {
                        text: "Climate"
                        icon: "󰔏"
                        fontSize: Theme.fontSizeS
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Repeater {
                            model: root.temperatures

                            HoverPopupStatBox {
                                required property var modelData
                                Layout.fillWidth: true
                                value: root.fmtTemp(modelData)
                                label: String(modelData.name || modelData.entityId || "Temperature")
                                valueColor: Theme.accent
                                clickable: false
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.temperatures.length === 0
                            text: "No sensors"
                            color: Theme.foreground
                            opacity: Theme.opacityMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                SectionPanel {
                    Layout.fillWidth: true
                    label: ""
                    sectionSpacing: 8
                    contentPad: Theme.hoverPopupContentPad
                    legendBackground: Theme.background

                    HoverPopupLabelPill {
                        text: "Cameras"
                        icon: "󰄀"
                        fontSize: Theme.fontSizeS
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingM

                        Repeater {
                            model: root.cameras

                            Item {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: cameraColumn.implicitHeight

                                readonly property string entityId: String(modelData.entityId || "")
                                readonly property bool available: modelData.available !== false
                                readonly property string imageUrl: root.snapshotUrl(entityId)

                                ColumnLayout {
                                    id: cameraColumn
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 72
                                        radius: Theme.fieldsetCornerRadius
                                        color: Theme.background
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            visible: cameraColumn.parent.imageUrl !== ""
                                            source: cameraColumn.parent.imageUrl
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: cameraColumn.parent.imageUrl === ""
                                            text: cameraColumn.parent.available ? "Loading…" : "Unavailable"
                                            color: Theme.foreground
                                            opacity: Theme.opacityMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeS
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: String(modelData.name || modelData.entityId || "Camera")
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeS
                                        font.bold: Theme.fontBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: root.snapshotAge(entityId) !== ""
                                        text: root.snapshotAge(entityId)
                                        color: Theme.foreground
                                        opacity: Theme.opacityMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeS
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.cameras.length === 0
                            text: "No cameras"
                            color: Theme.foreground
                            opacity: Theme.opacityMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
                }

                Repeater {
                    model: root.lightAreaColumns

                    ColumnLayout {
                        required property var modelData
                        required property int index
                        width: root.layoutColumnWidth
                        spacing: Theme.spacingM
                        clip: true

                        Repeater {
                            model: modelData

                            LightAreaFieldset {
                                required property var modelData
                                areaData: modelData
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.lights.length === 0 && index === 0
                            text: "No lights"
                            color: Theme.foreground
                            opacity: Theme.opacityMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFont
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: ha && ha.lastError !== "" && !ha.configured
            text: ha.lastError + (ha.data && ha.data.detail ? "\n" + ha.data.detail : "")
            color: Theme.urgent
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            visible: ha && ha.lastError === "" && !ha.configured && ha.busy
            text: "Loading…"
            color: Theme.foreground
            opacity: Theme.opacityMuted
            font.family: Theme.fontFamily
            font.pixelSize: root.hintFont
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
