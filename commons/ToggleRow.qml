import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string icon: ""
    property string detail: ""
    property bool detailInline: false
    property bool checked: false
    property bool enabled: true
    property bool labelWrap: false
    property int labelFontSize: Theme.fontSizeM
    property int detailFontSize: Theme.fontSizeM

    signal toggled()

    implicitHeight: row.implicitHeight
    implicitWidth: 200

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.spacingL

        RowLayout {
            visible: !root.detailInline
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Text {
                visible: root.icon !== ""
                text: root.icon
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
                font.bold: Theme.fontBold
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing2

            Text {
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: root.detail !== ""
                text: root.detail
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                opacity: Theme.opacityMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            }
        }

        RowLayout {
            visible: root.detailInline && !root.labelWrap
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Text {
                visible: root.icon !== ""
                text: root.icon
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
                font.bold: Theme.fontBold
            }

            Text {
                text: root.label
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                visible: root.detail !== ""
                text: root.detail
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.detailFontSize
                opacity: Theme.opacityMuted
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            visible: root.detailInline && root.labelWrap
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Text {
                visible: root.icon !== ""
                text: root.icon
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: root.labelFontSize
                font.bold: Theme.fontBold
                Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing2

                Text {
                    text: root.label
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.labelFontSize
                    font.bold: Theme.fontBold
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.detail !== ""
                    text: root.detail
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.detailFontSize
                    opacity: Theme.opacityMuted
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignTop

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: root.checked ? Theme.accent : Theme.foregroundSubtle
                opacity: root.enabled ? 1 : Theme.opacityDisabled

                Rectangle {
                    width: 18
                    height: 18
                    radius: 2
                    y: 3
                    x: root.checked ? parent.width - width - 3 : 3
                    color: root.checked ? Theme.background : Theme.foreground
                    Behavior on x {
                        NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
