import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "../../Commons"

Item {
    id: root

    property var shell: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME")
    readonly property string statePath: home + "/.local/state/evoshell/wallpaper"
    readonly property string themeNamePath: home + "/.themes/current/.theme-name"

    readonly property string defaultWallpaperCommand: [
        "dir=" + Util.shellQuote(home + "/.themes/current/wallpapers"),
        "find \"$dir\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null | sort | head -n1"
    ].join("\n")

    property bool lockRequested: false
    property bool authenticating: false
    property string enteredPassword: ""
    property string pendingPassword: ""
    property string failureMessage: ""
    property int failedAttempts: 0
    property string backgroundPath: ""

    readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure

    function recoverOrphanLock() {
        if (sessionLock.secure && !lockRequested) {
            lockRequested = true
            refreshBackground()
        }
    }

    function refreshBackground() {
        if (!readStateProc.running) readStateProc.running = true
    }

    function beginLock() {
        enteredPassword = ""
        pendingPassword = ""
        failureMessage = ""
        failedAttempts = 0
        authenticating = false
        lockRequested = true
        refreshBackground()
        sessionLock.locked = true
        return true
    }

    function finishUnlock() {
        lockRequested = false
        enteredPassword = ""
        pendingPassword = ""
        failureMessage = ""
        authenticating = false
        sessionLock.locked = false
        if (!wakeProc.running) wakeProc.running = true
    }

    function submitPassword(value) {
        var password = String(value || "")
        if (!lockRequested || authenticating || password.length === 0) return
        pendingPassword = password
        failureMessage = ""
        authenticating = true
        if (!passwordPam.start()) handlePasswordFailure()
        else Qt.callLater(respondToPasswordPrompt)
    }

    function respondToPasswordPrompt() {
        if (!authenticating || !passwordPam.active || !passwordPam.responseRequired) return
        passwordPam.respond(pendingPassword)
    }

    function handlePasswordFailure() {
        authenticating = false
        enteredPassword = ""
        pendingPassword = ""
        failedAttempts += 1
        failureMessage = "Authentication failed (" + failedAttempts + ")"
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        onLockStateChanged: {
            if (!locked && root.lockRequested) root.finishUnlock()
        }

        WlSessionLockSurface {
            color: Theme.background

            Image {
                anchors.fill: parent
                source: Util.fileUrl(root.backgroundPath)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.backgroundPath !== ""
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.background
                opacity: Theme.opacitySecondary
            }

            Column {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: "Locked"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize9xl
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.failureMessage
                    color: Theme.urgent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    visible: root.failureMessage !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 280
                    height: 36
                    color: Theme.background
                    border.color: Theme.accent
                    radius: Theme.radiusL

                    TextInput {
                        id: passwordField
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeL
                        passwordCharacter: "•"
                        echoMode: TextInput.Password
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        text: root.enteredPassword
                        onTextEdited: root.enteredPassword = text
                        Keys.onReturnPressed: root.submitPassword(text)
                        Keys.onEnterPressed: root.submitPassword(text)
                    }
                }
            }

            Component.onCompleted: passwordField.forceActiveFocus()
        }
    }

    PamContext {
        id: passwordPam
        config: "login"
        user: root.userName
        onResponseRequiredChanged: root.respondToPasswordPrompt()
        onPamMessage: root.respondToPasswordPrompt()
        onCompleted: function(result) {
            root.authenticating = false
            root.pendingPassword = ""
            if (!root.lockRequested) return
            if (result === PamResult.Success) root.finishUnlock()
            else root.handlePasswordFailure()
        }
        onError: function(error) { root.handlePasswordFailure() }
    }

    Process {
        id: readStateProc
        command: ["bash", "-c", "if [[ -f " + Util.shellQuote(root.statePath) + " ]]; then cat " + Util.shellQuote(root.statePath) + "; else " + root.defaultWallpaperCommand + "; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.backgroundPath = String(text || "").trim()
        }
    }

    Process {
        id: wakeProc
        command: ["bash", "-lc", "hyprctl dispatch dpms on 2>/dev/null || true"]
    }

    IpcHandler {
        target: "evo.lock"

        function lock(): string {
            if (!root.locked && !root.beginLock()) return "failed"
            return "ok"
        }

        function isLocked(): string {
            return root.locked ? "true" : "false"
        }

        function status(): string {
            return JSON.stringify({
                locked: root.locked,
                authenticating: root.authenticating,
                failedAttempts: root.failedAttempts
            })
        }
    }

    Component.onCompleted: {
        refreshBackground()
        Qt.callLater(recoverOrphanLock)
    }

    Connections {
        target: sessionLock
        function onSecureChanged() { root.recoverOrphanLock() }
    }
}
