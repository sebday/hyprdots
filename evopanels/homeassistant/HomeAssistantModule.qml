import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPanelWidth: 0

    readonly property var ha: shell ? shell.serviceFor("evo.panels.homeassistant") : null
    readonly property bool contentReady: !ha || ha.lastRefreshMs > 0 || (ha.lastError !== "" && ha.data)
    readonly property int hintFont: Theme.fontSizeL

    readonly property var climates: ha ? ha.climates : []
    readonly property var lights: ha ? ha.lights : []
    readonly property var areaRows: ha && ha.lightAreas.length > 0 ? ha.lightAreas.slice() : []
    readonly property bool lightsConfigured: areaRows.length > 0
    readonly property int layoutColumnCount: 2
    readonly property int layoutColumnGap: Theme.spacingM
    readonly property int layoutColumnWidth: Math.max(0, Math.floor(
        (root.hoverPanelWidth - root.layoutColumnGap * (root.layoutColumnCount - 1))
        / root.layoutColumnCount))
    readonly property int controlRowSpacing: Theme.spacingS

    function lightForArea(area) {
        var target = String(area || "")
        var i, light, haArea, name
        for (i = 0; i < root.lights.length; i++) {
            light = root.lights[i]
            haArea = String(light.haArea || "")
            if (haArea === target)
                return light
            name = String(light.name || "")
            if (name === target)
                return light
            if (String(light.area || "") === target)
                return light
        }
        return null
    }

    function hsFromLight(data) {
        var hs = data && data.hsColor
        if (!Array.isArray(hs) || hs.length < 2)
            return null
        var h = Math.round(parseFloat(hs[0]))
        var s = Math.round(parseFloat(hs[1]))
        if (isNaN(h) || isNaN(s))
            return null
        return [h, s]
    }

    function hsClose(a, b, toleranceDeg) {
        if (!Array.isArray(a) || !Array.isArray(b) || a.length < 1 || b.length < 1)
            return false
        var tol = toleranceDeg !== undefined ? toleranceDeg : 15
        var delta = Math.abs(Math.round(Number(a[0])) - Math.round(Number(b[0])))
        if (delta > 180)
            delta = 360 - delta
        return delta <= tol
    }

    component ClimateRow: ColumnLayout {
        required property var climateData
        readonly property var ha: root.ha
        Layout.fillWidth: true
        spacing: root.controlRowSpacing

        readonly property string entityId: String(climateData.entityId || "")
        readonly property bool available: climateData.available !== false
        readonly property bool heating: String(climateData.mode || "off") !== "off"
        readonly property int minTemp: 12
        readonly property int maxTemp: 25
        readonly property int targetTemp: {
            var n = parseFloat(climateData.target)
            if (isNaN(n))
                return minTemp
            return Math.max(minTemp, Math.min(maxTemp, Math.round(n)))
        }
        readonly property real currentValue: parseFloat(climateData.current)
        readonly property string unit: String(climateData.unit || "°C")
        readonly property string currentLabel: {
            if (isNaN(currentValue))
                return "—"
            return Number(currentValue).toFixed(1) + unit
        }

        property bool draftHeating: heating
        property bool pendingHeating: false
        property bool pendingTarget: false
        property int draftTarget: targetTemp
        property string syncedEntityId: ""

        function syncFromClimateData(force) {
            if (force || entityId !== syncedEntityId) {
                syncedEntityId = entityId
                pendingHeating = false
                pendingTarget = false
                draftHeating = heating
                draftTarget = targetTemp
                return
            }

            if (heating === draftHeating)
                pendingHeating = false
            else if (!pendingHeating)
                draftHeating = heating

            if (targetTemp === draftTarget)
                pendingTarget = false
            else if (!pendingTarget && !targetSlider.dragging)
                draftTarget = targetTemp
        }

        onClimateDataChanged: syncFromClimateData(false)

        onHeatingChanged: {
            if (!pendingHeating)
                draftHeating = heating
        }

        onTargetTempChanged: {
            if (!pendingTarget && !targetSlider.dragging)
                draftTarget = targetTemp
            else if (targetTemp === draftTarget)
                pendingTarget = false
        }

        Connections {
            target: ha
            enabled: ha !== null
            function onLastRefreshMsChanged() {
                if (pendingTarget && targetTemp === draftTarget)
                    pendingTarget = false
                syncFromClimateData(false)
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            label: currentLabel
            detail: draftHeating ? (String(draftTarget) + unit) : ""
            detailInline: true
            labelFontSize: Theme.fontSizeL
            detailFontSize: Theme.fontSizeL
            checked: draftHeating
            enabled: available && ha && !ha.climateBusy
            onToggled: {
                if (!ha)
                    return
                pendingHeating = true
                draftHeating = !draftHeating
                if (draftHeating) {
                    pendingTarget = true
                    ha.setClimateMode(entityId, "heat")
                    ha.setClimateTemperature(entityId, draftTarget)
                } else {
                    ha.setClimateMode(entityId, "off")
                }
            }
        }

        SliderSetting {
            id: targetSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            showHeader: false
            value: draftTarget
            minimum: minTemp
            maximum: maxTemp
            step: 1
            valueSuffix: unit
            enabled: available && ha && !ha.climateBusy && draftHeating
            onValueEdited: function(next) {
                pendingTarget = true
                draftTarget = next
            }
            onValueCommitted: function(next) {
                pendingTarget = true
                draftTarget = next
                if (!ha)
                    return
                ha.setClimateTemperature(entityId, next)
            }
        }

        TempGradientSlider {
            Layout.fillWidth: true
            value: draftTarget
            minimum: minTemp
            maximum: maxTemp
            step: 1
            interactive: false
            showTargetMarker: draftHeating
            enabled: available && ha
        }
    }

    component LightRow: ColumnLayout {
        required property var lightData
        readonly property var ha: root.ha
        property string rowTitle: String(lightData.area || lightData.name || "")
        Layout.fillWidth: true
        spacing: root.controlRowSpacing

        readonly property string entityId: String(lightData.entityId || "")
        readonly property bool isOn: lightData.on === true
        readonly property int brightnessPct: {
            var n = parseInt(lightData.brightnessPct, 10)
            return isNaN(n) ? 0 : n
        }
        readonly property bool available: lightData.available !== false
        readonly property bool showBrightness: lightData.supportsColor === true
            || (ha ? ha.lightHasBrightness(entityId) : false)
        readonly property bool showColor: lightData.supportsColor === true
            || (ha ? ha.lightHasColor(entityId) : false)
        readonly property var hs: root.hsFromLight(lightData)

        property int draftBrightness: brightnessPct
        property bool draftOn: isOn
        property bool pendingOn: false
        property bool pendingBrightness: false
        property bool colorCommitPending: false
        property int commitHsH: 0
        property int commitHsS: 100
        property string syncedEntityId: ""

        readonly property bool rowUsable: entityId !== "" && available !== false

        function syncPickerFromServer() {
            if (colorPicker.interacting || colorCommitPending)
                return
            var rgb = lightData.rgbColor
            if (Array.isArray(rgb) && rgb.length >= 3) {
                colorPicker.syncFromRgb(rgb[0], rgb[1], rgb[2])
                return
            }
            if (!hs)
                return
            colorPicker.syncFromHs(hs[0], hs[1])
        }

        onIsOnChanged: {
            if (!pendingOn)
                draftOn = isOn
        }

        function confirmCommittedColor() {
            if (!colorCommitPending)
                return
            if (!hs || !root.hsClose(hs, [commitHsH, commitHsS]))
                return
            colorCommitPending = false
            colorPicker.unlock()
        }

        function syncFromLightData(force) {
            if (force || entityId !== syncedEntityId) {
                syncedEntityId = entityId
                pendingOn = false
                pendingBrightness = false
                colorCommitPending = false
                colorPicker.unlock()
                draftOn = isOn
                draftBrightness = brightnessPct
                syncPickerFromServer()
                return
            }

            if (isOn === draftOn)
                pendingOn = false
            else if (!pendingOn)
                draftOn = isOn

            if (!pendingBrightness && !brightnessSlider.dragging)
                draftBrightness = brightnessPct

            syncPickerFromServer()
        }

        onLightDataChanged: syncFromLightData(false)

        onBrightnessPctChanged: {
            if (!pendingBrightness && !brightnessSlider.dragging)
                draftBrightness = brightnessPct
        }

        Connections {
            target: ha
            enabled: ha !== null
            function onLastRefreshMsChanged() {
                if (pendingOn && isOn === draftOn)
                    pendingOn = false
                if (pendingBrightness && brightnessPct === draftBrightness)
                    pendingBrightness = false
                confirmCommittedColor()
                syncFromLightData(false)
            }
            function onLightCommandFinished(finishedId, ok) {
                if (String(finishedId || "") !== entityId)
                    return
                if (ok) {
                    if (pendingBrightness)
                        pendingBrightness = false
                    return
                }
                colorCommitPending = false
                colorPicker.unlock()
                pendingBrightness = false
                draftBrightness = brightnessPct
                syncPickerFromServer()
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: rowTitle
            detail: !rowUsable
                ? "No light in this area"
                : (draftOn
                    ? (showBrightness ? (draftBrightness + "%") : "On")
                    : "Off")
            detailInline: true
            labelWrap: true
            labelFontSize: Theme.fontSizeL
            detailFontSize: Theme.fontSizeL
            checked: draftOn
            enabled: rowUsable && ha
            onToggled: {
                if (!ha)
                    return
                pendingOn = true
                draftOn = !draftOn
                ha.toggleLight(
                    entityId,
                    draftOn,
                    showBrightness && draftOn ? Math.max(draftBrightness, 1) : undefined
                )
            }
        }

        SliderSetting {
            id: brightnessSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            visible: draftOn && showBrightness
            showHeader: false
            value: draftBrightness
            minimum: 1
            maximum: 100
            step: 1
            enabled: available && ha
            onValueEdited: function(next) {
                pendingBrightness = true
                draftBrightness = next
                if (ha)
                    ha.patchLight(entityId, { on: true, brightnessPct: next, available: true })
            }
            onValueCommitted: function(next) {
                pendingBrightness = true
                draftBrightness = next
                if (!ha)
                    return
                ha.setLightBrightness(entityId, next)
            }
        }

        LightColorPicker {
            id: colorPicker
            Layout.fillWidth: true
            visible: draftOn && showColor
            enabled: available && ha
            Component.onCompleted: syncPickerFromServer()
            onColorCommitted: function(r, g, b) {
                if (!ha)
                    return
                commitHsH = Math.round(colorPicker.pickedHue * 360)
                commitHsS = 100
                colorCommitPending = true
                ha.setLightHue(
                    entityId,
                    colorPicker.pickedHue,
                    r,
                    g,
                    b,
                    showBrightness ? draftBrightness : undefined
                )
            }
        }
    }

    implicitHeight: column.implicitHeight

    function onActivated() {
        if (ha) {
            ha.popupActive = true
            ha.refresh()
        }
    }

    function onDeactivated() {
        if (ha)
            ha.popupActive = false
    }

    ColumnLayout {
        id: column
        width: root.hoverPanelWidth
        spacing: Theme.hoverPanelSectionSpacing

        Item {
            Layout.fillWidth: true
            implicitHeight: fieldsetRow.implicitHeight

            Row {
                id: fieldsetRow
                width: parent.width
                spacing: root.layoutColumnGap

                SectionPanel {
                    width: root.layoutColumnWidth
                    visible: root.climates.length > 0
                    label: ""
                    sectionSpacing: 8
                    contentPad: Theme.hoverPanelContentPad
                    legendBackground: Theme.background

                    HoverPanelLabelPill {
                        text: "Climate"
                        icon: "󰔏"
                        fontSize: Theme.fontSizeS
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Repeater {
                            model: root.climates

                            ClimateRow {
                                required property var modelData
                                climateData: modelData
                            }
                        }
                    }
                }

                SectionPanel {
                    width: root.layoutColumnWidth
                    label: ""
                    sectionSpacing: 8
                    contentPad: Theme.hoverPanelContentPad
                    legendBackground: Theme.background

                    HoverPanelLabelPill {
                        text: "Lights"
                        icon: "󰌵"
                        fontSize: Theme.fontSizeS
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        Repeater {
                            model: root.lightsConfigured ? root.areaRows : []

                            LightRow {
                                required property string modelData
                                readonly property string areaName: String(modelData || "")
                                readonly property var areaLight: root.lightForArea(areaName)
                                rowTitle: areaName
                                lightData: areaLight || ({
                                    entityId: "",
                                    area: areaName,
                                    name: areaName,
                                    on: false,
                                    available: false,
                                    supportsColor: false
                                })
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !root.lightsConfigured
                            text: "Choose light areas in Settings → Home Assistant"
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
