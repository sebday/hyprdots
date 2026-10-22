import QtQuick
import QtQuick.Layouts
import qs.commons

Item {
    id: root

    property var module: null

    implicitWidth: parent ? parent.width : Theme.settingsPanelWidth
    implicitHeight: settingsColumn.implicitHeight

    function rowVisible(labels) {
        if (!module)
            return true
        var q = String(module.menuFilterText || "").trim()
        if (q === "" || module.sectionFilterVisible("Looks"))
            return true
        for (var i = 0; i < labels.length; i++) {
            if (module.sectionFilterVisible(labels[i]))
                return true
        }
        return false
    }

    ColumnLayout {
        id: settingsColumn
        width: parent.width
        spacing: Theme.spacingM

            SliderSetting {
                Layout.fillWidth: true
                visible: root.rowVisible(["Active opacity", "Opacity", "Window"])
                label: "Active opacity"
                value: module.activeOpacityPercent
                valueSuffix: "%"
                minimum: 0
                maximum: 100
                step: 1
                enabled: module.hyprReady && !module.settingsBusy
                onValueEdited: function(v) {
                    module.activeOpacityPercent = v
                }
                onValueCommitted: function(v) {
                    module.activeOpacityPercent = v
                    module.setHyprOpacity("active", v)
                }
            }

            SliderSetting {
                Layout.fillWidth: true
                visible: root.rowVisible(["Inactive opacity", "Opacity", "Window"])
                label: "Inactive opacity"
                value: module.inactiveOpacityPercent
                valueSuffix: "%"
                minimum: 0
                maximum: 100
                step: 1
                enabled: module.hyprReady && !module.settingsBusy
                onValueEdited: function(v) {
                    module.inactiveOpacityPercent = v
                }
                onValueCommitted: function(v) {
                    module.inactiveOpacityPercent = v
                    module.setHyprOpacity("inactive", v)
                }
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Border radius"
                labelFontSize: Theme.fontSizeS
                detailFontSize: Theme.fontSizeS
                visible: root.rowVisible(["Border radius", "Window"])
                checked: Theme.roundingOn
                enabled: module.hyprReady && !module.settingsBusy
                onToggled: module.toggleHypr("rounding")
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Fieldset radius"
                labelFontSize: Theme.fontSizeS
                detailFontSize: Theme.fontSizeS
                visible: root.rowVisible(["Fieldset radius", "Window"])
                checked: module.fieldsetRoundingOn
                enabled: module.uiReady && !module.settingsBusy
                onToggled: module.toggleFieldsetRounding()
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Window gaps"
                labelFontSize: Theme.fontSizeS
                detailFontSize: Theme.fontSizeS
                visible: root.rowVisible(["Window gaps", "Gaps", "Window"])
                checked: module.gapsOn
                enabled: module.hyprReady && !module.settingsBusy
                onToggled: module.toggleHypr("gaps")
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Animations"
                labelFontSize: Theme.fontSizeS
                detailFontSize: Theme.fontSizeS
                visible: root.rowVisible(["Animations", "Window"])
                checked: module.animationsOn
                enabled: module.hyprReady && !module.settingsBusy
                onToggled: module.toggleHypr("animations")
            }
        }
    }
