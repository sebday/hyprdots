# Agent guide

House rules for evoshell. Architecture, plugins, and IPC: `skills/evoshell/SKILL.md`.

## Paths

```bash
EVOSHELL_BIN="${EVOSHELL_BIN:-$HOME/.local/bin}"
EVOSHELL_CONFIG="${EVOSHELL_CONFIG:-$HOME/.config/quickshell/evoshell}"
EVOSHELL_STATE="${EVOSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/evoshell}"
EVOSHELL_CACHE="${EVOSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/evoshell}"
EVOSHELL_DATA="${EVOSHELL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/evoshell}"
```

## Scripts

- `evo-*` only; 2-space indent, `#!/bin/bash`, `[[ ]]` for strings, `(( ))` for numbers
- `evo-bar-*` — bar poll wrappers (one JSON line stdout)
- `evo-dash-*` — dashboard / Hypr window control
- `evo-theme-*` — theme generation and apply
- Plugin ids: `evo.<feature>`; layer namespaces: `evo-<kebab>`
- Use `evo-ipc`, `evo-bar-common`, `evo-theme-lib` — not raw equivalents
- Secrets: `$EVOSHELL_DATA/secrets.env` (never commit)

## QML

- 4-space indent; new bar widgets → `widgets/qmldir` + `BarWidgetCatalog.qml`
- `BarWidgetCatalog` root must be `Item`; bar scripts print one JSON line
- Panel module ids: `calc`, `clipboard`, `settings` (legacy `"tools"` → `calc` only)

## Config reload

| Change | Action |
|--------|--------|
| `shell.json` | `evo-ipc shell reloadConfig` |
| `theme.json` | live — `Theme.qml` watches the file |
| `shell.qml` plugin table, new widget type | full restart (`evo-system-restart`) |
| `evoshell.lua` layer rules | Hypr reload; often needs shell restart too |

## Design tokens

All visual constants live in `Commons/Theme.qml`. Reference `Theme.*` in QML — no hardcoded colours, font sizes, or repeated layout numbers.

### Sources

| Source | Keys | Reload |
|--------|------|--------|
| `theme.json` | `foreground`, `background`, `accent`, `mantle`, `urgent`, `iconTheme`, `fontFamily`, `fontPixelSize` | live |
| `hypr-looks.json` | `activeOpacity`, `inactiveOpacity`, `roundingOn`, `gapsOn` | live |
| `Theme.qml` | layout, derived colours, font scale | code change + restart |

Optional `theme.json` overrides: `inactiveBorder`, `surfaceOpacity`, `surfaceOpacityInactive`, `panelMantleLift`.

### Colours (derived in Theme.qml)

- **Surfaces** — `overlaySurface`, `overlaySurfaceInactive`, `panelBackground`, `panelMantle`
- **Charts** — `heatmapColors`, `chartPalette`
- **Helpers** — `withOpacity()`, `mixColors()`

### Layout tokens (already in Theme.qml)

| Group | Tokens |
|-------|--------|
| Bar | `barHeight`, `barPaddingX`, `barGap`, `barSectionGap`, `barHoverTopPad` |
| Hover popup | `hoverPopupWidthStandard` (440), `hoverPopupWidthWide` (580), `hoverPopupMargin`, `hoverPopupContentPad`, `hoverPopupSectionSpacing`, `hoverPopupBorderWidth` |
| Panel | `panelContentPad`, `panelSectionSpacing`, `panelCornerRadius`, `fieldsetCornerRadius` |
| Sparkline | `sparklineHeight`, `sparklineGap`, `sparklineChartMargin`, `sparklineExpanded*` |
| Notifications | `notificationWidth`, `notificationPadding`, `notificationArtSize`, `notificationMediaPad`, `notificationStackSlot` |
| Hypr sync | `gapsOut`, `surfaceOpacity`, `surfaceOpacityInactive` |

### Typography

- `fontPixelSize` in `theme.json` is the base (default 13); `fontBold` is fixed `true`
- Use `Theme.fontSize*` scale only — no hardcoded `font.pixelSize` or surface-specific aliases (`panelTitle`, etc.)
- Steps: `fontSizeXxs` … `fontSize9xl`, `fontSizeHero`, `fontSizeHeroLg` — see `Theme.qml` for formulas
- Layout-derived icon sizing (e.g. `headerIconSize * 0.72`) is fine; text size must still use the scale

### Not yet tokenized (candidates)

These repeat across Commons/plugins — good next pulls into `Theme.qml`:

- **Opacity scale** — `0.45` disabled, `0.55` muted, `0.65` hover, `0.72` secondary text, `0.9` emphasis (100+ hardcoded uses)
- **Spacing scale** — `2`, `6`, `8`, `10` in `FramedPanel`, `HoverPopupHeader`, `ToggleRow`, settings rows
- **Border alpha** — `0.32` frame borders, `0.16`/`0.18` track fills (`FramedPanel`, `ToggleRow`, `SliderSetting`)
- **Overlay defaults** — `AttachedOverlay`/`BarHoverPopup` use `contentWidth: 420` and `contentMargin: 12`; popups elsewhere use `hoverPopupWidthStandard` (440) and `hoverPopupMargin` (16) — unify
- **FramedPanel chrome** — `labelPadH` (6), `labelGap` (8), `contentPad` (10) should alias `panelContentPad`

## Testing

```bash
evo-ipc shell ping
evo-ipc shell reloadConfig    # after shell.json edits
.local/bin/evo-bar-weather    # bar script → valid JSON
journalctl -t evoshell -f
```

Visual/QML changes need manual check in the running desktop.
