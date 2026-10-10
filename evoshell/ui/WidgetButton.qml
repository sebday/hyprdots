import QtQuick
import qs.commons

Item {
  id: root

  property var bar: null
  property string text: ""
  // Drawn before `text`, sized to the glyph's ink so a wide icon does not
  // eat the space before the value. Empty for labels that are text only.
  property string leadingIcon: ""
  property string fontFamily: bar ? bar.fontFamily : Theme.font.family
  property real fontSize: Theme.font.body
  property color foreground: bar ? bar.barForeground : Theme.foreground
  property color activeColor: bar ? bar.urgent : Theme.urgent
  property bool active: false
  property real horizontalMargin: 8.5
  property real verticalPadding: 6
  property real fixedWidth: -1
  property real fixedHeight: -1
  property real textRotation: 0
  property bool keepSpace: false
  property bool dimmed: false
  property bool concealed: false
  property bool interactive: true
  property bool pressable: true
  property bool useActiveColor: true
  property bool maintainIndicatorReveal: false
  property bool labelVisible: true
  property bool hasVisualContent: text !== ""
  property var revealHost: bar
  property string tooltipText: ""
  property var registeredBar: null

  signal pressed(int button)
  signal wheelMoved(int delta)

  function triggerPress(button) {
    if (root.bar) root.bar.hideTooltip(root)
    root.pressed(button)
  }

  function hideOwnTooltip() {
    if (root.bar) root.bar.hideTooltip(root)
  }

  function syncClickRegistration() {
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)
    registeredBar = root.bar
    if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(root)
  }

  onBarChanged: syncClickRegistration()
  onVisibleChanged: if (!visible) hideOwnTooltip()
  onInteractiveChanged: if (!interactive) hideOwnTooltip()
  onConcealedChanged: if (concealed) hideOwnTooltip()
  Component.onCompleted: syncClickRegistration()
  Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Theme.bar.sizeHorizontal
  readonly property real scaledHorizontalMargin: Theme.spaceReal(horizontalMargin)
  readonly property real scaledVerticalPadding: Theme.spaceReal(verticalPadding)
  readonly property bool tooltipHovered: visible && interactive && !concealed && mouseArea.containsMouse
  readonly property color labelColor: active && useActiveColor ? activeColor : foreground
  readonly property bool showLeadingIcon: leadingIcon !== "" && !vertical
  // Fixed gap after the icon ink. A measured space comes back as zero width,
  // which pulls the value flush against the glyph.
  readonly property real iconGap: Theme.spacing.md
  readonly property real iconBoxWidth: Math.max(
    iconMetrics.width,
    iconMetrics.tightBoundingRect.x + iconMetrics.tightBoundingRect.width)
  readonly property real contentWidth: showLeadingIcon ? iconRow.implicitWidth : label.implicitWidth
  // Width of the painted label, for bar chrome that wants to line up with the
  // text rather than with the slot it sits in. Zero on icon-only buttons.
  readonly property real labelWidth: showLeadingIcon
    ? iconRow.implicitWidth
    : (label.visible ? label.implicitWidth : 0)

  visible: hasVisualContent || keepSpace
  opacity: !hasVisualContent || concealed ? 0 : (dimmed ? 0.45 : 1)
  implicitWidth: fixedWidth > 0 ? fixedWidth : (vertical ? barSize : Math.max(12, contentWidth + scaledHorizontalMargin * 2))
  implicitHeight: fixedHeight > 0 ? fixedHeight : (vertical ? Math.max(12, label.implicitHeight + scaledVerticalPadding * 2) : barSize)

  Behavior on opacity {
    NumberAnimation { duration: Theme.duration(140); easing.type: Easing.OutCubic }
  }

  TextMetrics {
    id: iconMetrics
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    text: root.leadingIcon
  }

  Row {
    id: iconRow
    visible: root.showLeadingIcon && root.labelVisible
    anchors.centerIn: parent
    spacing: 0

    Item {
      // Match the price line. A fallback glyph (the double-struck X) has a
      // taller line box, and letting that set the row height lifts the label.
      width: root.iconBoxWidth
      height: valueLabel.implicitHeight

      Text {
        id: iconGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.leadingIcon
        color: root.labelColor
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        renderType: Text.NativeRendering

        Behavior on color {
          enabled: !root.bar || root.bar.foregroundAnimationEnabled
          ColorAnimation { duration: Theme.duration(160) }
        }
      }
    }

    Item {
      width: root.iconGap
      height: 1
    }

    Text {
      id: valueLabel
      textFormat: Text.PlainText
      text: root.text
      color: root.labelColor
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      renderType: Text.NativeRendering

      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: Theme.duration(160) }
      }
    }
  }

  Text {
    id: label
    textFormat: Text.PlainText
    visible: root.labelVisible && !root.showLeadingIcon
    anchors.centerIn: parent
    text: root.text
    color: root.labelColor
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    renderType: Text.NativeRendering
    rotation: root.textRotation
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
      enabled: !root.bar || root.bar.foregroundAnimationEnabled
      ColorAnimation { duration: Theme.duration(160) }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    enabled: root.interactive
    hoverEnabled: true
    cursorShape: root.pressable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onEntered: {
      if (root.bar) {
        root.bar.showTooltip(root, root.tooltipText)
      }
      if (root.maintainIndicatorReveal && root.revealHost && root.revealHost.setIndicatorItemHovered)
        root.revealHost.setIndicatorItemHovered(true)
    }
    onExited: {
      if (root.bar) {
        root.bar.hideTooltip(root)
      }
      if (root.maintainIndicatorReveal && root.revealHost && root.revealHost.setIndicatorItemHovered)
        root.revealHost.setIndicatorItemHovered(false)
    }
    onClicked: function(mouse) { if (root.pressable) root.triggerPress(mouse.button) }
    onWheel: function(wheel) { root.wheelMoved(wheel.angleDelta.y) }
  }
}
