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
| `Theme.qml` tokens | full restart (`evo-system-restart`) |
| `shell.qml` plugin table, new widget type | full restart |
| `evoshell.lua` layer rules | Hypr reload; often needs shell restart too |

## Design tokens (`Commons/Theme.qml`)

All visual constants go through `Theme.*` — no hardcoded colours, font sizes, spacing, opacity, or radius in QML.

Add a new token when a value appears 3+ times or has clear semantic meaning. Layout-derived ratios (`iconSize * 0.72`) are OK; never derive font sizes. No surface-specific aliases (`panelTitle`, `hoverBody`).

### Sources

| Source | Keys | Reload |
|--------|------|--------|
| `theme.json` | `foreground`, `background`, `accent`, `mantle`, `urgent`, `iconTheme`, `fontFamily`, `fontPixelSize` | live |
| `hypr-looks.json` | `activeOpacity`, `inactiveOpacity`, `roundingOn`, `gapsOn` | live |
| `ui.json` | `fieldsetRounding` | live |
| `Theme.qml` | spacing, opacity, radius, layout, derived colours | restart |

Optional `theme.json` overrides: `inactiveBorder`, `surfaceOpacity`, `surfaceOpacityInactive`, `panelMantleLift`.

### Opacity scale

| Token | Value | Use |
|-------|-------|-----|
| `opacityDisabled` | 0.45 | disabled controls |
| `opacityMuted` | 0.55 | de-emphasised labels |
| `opacityHover` | 0.65 | hover states |
| `opacitySecondary` | 0.72 | secondary text |
| `opacityEmphasis` | 0.9 | near-primary text/icons |

### Foreground alpha colours

| Token | Alpha | Use |
|-------|-------|-----|
| `foregroundGhost` | 0.05 | idle row wash |
| `foregroundWash` | 0.06 | chip/list backgrounds |
| `foregroundFaint` | 0.08 | hover row wash |
| `foregroundHoverWash` | 0.1 | chip hover |
| `foregroundRaised` | 0.12 | pressed rows |
| `foregroundDivider` | 0.14 | chip/row borders |
| `foregroundSubtle` | 0.16 | toggle track off |
| `foregroundTrack` | 0.18 | slider track |
| `foregroundPickerBorder` | 0.22 | combobox border |
| `foregroundBorder` | 0.32 | fieldset borders |

Use `Theme.withOpacity(Theme.foreground, n)` for one-off alphas (canvas, charts).

### Spacing scale

| Token | Value | Matches |
|-------|-------|---------|
| `spacing2` | 2 | tight stacks |
| `spacingS` | 6 | form rows (`sparklineGap`) |
| `spacingM` | 8 | row gaps (`barGap`) |
| `spacingL` | 10 | sections (`hoverPopupSectionSpacing`) |

Surface padding: `panelContentPad` (10), `panelDockPad` (12), `hoverPopupContentPad` (16), `hoverPopupMargin` / `overlayMargin` (16).

### Radius scale

| Token | Value | Use |
|-------|-------|-----|
| `radiusS` | 2 | tracks, sparkline cells |
| `radiusM` | 3 | list item highlight |
| `radiusL` | 4 | inputs (`fieldsetCornerRadius`) |
| `radiusToggleTrack` | 12 | toggle pill |
| `radiusToggleThumb` | 9 | toggle knob |
| `panelCornerRadius` | 0/4 | panels (from `roundingOn`) |

### Layout tokens

| Group | Tokens |
|-------|--------|
| Overlays | `overlayWidthDefault` (440), `overlayMargin` (16), `screenEdgeInset` (20), `hoverPopupWidthWide` (580) |
| Bar | `barHeight`, `barPaddingX`, `barGap`, `barSectionGap`, `barHoverTopPad` |
| Panel | `panelContentPad`, `panelDockPad`, `panelSectionSpacing`, `panelLabelPadH` |
| Sparkline / notifications | `sparkline*`, `notification*` — see `Theme.qml` |

### Typography

- `fontPixelSize` in `theme.json` is the base (default 13); `fontBold` is fixed `true`
- Use `Theme.fontSize*` only — see `Theme.qml` for the full scale (`fontSizeXxs` … `fontSizeHeroLg`)

## Testing

```bash
evo-ipc shell ping
evo-ipc shell reloadConfig    # after shell.json edits
evo-system-restart            # after Theme.qml edits
.local/bin/evo-bar-weather    # bar script → valid JSON
journalctl -t evoshell -f
```

Visual/QML changes need manual check: bar popups, panel, player dashboard, overlays, notifications.
