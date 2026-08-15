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

    readonly property var barLayout: barConfig && barConfig.layout ? barConfig.layout : {}

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
        return screens
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

            anchors.top: root.position === "top"
            anchors.bottom: root.position === "bottom"
            anchors.left: root.position === "left" || root.position === "top" || root.position === "bottom"
            anchors.right: root.position === "right" || root.position === "top" || root.position === "bottom"

            WlrLayershell.namespace: "evo-bar"
            WlrLayershell.layer: WlrLayer.Top

            Rectangle {
                anchors.fill: parent
                color: Theme.mantle
                opacity: root.shell && root.shell.hoverPopupId ? 1.0 : Theme.surfaceOpacityInactive
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
                entries: Array.isArray(root.barLayout.left) ? root.barLayout.left : []
            }

            BarSection {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                bar: root
                barPanel: barPanel
                shell: root.shell
                barConfig: root.barConfig
                widgetRegistry: barWidgetRegistry
                entries: Array.isArray(root.barLayout.center) ? root.barLayout.center : []
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
                entries: Array.isArray(root.barLayout.right) ? root.barLayout.right : []
            }
        }
    }
}
