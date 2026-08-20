import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../Commons"
import "Model.js" as Model

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property var ha: shell ? shell.serviceFor("evo.bar.popups.home-assistant") : null
    readonly property bool contentReady: !ha || ha.lastRefreshMs > 0 || (ha.lastError !== "" && ha.data)
    readonly property int hintFont: Theme.fontSizeL

    property double nowMs: Date.now()

    readonly property var cameras: ha ? ha.cameras : []
    readonly property var climates: ha ? ha.climates : []
    readonly property var lights: ha ? ha.lights : []
    readonly property var selectedLight: root.lightForArea("Shed")
    readonly property int layoutColumnCount: 2
    readonly property int layoutColumnGap: Theme.spacingM
    readonly property int layoutColumnWidth: Math.max(0, Math.floor(
        (root.hoverPopupWidth - root.layoutColumnGap * (root.layoutColumnCount - 1))
        / root.layoutColumnCount))

    function lightForArea(area) {
        var target = String(area || "")
        for (var i = 0; i < root.lights.length; i++) {
            if (String(root.lights[i].area || "") === target)
                return root.lights[i]
        }
        return null
    }

    function rgbFromLight(data) {
        var rgb = data && data.rgbColor
        if (Array.isArray(rgb) && rgb.length >= 3)
            return [parseInt(rgb[0], 10), parseInt(rgb[1], 10), parseInt(rgb[2], 10)]
        var hs = data && data.hsColor
        if (Array.isArray(hs) && hs.length >= 2) {
            var hue = parseFloat(hs[0]) / 360
            var sat = parseFloat(hs[1]) / 100
            if (isNaN(hue) || isNaN(sat))
                return [255, 180, 80]
            var pct = parseInt(data.brightnessPct, 10)
            var val = isNaN(pct) ? 1 : Math.max(0.35, Math.min(1, pct / 100))
            var c = Qt.hsv(hue, Math.max(0, Math.min(1, sat)), val)
            return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)]
        }
        return [255, 180, 80]
    }

    function rgbClose(r1, g1, b1, r2, g2, b2, tolerance) {
        var tol = tolerance !== undefined ? tolerance : 14
        return Math.abs(r1 - r2) <= tol
            && Math.abs(g1 - g2) <= tol
            && Math.abs(b1 - b2) <= tol
    }

    function hueOfRgb(r, g, b) {
        var c = Qt.rgba(r / 255, g / 255, b / 255, 1)
        return c.hsvHue >= 0 ? c.hsvHue : 0
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
        Layout.fillWidth: true
        spacing: Theme.spacingM

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
        readonly property color aqiTone: root.aqiColor(ha && ha.airQuality ? ha.airQuality.value : NaN)
        readonly property string aqiLabelText: ha && ha.airQuality && ha.airQuality.label
            ? String(ha.airQuality.label)
            : "AQI"

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
            else if (!pendingTarget)
                draftTarget = targetTemp
        }

        onClimateDataChanged: syncFromClimateData(false)

        onHeatingChanged: {
            if (!pendingHeating)
                draftHeating = heating
        }

        onTargetTempChanged: {
            if (!pendingTarget)
                draftTarget = targetTemp
            else if (targetTemp === draftTarget)
                pendingTarget = false
        }

        Connections {
            target: ha
            enabled: ha !== null
            function onLastRefreshMsChanged() {
                syncFromClimateData(false)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacingS
            rowSpacing: Theme.spacingS

            HoverPopupStatBox {
                Layout.fillWidth: true
                icon: "󰔏"
                value: currentLabel
                special: true
                labelToggle: true
                toggleVertical: true
                toggleChecked: draftHeating
                toggleEnabled: available && ha && !ha.climateBusy
                toggleWidth: 12
                toggleHeight: 26
                valueColor: root.climateTempColor(currentValue)
                iconColor: root.climateTempColor(currentValue)
                onToggleClicked: {
                    if (!ha)
                        return
                    pendingHeating = true
                    draftHeating = !draftHeating
                    if (draftHeating) {
                        draftTarget = minTemp
                        pendingTarget = true
                        ha.setClimateTemperature(entityId, minTemp)
                    }
                    ha.setClimateMode(entityId, draftHeating ? "heat" : "off")
                }
            }

            HoverPopupStatBox {
                Layout.fillWidth: true
                icon: "󰂫"
                value: root.aqiValueText()
                label: aqiLabelText
                labelInline: true
                valueColor: aqiTone
                iconColor: aqiTone
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: draftHeating
            text: String(draftTarget) + "°"
            color: root.climateTempColor(draftTarget)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize4xl
            font.bold: Theme.fontBold
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            TempGradientSlider {
                Layout.fillWidth: true
                value: draftTarget
                minimum: minTemp
                maximum: maxTemp
                step: 1
                interactive: draftHeating
                enabled: available && ha
                onDragStarted: pendingTarget = true
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
        }
    }

    component LightRow: ColumnLayout {
        required property var lightData
        Layout.fillWidth: true
        spacing: Theme.spacingS

        readonly property string entityId: String(lightData.entityId || "")
        readonly property bool isOn: lightData.on === true
        readonly property int brightnessPct: {
            var n = parseInt(lightData.brightnessPct, 10)
            return isNaN(n) ? 0 : n
        }
        readonly property bool available: lightData.available !== false
        readonly property bool showBrightness: lightData.supportsColor === true
            || (ha ? ha.lightHasBrightness(entityId) : false)
        readonly property bool showColor: ha ? ha.lightHasColor(entityId) : lightData.supportsColor === true
        readonly property var hs: root.hsFromLight(lightData)

        property int draftBrightness: brightnessPct
        property bool draftOn: isOn
        property bool pendingOn: false
        property bool pendingBrightness: false
        property bool colorCommitPending: false
        property int commitHsH: 0
        property int commitHsS: 100
        property string syncedEntityId: ""

        function syncPickerFromServer() {
            if (colorPicker.interacting || colorCommitPending)
                return
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
            label: String(lightData.name || lightData.entityId || "Light")
            detail: draftOn
                ? (showBrightness ? (draftBrightness + "%") : "On")
                : "Off"
            detailInline: true
            checked: draftOn
            enabled: available && ha
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

    function bootstrapFromCache() {
        if (ha)
            ha.seedSnapshotsFromCache(false)
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

    function climateTempColor(temp) {
        var n = Number(temp)
        if (isNaN(n))
            return Theme.accent
        return Theme.mixColors(Qt.color("#6ec8ff"), Theme.urgent, Math.max(0, Math.min(1, (n - 12) / 13)))
    }

    function aqiColor(value) {
        var n = Number(value)
        if (isNaN(n))
            return Theme.foreground
        if (n < 20)
            return Theme.accent
        if (n < 60)
            return Theme.mixColors(Theme.accent, Theme.urgent, 0.45)
        return Theme.urgent
    }

    function aqiValueText() {
        if (!ha || !ha.airQuality || ha.airQuality.available !== true)
            return "—"
        var n = Number(ha.airQuality.value)
        if (isNaN(n))
            return "—"
        return String(Math.round(n))
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
            visible: root.climates.length > 0
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
                    model: root.climates

                    ClimateRow {
                        required property var modelData
                        climateData: modelData
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: fieldsetRow.implicitHeight

            Row {
                id: fieldsetRow
                width: parent.width
                spacing: root.layoutColumnGap

                SectionPanel {
                    width: root.layoutColumnWidth
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

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: cameraOverlayRow.implicitHeight + 8
                                            color: Theme.withOpacity(Theme.background, 0.72)
                                        }

                                        RowLayout {
                                            id: cameraOverlayRow
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 4
                                            spacing: Theme.spacingS

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
                                                visible: root.snapshotAge(cameraColumn.parent.entityId) !== ""
                                                text: root.snapshotAge(cameraColumn.parent.entityId)
                                                color: Theme.foreground
                                                opacity: Theme.opacityMuted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                horizontalAlignment: Text.AlignRight
                                                elide: Text.ElideLeft
                                                maximumLineCount: 1
                                            }
                                        }
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

                SectionPanel {
                    width: root.layoutColumnWidth
                    label: ""
                    sectionSpacing: 8
                    contentPad: Theme.hoverPopupContentPad
                    legendBackground: Theme.background

                    HoverPopupLabelPill {
                        text: "Lights"
                        icon: "󰌵"
                        fontSize: Theme.fontSizeS
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        LightRow {
                            Layout.fillWidth: true
                            visible: root.selectedLight !== null
                            lightData: root.selectedLight || ({
                                entityId: "",
                                name: "",
                                on: false,
                                available: false,
                                supportsColor: false
                            })
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.lights.length === 0
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
