import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string urlText: ""

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string addScript: home + "/.local/bin/evo-transmission"
    readonly property int dialogWidth: 520
    readonly property int dialogPad: 16
    readonly property int fieldHeight: 38
    readonly property int titleFont: Theme.fontSizeL
    readonly property int bodyFont: Theme.fontSizeM

    readonly property string promptOutput: {
        if (shell && shell.shellConfig && shell.shellConfig.notifications
                && shell.shellConfig.notifications.output)
            return String(shell.shellConfig.notifications.output).trim()
        return "DP-1"
    }

    readonly property var hostScreen: {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null
        var wanted = promptOutput
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (s && String(s.name) === wanted)
                return s
        }
        return screens[0]
    }

    function open(payloadJson) {
        urlText = ""
        opened = true
        Qt.callLater(function() {
            if (root.opened)
                urlField.forceActiveFocus()
        })
    }

    function close() {
        opened = false
        urlText = ""
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.transmission.add")
        else
            close()
    }

    function submit() {
        var url = urlText.trim()
        if (!url)
            return
        Quickshell.execDetached([
            "bash", "-lc",
            Util.shellQuote(addScript) + " add " + Util.shellQuote(url)
        ])
        dismiss()
    }

    PanelWindow {
        screen: root.hostScreen
        visible: root.opened && root.hostScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "evo-transmission-add"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: Theme.withOpacity(Theme.background, 0.62)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Item {
            id: dialog
            z: 1
            anchors.centerIn: parent
            width: root.dialogWidth
            implicitHeight: dialogColumn.implicitHeight + root.dialogPad * 2
            height: implicitHeight
            focus: root.opened

            Keys.onEscapePressed: root.dismiss()
            Keys.onReturnPressed: root.submit()

            Rectangle {
                anchors.fill: parent
                color: Theme.overlaySurface
                border.color: Theme.accent
                border.width: 1
            }

            ColumnLayout {
                id: dialogColumn
                anchors.fill: parent
                anchors.margins: root.dialogPad
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    Text {
                        text: "󰇚"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: root.titleFont
                        font.bold: Theme.fontBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Download"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: root.titleFont
                        font.bold: Theme.fontBold
                    }
                }

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
                            Keys.onEscapePressed: root.dismiss()
                            Keys.onReturnPressed: root.submit()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingL

                    Item {
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

                    Item {
                        implicitWidth: cancelActionRow.implicitWidth
                        implicitHeight: cancelActionRow.implicitHeight

                        RowLayout {
                            id: cancelActionRow
                            spacing: Theme.spacingM

                            Text {
                                text: "󰁍"
                                color: cancelAction.containsMouse ? Theme.urgent : Theme.foreground
                                opacity: cancelAction.containsMouse ? 1 : 0.55
                                font.family: Theme.fontFamily
                                font.pixelSize: root.bodyFont
                                font.bold: Theme.fontBold
                            }

                            Text {
                                text: "Cancel"
                                color: cancelAction.containsMouse ? Theme.urgent : Theme.foreground
                                opacity: cancelAction.containsMouse ? 1 : 0.55
                                font.family: Theme.fontFamily
                                font.pixelSize: root.bodyFont
                                font.bold: Theme.fontBold
                            }
                        }

                        MouseArea {
                            id: cancelAction
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismiss()
                        }
                    }
                }
            }
        }
    }
}
