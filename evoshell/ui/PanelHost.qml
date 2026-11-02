import QtQuick

// Bar widget that loads its popup from panelUrl. The button, glyph, and
// icon state stay on the widget. panelUrl must be resolved there:
// Qt.resolvedUrl in this file would point at ui/.
BarWidget {
  id: root

  property url panelUrl
  property Item anchor: null

  readonly property var panel: panelLoader.item
  readonly property bool opened: panel ? panel.opened === true : false
  readonly property bool popoutSwitchClosing: panel ? panel.popoutSwitchClosing === true : false

  // Widgets that need work before the panel refresh (clock tick, Cloudflare
  // service) handle this. Cursor sets forceRefresh so the panel skips cache.
  signal beforeRefresh()
  property bool forceRefresh: false

  function injectPanel() {
    var target = panel
    if (!target)
      return
    if ("bar" in target)
      target.bar = root.bar
    if ("settings" in target)
      target.settings = root.settings
    if ("anchorItem" in target)
      target.anchorItem = root.anchor
    if ("hostWidget" in target)
      target.hostWidget = root
  }

  function refresh() {
    beforeRefresh()
    if (panel && typeof panel.refresh === "function")
      panel.refresh(forceRefresh)
  }

  function togglePanel() {
    if (panel && panel.toggle)
      panel.toggle()
  }

  function open() {
    var target = panel
    if (!target)
      return
    if (typeof target.openFromHotkey === "function")
      target.openFromHotkey()
    else if (typeof target.open === "function")
      target.open()
  }

  function close() {
    if (panel && panel.close)
      panel.close()
  }

  function closeForPopoutSwitch() {
    if (panel && panel.closeForPopoutSwitch)
      panel.closeForPopoutSwitch()
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: String(root.panelUrl) !== ""
    source: root.panelUrl
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
    onStatusChanged: {
      if (status === Loader.Error)
        console.warn(root.moduleName + " panel failed to load")
    }
  }
}
