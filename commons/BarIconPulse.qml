import QtQuick

Item {
    id: root

    property Item target: null
    property bool running: false
    property color restColor: Theme.barIconColor
    property color activeColor: Theme.barIconColorActive

    Binding {
        target: root.target
        property: "color"
        value: root.running ? root.activeColor : root.restColor
        when: root.target !== null
    }

    SequentialAnimation {
        running: root.running && root.target
        loops: Animation.Infinite

        NumberAnimation {
            target: root.target
            property: "opacity"
            from: Theme.barIconPulseMin
            to: Theme.barIconPulseMax
            duration: Theme.barIconPulseDuration
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: root.target
            property: "opacity"
            from: Theme.barIconPulseMax
            to: Theme.barIconPulseMin
            duration: Theme.barIconPulseDuration
            easing.type: Easing.InOutSine
        }
    }
}
