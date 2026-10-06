import QtQuick

Item {
    id: root

    property bool running: false
    property real pulseOpacity: 1
    property Item target: null
    property bool bindColor: false
    property color restColor: Theme.barIconColor
    property color activeColor: Theme.barIconColorActive

    Binding {
        target: root.target
        property: "color"
        value: root.running ? root.activeColor : root.restColor
        when: root.bindColor && root.target !== null
    }

    SequentialAnimation on pulseOpacity {
        running: root.running
        loops: Animation.Infinite

        NumberAnimation {
            from: Theme.barIconPulseMin
            to: Theme.barIconPulseMax
            duration: Theme.barIconPulseDuration
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            from: Theme.barIconPulseMax
            to: Theme.barIconPulseMin
            duration: Theme.barIconPulseDuration
            easing.type: Easing.InOutSine
        }
    }

    onRunningChanged: if (!running) pulseOpacity = 1
}
