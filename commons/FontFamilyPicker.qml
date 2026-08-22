import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: "Family"
    property string value: ""
    property var model: []
    property bool enabled: true
    property bool open: false
    property bool previewFont: true
    property bool labelBold: true
    property bool externalTrigger: false
    property int labelFontSize: Theme.fontSizeM
    property int popupMaxHeight: 160

    signal activated(string value)

    readonly property int currentIndex: {
        for (var i = 0; i < model.length; i++) {
            if (String(model[i]) === String(value))
                return i
        }
        return -1
    }

    readonly property int listHeight: open
        ? Math.min(popupMaxHeight, Math.max(28, model.length * 28) + 8)
        : 0

    implicitHeight: (root.externalTrigger ? 0 : header.implicitHeight) + (open ? ((root.externalTrigger ? 0 : 6) + listHeight) : 0)
    implicitWidth: 200
    opacity: root.enabled ? 1 : Theme.opacityDisabled
    z: root.open ? 100 : 0

    function toggle() {
        if (!root.enabled) return
        open = !open
        if (open && currentIndex >= 0)
            Qt.callLater(function() {
                listView.positionViewAtIndex(root.currentIndex, ListView.Contain)
            })
    }

    function close() {
        open = false
    }

    ColumnLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.spacingS

        Text {
            visible: !root.externalTrigger && root.label !== ""
            text: root.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: root.labelFontSize
            font.bold: root.labelBold ? Theme.fontBold : false
            opacity: Theme.opacityMuted
            Layout.fillWidth: true
        }

        Item {
            visible: !root.externalTrigger
            Layout.fillWidth: true
            Layout.preferredHeight: 30

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusL
                color: Theme.panelMantle
                border.color: root.open || triggerMouse.containsMouse
                    ? Theme.accent
                    : Theme.foregroundPickerBorder
                border.width: 1
            }

            Text {
                anchors.left: parent.left
                anchors.right: chevron.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.panelContentPad
                anchors.rightMargin: Theme.spacingM
                text: root.value || (root.previewFont ? "Select font" : "Select…")
                color: Theme.foreground
                font.family: root.previewFont && root.value ? String(root.value) : Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: Theme.panelContentPad
                anchors.verticalCenter: parent.verticalCenter
                text: root.open ? "󰅀" : "󰅂"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeL
                opacity: 0.7
            }

            MouseArea {
                id: triggerMouse
                anchors.fill: parent
                enabled: root.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle()
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.externalTrigger ? parent.top : header.bottom
        anchors.topMargin: root.externalTrigger ? 0 : Theme.spacingS
        height: root.listHeight
        visible: root.open
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusL
            color: Theme.panelMantle
            border.color: Theme.accent
            border.width: 1
        }

        ListView {
            id: listView
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: root.model
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.currentIndex

            delegate: Item {
                required property var modelData
                required property int index
                width: listView.width
                height: 28

                readonly property bool selected: String(modelData) === String(root.value)
                readonly property bool hovered: optionMouse.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusM
                    color: selected || hovered
                        ? Theme.foregroundFaint
                        : "transparent"
                    border.color: selected ? Theme.accent : "transparent"
                    border.width: selected ? 1 : 0
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: selected ? Theme.accent : Theme.foreground
                    font.family: root.previewFont ? String(modelData) : Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.activated(String(modelData))
                        root.close()
                    }
                }
            }
        }
    }
}
