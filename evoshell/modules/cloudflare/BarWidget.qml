import QtQuick
import qs.ui
import "Model.js" as Model

PanelHost {
  id: root
  moduleName: "evo.cloudflare"
  panelUrl: Qt.resolvedUrl("Panel.qml")
  anchor: button

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

  onBeforeRefresh: {
    if (cf && typeof cf.refresh === "function") {
      cf.refresh()
      if (!cf.analytics.loaded && typeof cf.refreshAnalytics === "function")
        cf.refreshAnalytics()
    }
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

  onBarChanged: injectService()
  onSettingsChanged: injectService()

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
