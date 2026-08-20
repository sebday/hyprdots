import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../Commons"
import "."

PanelWindow {
    id: root

    required property var entry
    required property int stackIndex

    property var fields: ({})
    property string coverArt: ""
    property int artRev: 0
    property string fallbackIcon: "󰎆"
    property int imageFillMode: Image.PreserveAspectCrop
    property bool hyprshot: false
    property var popupScreen: null
    property bool popupOnTop: false
    property var stackOffsets: []
    property int popupMarginFromEdge: 0
    property int popupMarginLeft: 0

    signal dismissed()
    signal openScreenshot()
    signal artError(string source)
    signal artReady(string source)
    signal opened()

    readonly property int stackOffset: stackIndex < stackOffsets.length
        ? stackOffsets[stackIndex]
        : popupMarginFromEdge

    screen: popupScreen
    color: "transparent"
    implicitWidth: Theme.notificationWidth
    implicitHeight: card.height

    anchors.top: popupOnTop
    anchors.bottom: !popupOnTop
    anchors.left: true
    margins.top: popupOnTop ? stackOffset : 0
    margins.bottom: popupOnTop ? 0 : stackOffset
    margins.left: popupMarginLeft

    Component.onCompleted: opened()

    WlrLayershell.namespace: "evo-sys-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Item {
        id: card
        width: Theme.notificationWidth
        height: artworkCard.implicitHeight
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.panelCornerRadius
            color: Theme.overlaySurface
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.panelCornerRadius
            color: "transparent"
            border.color: Theme.accent
            border.width: 2
        }

        NotificationCard {
            id: artworkCard
            coverArt: root.coverArt
            artRev: root.artRev
            fallbackIcon: root.fallbackIcon
            fields: root.fields
            imageFillMode: root.imageFillMode
            onArtError: function(source) { root.artError(source) }
            onArtReady: function(source) { root.artReady(source) }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.hyprshot ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) {
            if (!entry)
                return
            if (mouse.button === Qt.RightButton)
                root.dismissed()
            else if (mouse.button === Qt.LeftButton && root.hyprshot)
                root.openScreenshot()
        }
    }
}
