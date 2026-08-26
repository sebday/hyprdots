import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string text: ""
    property string icon: ""
    property string iconUrl: ""
    property int fontSize: Theme.fontSizeXs
    property int iconSize: 0
    property color textColor: Theme.foreground
    property color fill: Theme.fillNeutralSubtle
    property real textOpacity: 0.72
    property bool alignCenter: false
    property bool fieldsetLegend: true
    property color fieldsetFill: Theme.background
    property bool clickable: false

    signal clicked()

    visible: root.text !== "" || root.icon !== "" || root.iconUrl !== ""
    width: implicitWidth
    height: implicitHeight
    implicitWidth: root.alignCenter && parent && parent.width > 0
        ? parent.width
        : pill.implicitWidth
    implicitHeight: pill.implicitHeight

    readonly property int padH: root.fieldsetLegend ? 5 : 6
    readonly property int padTop: root.fieldsetLegend ? 0 : 3
    readonly property int padBottom: root.fieldsetLegend ? 0 : 3
    readonly property int resolvedIconSize: root.iconSize > 0 ? root.iconSize : root.fontSize
    readonly property bool hasIcon: root.icon !== "" || root.iconUrl !== ""

    Rectangle {
        id: pill
        anchors.left: root.alignCenter ? undefined : parent.left
        anchors.horizontalCenter: root.alignCenter ? parent.horizontalCenter : undefined
        radius: root.fieldsetLegend ? 0 : height / 2
        color: root.fieldsetLegend ? root.fieldsetFill : root.fill
        implicitWidth: labelRow.implicitWidth + root.padH * 2
        implicitHeight: labelRow.implicitHeight + root.padTop + root.padBottom
        width: implicitWidth
        height: implicitHeight

        RowLayout {
            id: labelRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: root.padTop
            anchors.leftMargin: root.padH
            anchors.rightMargin: root.padH
            spacing: root.hasIcon && root.text !== "" ? 5 : 0

            Item {
                visible: root.icon !== "" || root.iconUrl !== ""
                Layout.preferredWidth: root.resolvedIconSize
                Layout.preferredHeight: root.resolvedIconSize

                Image {
                    id: legendIconImage
                    anchors.fill: parent
                    source: root.iconUrl
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    visible: root.iconUrl !== "" && status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.icon !== "" && (root.iconUrl === "" || legendIconImage.status !== Image.Ready)
                    text: root.icon
                    color: root.textColor
                    opacity: root.textOpacity
                    font.family: Theme.fontFamily
                    font.pixelSize: root.resolvedIconSize
                    font.bold: Theme.fontBold
                }
            }

            Text {
                id: labelText
                visible: root.text !== ""
                text: root.text
                color: root.textColor
                opacity: root.textOpacity
                font.family: Theme.fontFamily
                font.pixelSize: root.fontSize
                font.bold: Theme.fontBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
