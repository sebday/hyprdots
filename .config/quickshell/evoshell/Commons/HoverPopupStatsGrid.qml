import QtQuick
import QtQuick.Layouts

GridLayout {
    id: root

    property int columns: 2
    property int columnSpacing: Theme.hoverPopupStatColumnSpacing
    property int rowSpacing: Theme.hoverPopupStatRowSpacing
    property int valueFontSize: Theme.hoverPopupStatValueFont
    property int labelFontSize: Theme.hoverPopupStatLabelFont

    default property alias stats: root.data

    Layout.fillWidth: true
}
