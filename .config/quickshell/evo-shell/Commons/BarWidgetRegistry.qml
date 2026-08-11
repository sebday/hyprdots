import QtQuick

// Instance, not a singleton — created by the bar host and passed into sections.
// Relative-path singleton imports create per-importer instances, so the shell
// host and bar must share one registry object.
QtObject {
    id: registry

    // { widgetId: { component: Component, metadata: var } }
    property var widgets: ({})
    property int revision: 0

    signal changed()

    function register(id, component, metadata) {
        var key = String(id)
        if (!key || !component) return
        var next = {}
        for (var k in widgets) next[k] = widgets[k]
        next[key] = { component: component, metadata: metadata || {} }
        widgets = next
        revision++
        changed()
    }

    function unregister(id) {
        var key = String(id)
        if (!widgets[key]) return
        var next = {}
        for (var k in widgets) if (k !== key) next[k] = widgets[k]
        widgets = next
        revision++
        changed()
    }

    function componentFor(id) {
        var entry = widgets[String(id)]
        return entry ? entry.component : null
    }

    function metadataFor(id) {
        var entry = widgets[String(id)]
        return entry ? entry.metadata : null
    }

    function availableIds() {
        return Object.keys(widgets)
    }

    function has(id) {
        return widgets[String(id)] !== undefined
    }
}
