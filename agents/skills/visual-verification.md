# Visual verification

Read this before finishing any change with a visual effect: bar layout, hover popups, dashboards, notifications, lock screen, themes, animations, or multi-monitor positioning.

Automated tests alone are not sufficient. Inspect the running UI for clipping, overlap, stale state, focus problems, and hover/pin regressions.

## Automated gate

Run the tests for the area you changed:

```bash
bash tests/test-plugin-manifest.sh
bash tests/test-evoplayer-art.sh
bash tests/test-static-contracts.sh
```

Confirm the shell IPC responds:

```bash
evo ipc shell ping
```

After manifest, `Theme.qml`, or loader changes:

```bash
evo system restart
evo ipc shell ping
```

Watch for load errors:

```bash
journalctl -t evoshell -n 50 --no-pager
```

## Screenshots

EvoShell ships `evo-screenshot` for capture and annotation.

Full stacked multi-monitor capture:

```bash
evo-screenshot stacked -o /tmp/evoshell-check.png
```

Annotate or capture a region first:

```bash
evo-screenshot edit /tmp/evoshell-check.png --capture region
```

Environment overrides:

- `EVO_SCREENSHOT_TOP` — top-row monitor (auto-detected from focused monitor when unset)
- `EVO_SCREENSHOT_BOTTOM` — bottom-row monitors (remaining monitors when unset)

Capture reference and candidate states as separate images when changing layout, then compare both.

## Bar and hover popups

Verify on the configured bar output (`shell.json` → `bar.output`):

1. Widgets render with expected text, icons, or tray mode
2. Hover opens the correct popup (`onHover` plugin id)
3. Moving off the widget closes unpinned popups
4. Right-click pins when supported (`Util.pinHoverPanelFromBarIfActive`)
5. Pinned popups stay open until explicitly closed or unpinned
6. Click and right-click handlers run the configured commands

Exercise via IPC when useful:

```bash
evo ipc shell summon evo.panels.weather ""
evo ipc shell hide evo.panels.weather
evo ipc shell toggle evo.sys.settings ""
```

## Dashboards and overlays

1. `evo ipc shell toggle evo.panels.player ""` opens and closes the player dashboard
2. Dashboard appears on the expected monitor (`barConfig.output` fallback)
3. Focus lands inside the dashboard after open
4. Settings overlay (`evo.sys.settings`) centers and dismisses on escape/outside click

## Evoside, notifications, lock screen

Manual checks when touching those areas:

- Evoside calculator opens on Super+C; tasks focus opens on Super+N (`{"module":"calc","focus":"tasks"}`)
- Desktop toasts appear on the configured monitor (`shell.json` → `notifications.output`, `notifications.position`)
- Notification history hover popup works (`evo.panels.notifications`); unread count updates in the tray
- Lock screen engages and releases via `evo system lock` / unlock flow
- Idle timers from `shell.json` → `idle` still match expected behavior

## Multi-monitor

When changing bar output, dashboard placement, or notification position:

1. Confirm widgets appear on the intended monitor only
2. Hover popups anchor to the bar widget, not a stale monitor
3. Run `evo-screenshot stacked` to confirm full layout

## Interactive input

For keyboard-driven UI, prefer `wtype` when available:

```bash
wtype -k Right -k Return
```

Track PIDs for any UI launched only for verification and stop them afterward; avoid broad `pkill` unless you have confirmed the target process list.

## Completion criteria

A visual change is done when:

1. Focused automated tests pass
2. `evo ipc shell ping` succeeds after reload/restart
3. No new errors in `journalctl -t evoshell`
4. Screenshot or live inspection confirms the intended appearance and behavior
5. Hover, pin, focus, and monitor placement work on the affected surfaces
