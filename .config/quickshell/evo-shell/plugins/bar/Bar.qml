import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "."
import "widgets"

Scope {
    id: root

    property var shell: null
    property var barConfig: ({})

    BarWidgetRegistry { id: barWidgetRegistry }

    BarWidgetCatalog {
        registry: barWidgetRegistry
    }

    readonly property string position: {
        var p = barConfig && barConfig.position ? String(barConfig.position) : "bottom"
        return p
    }

    readonly property string barOutput: {
        if (barConfig && barConfig.output) return String(barConfig.output).trim()
        return ""
    }

    readonly property bool barOnDp1Top: barOutput === "DP-1" && position === "top"

    function barEntries(section) {
        var layout = barConfig && barConfig.layout ? barConfig.layout : {}
        var entries = Array.isArray(layout[section]) ? layout[section] : []
        if (!barOnDp1Top) return entries
        return entries.filter(function(entry) {
            var id = String(entry && entry.id ? entry.id : "")
            return id !== "evo.shopify" && id !== "evo.github"
        })
    }

    readonly property var barScreenModel: {
        var screens = Quickshell.screens
        if (!screens || screens.length === 0) return []
        var output = barOutput
        if (!output) return screens
        var matched = []
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (s && String(s.name) === output) matched.push(s)
        }
        if (matched.length > 0) return matched
        var fallback = Util.screenForOutput("", true)
        return fallback ? [fallback] : screens
    }

    Variants {
        model: root.barScreenModel

        PanelWindow {
            id: barPanel
            required property var modelData
            screen: modelData
            color: "transparent"
            implicitHeight: root.position === "top" || root.position === "bottom" ? Theme.barHeight : 0
            implicitWidth: root.position === "left" || root.position === "right" ? Theme.barHeight : 0

            property bool hovered: false
            readonly property bool surfaceActive: hovered

            function syncHover() {
                hovered = barHover.hovered || barHoverCatcher.containsMouse
            }

            anchors.top: root.position === "top"
            anchors.bottom: root.position === "bottom"
            anchors.left: root.position === "left" || root.position === "top" || root.position === "bottom"
            anchors.right: root.position === "right" || root.position === "top" || root.position === "bottom"

            WlrLayershell.namespace: "evo-bar"
            WlrLayershell.layer: WlrLayer.Top

            Item {
                anchors.fill: parent

                HoverHandler {
                    id: barHover
                    onHoveredChanged: barPanel.syncHover()
                }

                MouseArea {
                    id: barHoverCatcher
                    anchors.fill: parent
                    z: 100
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: barPanel.syncHover()
                    onWheel: function(wheel) { wheel.accepted = false }
                }

                Rectangle {
                    anchors.fill: parent
                    z: -1
                    color: Theme.mantle
                    opacity: barPanel.surfaceActive ? Theme.surfaceOpacity : Theme.surfaceOpacityInactive

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }

            BarSection {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                sectionMargin: Theme.barGap
                bar: root
                barPanel: barPanel
                shell: root.shell
                barConfig: root.barConfig
                widgetRegistry: barWidgetRegistry
                entries: root.barEntries("left")
            }

            BarSection {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                bar: root
                barPanel: barPanel
                shell: root.shell
                barConfig: root.barConfig
                widgetRegistry: barWidgetRegistry
                entries: root.barEntries("center")
            }

            BarSection {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                sectionMargin: Theme.barGap
                bar: root
                barPanel: barPanel
                shell: root.shell
                barConfig: root.barConfig
                widgetRegistry: barWidgetRegistry
                entries: root.barEntries("right")
            }
            }
        }
    }
}
