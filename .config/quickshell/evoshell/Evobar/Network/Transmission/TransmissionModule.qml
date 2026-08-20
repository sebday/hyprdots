import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../Commons"
import "."

Item {
    id: root

    property var host: null
    property var shell: null
    property int hoverPopupWidth: 0

    readonly property bool active: host && host.opened === true
    readonly property var barSource: host && host.shell ? host.shell.popupAnchorItem : null
    readonly property int hintFont: Theme.fontSizeL
    readonly property int titleFont: Theme.fontSize2xl

    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: root.hoverPopupWidth
        spacing: Theme.hoverPopupSectionSpacing

        HoverPopupHeader {
            Layout.fillWidth: true
            iconFallback: "󰇚"
            titleFont: root.titleFont
            detailFont: root.hintFont
            value: transmissionPanel.loading
                ? "Transmission\nLoading…"
                : (transmissionPanel.errorText
                    ? "Transmission\n" + transmissionPanel.errorText
                    : "Transmission\n" + transmissionPanel.formatRate(transmissionPanel.downloadRate) + " ↓ · "
                        + transmissionPanel.formatRate(transmissionPanel.uploadRate) + " ↑")
        }

        TransmissionPanel {
            id: transmissionPanel
            Layout.fillWidth: true
            active: root.active
            shell: root.shell
            barSource: root.barSource
        }
    }
}
