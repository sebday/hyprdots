import QtQuick
import QtQuick.Controls
import qs.commons

// Styled wrapper around Qt Quick Controls ToolTip. Drop-in: declare inside
// the hovered item and bind `visible` to the hover state, e.g.
//   PanelToolTip {
//     visible: mouse.containsMouse
//     text: "Forget network"
//   }
//
// Defaults pull from [tooltip] in shell.toml via Theme.tooltip.*. Override
// the panel* properties per-instance only when you need a tooltip that
// intentionally diverges from the theme.
//
// Property names are prefixed `panel*` to avoid clashing with ToolTip's
// built-in `background`/`font` properties.
ToolTip {
  id: root

  property color panelForeground: Theme.tooltip.text
  property color panelBackground: Theme.tooltip.background
  property color panelBorder: Theme.tooltip.border
  property string fontFamily: Theme.font.family
  property real fontSize: Theme.font.bodySmall

  readonly property var panelBorderSpec: Border.localOrSurfaceSpec("tooltip", "border", panelBorder, Theme.tooltip.border, Theme.normalBorderWidth)

  delay: 400
  padding: 0

  background: BorderSurface {
    color: root.panelBackground
    borderSpec: root.panelBorderSpec
    radius: Theme.cornerRadius
  }

  contentItem: Text {
    textFormat: Text.PlainText
    text: root.text
    color: root.panelForeground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    leftPadding: Border.left(root.panelBorderSpec) + Theme.spacing.controlPaddingX
    rightPadding: Border.right(root.panelBorderSpec) + Theme.spacing.controlPaddingX
    topPadding: Border.top(root.panelBorderSpec) + Theme.spacing.controlPaddingY
    bottomPadding: Border.bottom(root.panelBorderSpec) + Theme.spacing.controlPaddingY
  }
}
