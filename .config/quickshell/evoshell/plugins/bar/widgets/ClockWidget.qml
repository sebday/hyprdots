import QtQuick
import "../../../Commons"

Item {
    id: root

    property var bar: null
    property var barPanel: null
    property var shell: null
    property var settings: ({})
    readonly property string hoverPopupId: settings.onHover ? String(settings.onHover) : "evo.calendar"

    implicitWidth: label.implicitWidth + Theme.barSectionGap * 2
    implicitHeight: Theme.barHeight

    function strftimeToQt(fmt) {
        var f = String(fmt || "")
        f = f.replace(/%Y/g, "yyyy")
        f = f.replace(/%y/g, "yy")
        f = f.replace(/%m/g, "MM")
        f = f.replace(/%d/g, "dd")
        f = f.replace(/%H/g, "HH")
        f = f.replace(/%I/g, "hh")
        f = f.replace(/%M/g, "mm")
        f = f.replace(/%S/g, "ss")
        f = f.replace(/%p/g, "AP")
        f = f.replace(/%A/g, "dddd")
        f = f.replace(/%a/g, "ddd")
        f = f.replace(/%B/g, "MMMM")
        f = f.replace(/%b/g, "MMM")
        return f
    }

    function qtFormat() {
        var raw = settings.format ? String(settings.format) : "%a %d %H:%M"
        return strftimeToQt(raw)
    }

    function updateText() {
        label.text = Qt.formatDateTime(new Date(), qtFormat())
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.barSectionGap
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.barFontPixelSize
        font.bold: Theme.fontBold
    }

    HoverHandler {
        enabled: root.hoverPopupId !== ""
        onHoveredChanged: {
            if (!root.shell || !root.hoverPopupId) return
            if (hovered)
                root.shell.hoverEnter(root.hoverPopupId, root, root.barPanel)
            else
                root.shell.hoverLeave(root.hoverPopupId)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateText()
    }

    Component.onCompleted: updateText()
}
