import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property string urlText: ""
    property int bodyFont: Theme.fontSizeM
    property int fieldHeight: 38

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string addScript: home + "/.local/bin/evo-bar-transmission"

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    signal submitted()

    function clear() {
        urlText = ""
        urlField.text = ""
    }

    function focusField() {
        urlField.forceActiveFocus()
    }

    function submit() {
        var url = urlText.trim()
        if (!url)
            return
        Quickshell.execDetached([
            "bash", "-lc",
            Util.shellQuote(addScript) + " add " + Util.shellQuote(url)
        ])
        clear()
        root.submitted()
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.spacingM

        FramedPanel {
            Layout.fillWidth: true
            label: "URL or magnet link"
            filled: true
            contentPad: 12
            labelGap: 6

            Item {
                width: parent.width
                height: root.fieldHeight

                Text {
                    visible: urlField.text.length === 0 && !urlField.activeFocus
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "https://… or magnet:…"
                    color: Theme.foreground
                    opacity: Theme.opacityDisabled
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                    font.bold: Theme.fontBold
                }

                TextInput {
                    id: urlField
                    anchors.fill: parent
                    text: root.urlText
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                    font.bold: Theme.fontBold
                    selectByMouse: true
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    onTextEdited: root.urlText = text
                    Keys.onReturnPressed: root.submit()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitWidth: downloadActionRow.implicitWidth
            implicitHeight: downloadActionRow.implicitHeight

            RowLayout {
                id: downloadActionRow
                spacing: Theme.spacingM

                Text {
                    text: "󰁝"
                    color: downloadAction.containsMouse ? Theme.accent : Theme.foreground
                    opacity: downloadAction.containsMouse ? 1 : 0.72
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                    font.bold: Theme.fontBold
                }

                Text {
                    text: "Download"
                    color: downloadAction.containsMouse ? Theme.accent : Theme.foreground
                    opacity: downloadAction.containsMouse ? 1 : 0.72
                    font.family: Theme.fontFamily
                    font.pixelSize: root.bodyFont
                    font.bold: Theme.fontBold
                }
            }

            MouseArea {
                id: downloadAction
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submit()
            }
        }
    }
}
