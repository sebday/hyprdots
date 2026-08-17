import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property string placeholder: "Select…"
    property var options: []
    property var selected: []
    property bool enabled: true
    property bool open: false
    property int popupMaxHeight: 200

    signal selectionChanged(var selected)

    readonly property var selectedSet: {
        var out = {}
        for (var i = 0; i < selected.length; i++)
            out[String(selected[i])] = true
        return out
    }

    readonly property string summaryText: {
        if (!options || options.length === 0)
            return root.placeholder
        var count = selected.length
        if (count === 0)
            return "None selected"
        if (count === options.length)
            return "All shows (" + count + ")"
        if (count === 1)
            return String(selected[0])
        if (count === 2)
            return String(selected[0]) + ", " + String(selected[1])
        return count + " shows selected"
    }

    readonly property int listHeight: open
        ? Math.min(popupMaxHeight, Math.max(28, options.length * 28) + 8)
        : 0

    implicitHeight: header.implicitHeight + (open ? (6 + listHeight) : 0)
    implicitWidth: 200
    opacity: root.enabled ? 1 : 0.45

    function toggle() {
        if (!root.enabled) return
        open = !open
    }

    function close() {
        open = false
    }

    function isSelected(name) {
        return !!selectedSet[String(name)]
    }

    function toggleOption(name) {
        var key = String(name)
        var next = []
        var found = false
        for (var i = 0; i < selected.length; i++) {
            if (String(selected[i]) === key) {
                found = true
                continue
            }
            next.push(selected[i])
        }
        if (!found)
            next.push(name)
        next.sort(function(a, b) {
            return String(a).localeCompare(String(b))
        })
        root.selectionChanged(next)
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
            font.pixelSize: Theme.fontSizeM
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
                text: root.summaryText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
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
                font.pixelSize: Theme.fontSizeL
                opacity: 0.7
            }

            MouseArea {
                id: triggerMouse
                anchors.fill: parent
                enabled: root.enabled && root.options.length > 0
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
            model: root.options
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                required property var modelData
                required property int index
                width: listView.width
                height: 28

                readonly property bool checked: root.isSelected(modelData)
                readonly property bool hovered: optionMouse.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: checked || hovered
                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                        : "transparent"
                    border.color: checked ? Theme.accent : "transparent"
                    border.width: checked ? 1 : 0
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: checked ? "󰄬" : "󰄱"
                        color: checked ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeL
                        opacity: checked ? 1 : 0.45
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData
                        color: checked ? Theme.accent : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        font.bold: Theme.fontBold
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleOption(modelData)
                }
            }
        }
    }
}
