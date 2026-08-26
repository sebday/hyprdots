import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string value: ""
    property string label: ""
    property string icon: ""
    property color valueColor: Theme.accent
    property color iconColor: Theme.foreground
    property bool customFill: false
    property color customFillColor: Theme.panelMantle
    property int valueFontSize: Theme.fontSize5xl
    property int iconFontSize: Theme.fontSize6xl
    property int labelFontSize: Theme.fontSizeS
    property int contentPad: Theme.panelContentPad
    property bool clickable: false
    property bool special: false
    property bool labelInline: false
    property bool labelToggle: false
    property bool toggleVertical: false
    property bool toggleChecked: false
    property bool toggleEnabled: true
    property int toggleWidth: 30
    property int toggleHeight: 16
    property int toggleTrackRadius: 3
    property int toggleThumbRadius: 2
    property string suffixIcon: ""
    property string suffixValue: ""
    property string suffixLabel: ""
    property color suffixValueColor: Theme.foreground
    property color suffixIconColor: Theme.foreground
    property int suffixValueFontSize: Theme.fontSizeL
    property int suffixIconFontSize: Theme.fontSizeL

    readonly property bool hasIcon: root.icon !== ""
    readonly property bool hasSuffix: root.suffixIcon !== "" || root.suffixValue !== "" || root.suffixLabel !== ""
    readonly property int switchWidth: root.toggleVertical ? root.toggleWidth : root.toggleWidth
    readonly property int switchHeight: root.toggleVertical ? root.toggleHeight : root.toggleHeight

    signal clicked()
    signal toggleClicked()

    Layout.fillWidth: true
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    SectionPanel {
        id: panel
        anchors.fill: parent
        label: ""
        filled: true
        fillColor: root.customFill
            ? root.customFillColor
            : (root.special
                ? Theme.fillAccentSubtle
                : Theme.panelMantle)
        contentPad: root.contentPad

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing2

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                visible: root.hasIcon || (root.labelToggle && root.toggleVertical)
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: statContent.implicitHeight

                    RowLayout {
                        id: statContent
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenterOffset: root.labelToggle && root.toggleVertical
                            ? -root.switchWidth / 2
                            : 0
                        spacing: Theme.spacingS

                        Text {
                            text: root.icon
                            color: root.iconColor
                            font.family: Theme.fontFamily
                            font.pixelSize: root.iconFontSize
                            Layout.alignment: Qt.AlignVCenter
                            Layout.topMargin: 1
                        }

                        Text {
                            text: root.value
                            color: root.special ? Theme.accent : root.valueColor
                            font.family: Theme.fontFamily
                            font.pixelSize: root.valueFontSize
                            font.bold: Theme.fontBold
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            visible: root.hasSuffix
                            text: "·"
                            color: Theme.foreground
                            opacity: Theme.opacityMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.suffixValueFontSize
                            font.bold: Theme.fontBold
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: Theme.spacing2
                        }

                        RowLayout {
                            visible: root.hasSuffix
                            spacing: Theme.spacing2
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                visible: root.suffixIcon !== ""
                                text: root.suffixIcon
                                color: root.suffixIconColor
                                font.family: Theme.fontFamily
                                font.pixelSize: root.suffixIconFontSize
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                visible: root.suffixValue !== ""
                                text: root.suffixValue
                                color: root.suffixValueColor
                                font.family: Theme.fontFamily
                                font.pixelSize: root.suffixValueFontSize
                                font.bold: Theme.fontBold
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                visible: root.suffixLabel !== ""
                                text: root.suffixLabel
                                color: root.suffixValueColor
                                opacity: Theme.opacityMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        Text {
                            visible: root.labelInline && root.label !== ""
                            text: root.label
                            color: Theme.foreground
                            opacity: Theme.opacityMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.labelFontSize
                            font.bold: root.special ? Theme.fontBold : false
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                Item {
                    visible: root.labelToggle && root.toggleVertical
                    Layout.preferredWidth: root.labelToggle && root.toggleVertical ? root.switchWidth : 0
                    Layout.preferredHeight: root.labelToggle && root.toggleVertical ? root.switchHeight : 0
                    width: root.switchWidth
                    height: root.switchHeight
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: root.toggleTrackRadius
                        color: root.toggleChecked ? Theme.accent : Theme.foregroundSubtle
                        opacity: root.toggleEnabled ? 1 : Theme.opacityDisabled

                        Rectangle {
                            readonly property int thumbBreadth: Math.max(8, parent.width - 4)
                            readonly property int thumbSpan: root.toggleVertical
                                ? Math.max(8, Math.round(parent.height * 0.36))
                                : thumbBreadth
                            width: root.toggleVertical ? thumbBreadth : thumbSpan
                            height: root.toggleVertical ? thumbSpan : thumbSpan
                            radius: root.toggleThumbRadius
                            x: root.toggleVertical
                                ? (parent.width - width) / 2
                                : (root.toggleChecked ? parent.width - width - 2 : 2)
                            y: root.toggleVertical
                                ? (root.toggleChecked ? 2 : parent.height - height - 2)
                                : 2
                            color: root.toggleChecked ? Theme.background : Theme.foreground
                            Behavior on x {
                                enabled: !root.toggleVertical
                                NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
                            }
                            Behavior on y {
                                enabled: root.toggleVertical
                                NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.toggleEnabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleClicked()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.hasIcon
                horizontalAlignment: Text.AlignHCenter
                text: root.value
                color: root.special ? Theme.accent : root.valueColor
                font.family: Theme.fontFamily
                font.pixelSize: root.valueFontSize
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.label
                visible: !root.labelToggle && !root.labelInline && root.label !== ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
                font.bold: root.special ? Theme.fontBold : false
                opacity: root.special ? 0.82 : Theme.opacityMuted
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                visible: root.labelToggle && !root.toggleVertical
                width: root.switchWidth
                height: root.switchHeight

                Rectangle {
                    anchors.fill: parent
                    radius: root.toggleTrackRadius
                    color: root.toggleChecked ? Theme.accent : Theme.foregroundSubtle
                    opacity: root.toggleEnabled ? 1 : Theme.opacityDisabled

                    Rectangle {
                        readonly property int thumbBreadth: Math.max(8, parent.height - 4)
                        width: Math.max(10, parent.height - 4)
                        height: width
                        radius: root.toggleThumbRadius
                        y: 2
                        x: root.toggleChecked ? parent.width - width - 2 : 2
                        color: root.toggleChecked ? Theme.background : Theme.foreground
                        Behavior on x {
                            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.toggleEnabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleClicked()
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.special
        radius: Theme.fieldsetCornerRadius
        color: "transparent"
        border.color: Theme.withOpacity(Theme.accent, 0.45)
        border.width: 1
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
