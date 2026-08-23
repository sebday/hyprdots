import QtQuick
import QtQuick.Layouts
import "../../commons"

Item {
    id: root

    property var module: null

    implicitWidth: parent ? parent.width : Theme.settingsPanelWidth
    implicitHeight: settingsColumn.implicitHeight

                Item {
                    id: settingsColumn
                    width: parent.width
                    implicitHeight: settingsRow.implicitHeight
                    clip: true

                    readonly property int columnSpacing: Theme.hoverPanelSectionSpacing
                    readonly property int leftColumnWidth: Math.max(1, Math.floor((width - columnSpacing) * 0.66))
                    readonly property int rightColumnWidth: Math.max(1, width - columnSpacing - leftColumnWidth)

                    RowLayout {
                        id: settingsRow
                        width: parent.width
                        spacing: settingsColumn.columnSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: settingsColumn.leftColumnWidth
                            Layout.maximumWidth: settingsColumn.leftColumnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: settingsColumn.columnSpacing

                            SectionPanel {
                                visible: module.sectionFilterVisible("Looks")
                                        || module.sectionFilterVisible("Font")
                                Layout.fillWidth: true
                                Layout.preferredWidth: settingsColumn.leftColumnWidth
                                Layout.maximumWidth: settingsColumn.leftColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: settingsColumn.leftColumnWidth
                                legendBackground: Theme.background
                                label: ""

                                HoverPanelLabelPill {
                                    text: "Looks"
                                    icon: "󰒠"
                                    fontSize: Theme.fontSizeS
                                }


                                                ToggleRow {
                                                    Layout.fillWidth: true
                                                    label: "Border radius"
                                                    checked: module.roundingOn
                                                    enabled: module.hyprReady && !module.settingsBusy
                                                    onToggled: module.toggleHypr("rounding")
                                                }

                                                ToggleRow {
                                                    Layout.fillWidth: true
                                                    label: "Fieldset radius"
                                                    checked: module.fieldsetRoundingOn
                                                    enabled: module.uiReady && !module.settingsBusy
                                                    onToggled: module.toggleFieldsetRounding()
                                                }

                                                ToggleRow {
                                                    Layout.fillWidth: true
                                                    label: "Window gaps"
                                                    checked: module.gapsOn
                                                    enabled: module.hyprReady && !module.settingsBusy
                                                    onToggled: module.toggleHypr("gaps")
                                                }

                                                ToggleRow {
                                                    Layout.fillWidth: true
                                                    label: "Animations"
                                                    checked: module.animationsOn
                                                    enabled: module.hyprReady && !module.settingsBusy
                                                    onToggled: module.toggleHypr("animations")
                                                }

                                                SliderSetting {
                                                    Layout.fillWidth: true
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

                                                FontFamilyPicker {
                                                    Layout.fillWidth: true
                                                    label: "Family"
                                                    value: module.fontFamily
                                                    model: module.fontFamilies
                                                    enabled: module.fontReady && !module.settingsBusy
                                                    onActivated: function(family) {
                                                        module.fontFamily = family
                                                        module.setFont("family", family)
                                                    }
                                                }

                                                SliderSetting {
                                                    Layout.fillWidth: true
                                                    label: "UI scale"
                                                    value: module.fontScalePercent
                                                    valueSuffix: "%"
                                                    minimum: 50
                                                    maximum: 150
                                                    step: 10
                                                    enabled: false
                                                }

                                                SliderSetting {
                                                    Layout.fillWidth: true
                                                    label: "Lock after"
                                                    value: module.idleLockMin
                                                    minimum: 0
                                                    maximum: 120
                                                    step: 5
                                                    valueSuffix: "m"
                                                    enabled: module.idleReady && !module.settingsBusy
                                                    onValueCommitted: module.setIdleLockMin(value)
                                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: settingsColumn.rightColumnWidth
                            Layout.maximumWidth: settingsColumn.rightColumnWidth
                            Layout.alignment: Qt.AlignTop
                            spacing: settingsColumn.columnSpacing

                            SectionPanel {
                                visible: module.sectionFilterVisible("Theme")
                                Layout.fillWidth: true
                                Layout.preferredWidth: settingsColumn.rightColumnWidth
                                Layout.maximumWidth: settingsColumn.rightColumnWidth
                                Layout.alignment: Qt.AlignTop
                                width: settingsColumn.rightColumnWidth
                                legendBackground: Theme.background
                                label: ""

                                HoverPanelLabelPill {
                                    text: "Theme"
                                    icon: "󰸌"
                                    fontSize: Theme.fontSizeS
                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: themeCard.implicitHeight + 16
                                                    radius: 6
                                                    color: themePickMouse.containsMouse ? Theme.foregroundHoverWash : Theme.foregroundWash
                                                    border.color: Theme.foregroundDivider
                                                    border.width: 1

                                                    ColumnLayout {
                                                        id: themeCard
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        spacing: Theme.spacingS

                                                        Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 80
                                                            radius: 4
                                                            color: Theme.overlaySurface
                                                            clip: true

                                                            Image {
                                                                id: themePreviewImage
                                                                anchors.fill: parent
                                                                source: module.themePreviewSource ? Util.fileUrl(module.themePreviewSource) : ""
                                                                fillMode: Image.PreserveAspectCrop
                                                                smooth: true
                                                                asynchronous: true
                                                                cache: true
                                                                visible: module.themePreviewSource !== "" && status !== Image.Error
                                                            }

                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: module.themePreviewSource === "" || themePreviewImage.status === Image.Error
                                                                text: "󰸌"
                                                                color: Theme.accent
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: Theme.fontSize5xl
                                                            }
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            horizontalAlignment: Text.AlignHCenter
                                                            text: module.themeDisplayName
                                                            color: Theme.foreground
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeS
                                                            font.bold: Theme.fontBold
                                                            elide: Text.ElideRight
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: themePickMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: module.openThemePicker()
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: wallpaperCard.implicitHeight + 16
                                                    radius: 6
                                                    color: wallpaperPickMouse.containsMouse ? Theme.foregroundHoverWash : Theme.foregroundWash
                                                    border.color: Theme.foregroundDivider
                                                    border.width: 1

                                                    ColumnLayout {
                                                        id: wallpaperCard
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        spacing: Theme.spacingS

                                                        Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 80
                                                            radius: 4
                                                            color: Theme.overlaySurface
                                                            clip: true

                                                            Image {
                                                                id: wallpaperPreviewImage
                                                                anchors.fill: parent
                                                                source: module.wallpaperPreviewSource ? Util.fileUrl(module.wallpaperPreviewSource) : ""
                                                                fillMode: Image.PreserveAspectCrop
                                                                smooth: true
                                                                asynchronous: true
                                                                cache: true
                                                                visible: module.wallpaperPreviewSource !== "" && status !== Image.Error
                                                            }

                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: module.wallpaperPreviewSource === "" || wallpaperPreviewImage.status === Image.Error
                                                                text: "󰏘"
                                                                color: Theme.accent
                                                                font.family: Theme.fontFamily
                                                                font.pixelSize: Theme.fontSize5xl
                                                            }
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            horizontalAlignment: Text.AlignHCenter
                                                            text: module.wallpaperDisplayName
                                                            color: Theme.foreground
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeS
                                                            font.bold: Theme.fontBold
                                                            elide: Text.ElideRight
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: wallpaperPickMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: module.openWallpaperPicker()
                                                    }
                                                }
                            }
                        }
                    }
                }

}
