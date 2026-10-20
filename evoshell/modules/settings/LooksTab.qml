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

    component PreviewRow: Item {
        id: row

        property string label: ""
        property string title: ""
        property string source: ""
        property string fallbackIcon: ""
        property bool keyboardSelected: false
        readonly property bool settingsNavActivate: true
        signal clicked()

        readonly property int rowPad: Theme.settingsNavRowPad
        readonly property int thumbH: Theme.launcherRowHeight
        readonly property int thumbW: Theme.launcherRowHeight * 2
        implicitHeight: line.implicitHeight + rowPad * 2

        Rectangle {
            anchors.fill: parent
            visible: row.keyboardSelected || rowMouse.containsMouse
            radius: Theme.radiusM
            color: Theme.foregroundWash
            opacity: 0.85
        }

        RowLayout {
            id: line
            anchors.fill: parent
            anchors.margins: row.rowPad
            spacing: Theme.spacingL

            Text {
                Layout.fillWidth: true
                text: row.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                text: row.title
                color: Theme.foreground
                opacity: Theme.opacityMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
                Layout.maximumWidth: parent.width * 0.45
            }

            Rectangle {
                Layout.preferredWidth: row.thumbW
                Layout.preferredHeight: row.thumbH
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.radiusS
                color: Theme.overlaySurface
                clip: true

                Image {
                    id: previewImage
                    anchors.fill: parent
                    source: row.source ? Util.fileUrl(row.source) : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    cache: true
                    visible: row.source !== "" && status !== Image.Error
                }

                Text {
                    anchors.centerIn: parent
                    visible: row.source === "" || previewImage.status === Image.Error
                    text: row.fallbackIcon
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.bold: Theme.fontBold
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    ColumnLayout {
        id: settingsColumn
        width: parent.width
        spacing: Theme.spacingM

            PreviewRow {
                Layout.fillWidth: true
                visible: root.rowVisible(["Theme"])
                label: "Theme"
                title: module ? module.themeDisplayName : ""
                source: module ? module.themePreviewSource : ""
                fallbackIcon: "󰸌"
                onClicked: module.openThemePicker()
            }

            PreviewRow {
                Layout.fillWidth: true
                visible: root.rowVisible(["Wallpaper"])
                label: "Wallpaper"
                title: module ? module.wallpaperDisplayName : ""
                source: module ? module.wallpaperPreviewSource : ""
                fallbackIcon: "󰏘"
                onClicked: module.openWallpaperPicker()
            }

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
