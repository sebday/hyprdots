import QtQuick
import qs.commons
import qs.ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "evo.cloudflare"

  // Own the service here. A replacement bar (evo.monitors) only exposes a
  // scoped shell for *its* plugin, so bar.shell.serviceFor("evo.cloudflare")
  // is always null on this desktop.
  readonly property var cf: serviceLoader.item
  readonly property bool loggedIn: cf && cf.loggedIn
  readonly property bool warningState: cf && cf.warning
  readonly property bool busy: cf && cf.busy


  function injectService() {
    var svc = serviceLoader.item
    if (!svc) return
    if ("shell" in svc && root.bar && root.bar.shell) svc.shell = root.bar.shell
    if ("settingsOverride" in svc) svc.settingsOverride = root.settings
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (cf && typeof cf.refresh === "function") {
      cf.refresh()
      if (!cf.analytics.loaded && typeof cf.refreshAnalytics === "function")
        cf.refreshAnalytics()
    }
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property bool iconError: loggedIn && cf && (
    cf.failedDeploys > 0
    || (cf.analytics && cf.analytics.workersOverErrorRate > 0)
    || (cf.lastError !== "" && cf.lastError.indexOf("pass insert") < 0)
  )
  readonly property bool iconBusy: false
  readonly property bool iconMuted: !loggedIn
  readonly property string tooltip: {
    if (!cf) return "Cloudflare"
    void cf.accountName
    void cf.lastError
    if (cf.accountName !== "") return cf.accountName
    if (cf.lastError !== "") return cf.lastError
    return cf.loggedIn ? "Cloudflare" : "Cloudflare — not logged in"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  onBarChanged: {
    injectService()
    injectPanel()
  }
  onSettingsChanged: {
    injectService()
    injectPanel()
  }

  Loader {
    id: serviceLoader
    active: true
    source: Qt.resolvedUrl("Service.qml")
    visible: false
    onLoaded: {
      root.injectService()
      Qt.callLater(root.injectService)
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰊠"
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError
    tooltipText: Model.plain(root.tooltip)

    onPressed: function() {
      if (!root.bar) return
      root.togglePanel()
    }
  }
}
