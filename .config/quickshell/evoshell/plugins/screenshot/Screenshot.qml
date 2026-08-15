import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "."

Item {
    id: root

    property var shell: null
    property bool opened: false
    property string pendingPath: ""

    readonly property string defaultPath: "/tmp/hyprshot.png"

    function parsePath(payloadJson) {
        var path = root.defaultPath
        var raw = String(payloadJson || "").trim()
        if (!raw)
            return path
        try {
            var payload = JSON.parse(raw)
            if (payload && payload.path)
                path = String(payload.path)
        } catch (e) {
        }
        return path
    }

    function notify(title, body) {
        var notif = shell ? shell.serviceFor("evo.notifications") : null
        if (notif && typeof notif.showBrief === "function")
            notif.showBrief(title, body)
    }

    function open(payloadJson) {
        var path = parsePath(payloadJson)
        if (!path) {
            notify("screenshot", "no capture — press Print first")
            return
        }
        pendingPath = path
        if (existsProc.running)
            existsProc.running = false
        existsProc.running = true
    }

    function close() {
        opened = false
        content.reset()
    }

    function dismiss() {
        if (shell)
            shell.hide("evo.screenshot")
        else
            close()
    }

    Process {
        id: existsProc
        command: ["bash", "-c", "if test -f " + Util.shellQuote(root.pendingPath) + "; then echo ok; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (String(text).trim() === "ok") {
                    content.loadImage(root.pendingPath)
                    root.opened = true
                    Qt.callLater(function() {
                        content.onActivated()
                    })
                } else {
                    root.notify("screenshot", "no capture — press Print first")
                }
            }
        }
    }

    PanelWindow {
        id: editorWindow
        screen: content.hostScreen
        visible: root.opened
        color: Theme.overlaySurface
        implicitWidth: content.windowWidth
        implicitHeight: content.windowHeight
        anchors.top: true
        anchors.left: true
        margins.top: content.windowY
        margins.left: content.windowX
        WlrLayershell.namespace: "evo-screenshot"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore

        AppScreenshot {
            id: content
            anchors.fill: parent
            host: root
        }
    }
}