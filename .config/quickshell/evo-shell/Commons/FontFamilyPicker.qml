import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: "Family"
    property string value: ""
    property var model: []
    property bool enabled: true
    property bool open: false
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

    implicitHeight: header.implicitHeight + (open ? (6 + listHeight) : 0)
    implicitWidth: 200
    opacity: root.enabled ? 1 : 0.45

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
        spacing: 6

        Text {
            text: root.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: Theme.fontBold
            Layout.fillWidth: true
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 30

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: Theme.panelMantle
                border.color: root.open || triggerMouse.containsMouse
                    ? Theme.accent
                    : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.22)
                border.width: 1
            }

            Text {
                anchors.left: parent.left
                anchors.right: chevron.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                text: root.value || "Select font"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: Theme.fontBold
                elide: Text.ElideRight
            }

            Text {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.open ? "󰅀" : "󰅂"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 14
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
        anchors.top: header.bottom
        anchors.topMargin: 6
        height: root.listHeight
        visible: root.open
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: 4
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
                    radius: 3
                    color: selected || hovered
                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                        : "transparent"
                    border.color: selected ? Theme.accent : "transparent"
                    border.width: selected ? 1 : 0
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: selected ? Theme.accent : Theme.foreground
                    font.family: String(modelData)
                    font.pixelSize: 12
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
