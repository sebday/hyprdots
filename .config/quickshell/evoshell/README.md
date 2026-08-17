# Evo player

Local music library and player for evoshell. The UI is a dashboard plugin (`evo.player`); playback and library work live in the `evo-player` CLI, which drives a headless **mpv** instance over a Unix socket.

This is separate from **`evo.media`**, the bar tray popup that shows whatever app currently owns MPRIS (Spotify, browser, etc.). Tray media icon click toggles the **evo.player** dashboard via `evo-bar-player`, not MPRIS.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  evoshell (Quickshell)                                          │
│  shell.qml → Loader (keepLoaded) → plugins/player/              │
│    Player.qml          FloatingWindow, open/close/toggle, focus   │
│    PlayerModule.qml    UI, timers, optimistic transport state     │
│         │                                                       │
│         │  Process: bash ~/.local/bin/evo-player <cmd> [--json] │
│         ▼                                                       │
└─────────┼───────────────────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────────────────┐
│  evo-player (+ evo-player-lib.sh)                               │
│    library index · playlists · likes · art · waveforms · jobs     │
│         │                                                       │
│         │  mpv IPC (JSON lines on Unix socket)                  │
│         ▼                                                       │
│  mpv --no-video --idle=yes  ($XDG_RUNTIME_DIR/evo-player.sock)   │
│    optional MPRIS: /usr/share/mpv-mpris/mpris.so                  │
└─────────────────────────────────────────────────────────────────┘
```

**Control flow:** QML never talks to mpv directly. Every action is a subprocess call to `evo-player`. Queries return one JSON blob on stdout; long-running library tasks stream stderr to a job log while holding an exclusive lock.

**Lifecycle:** Opening the dashboard calls `evo-player open` (restore saved track metadata), starts status polling (500 ms), and periodic `save` (10 s). Closing calls `evo-player close`, which persists position and quits mpv.

## Plugin surface (`plugins/player/`)

| File | Role |
|------|------|
| `Player.qml` | Dashboard shell: `FloatingWindow` titled `evo.player`, screen selection (`HDMI-A-1` default), `open` / `close` / `toggle`, focus on activate |
| `PlayerModule.qml` | Full UI and state machine: genres, browse, playlists, now playing, transport, art picker, library jobs |
| `qmldir` | QML module `player` |

Registered in `shell.qml` as `evo.player` with `kinds: ["dashboard"]` and `keepLoaded: true`, so the loader stays warm and IPC toggle is instant.

### UI screens

`playerScreen` drives a stacked layout:

| Screen | Purpose |
|--------|---------|
| `nowPlaying` | Art, waveform scrubber, transport, volume, metadata chips |
| `browse` | Genre roots and folder browser (`evo-player browse`) |
| `playlistLibrary` | Starred and system playlists |
| `playlists` | Track list for the selected playlist |

The sidebar can show genre tabs, starred playlist tabs, and a library tools menu (build, sync, import, art maintenance).

### QML ↔ CLI bridge

`PlayerModule` keeps several `Process` runners so queries and commands do not block each other:

| Runner | Typical use |
|--------|-------------|
| `queryProc` | Read-only JSON: `genres`, `browse`, `stats`, `playlist`, `job status` |
| `statusQueryProc` | `status --json` on the poll timer |
| `cmdProc` / `playerQueryProc` | Playback mutations: `toggle`, `open`, `save` |
| `loadProc` | `load` / `load --folder` (serialized with a pending queue) |
| `queuePlayProc` | `queue play` for playlist jumps |
| `jobProc` | Exclusive library jobs (`build`, `import`, `soundcloud`, …) |

**Optimistic UI:** Transport, seek, and volume changes update `player` immediately, then debounce CLI calls (~120 ms) and reconcile on the next `status` poll (~1.5 s settle). This keeps the waveform and buttons responsive while mpv catches up.

## CLI backend (`~/.local/bin/evo-player`)

`evo-player` sources `evo-player-lib.sh` for paths, caching, and shared helpers. Run `evo-player` with no args for the full command list.

### Playback

| Command | Behaviour |
|---------|-----------|
| `start` | Launch mpv if not running |
| `load <path> [--folder]` | Replace playlist; `--folder` queues siblings in the same directory |
| `queue play <start> <paths…>` | Build mpv playlist rotated to `start` |
| `toggle` / `next` / `prev` | Transport; falls back to `current.m3u` when mpv playlist has one track |
| `seek <sec>` / `volume set <0-100>` / `shuffle` | mpv property control |
| `status [--json]` | Live state from mpv + ffprobe metadata, art path, waveform path |
| `open` / `restore` / `resume` / `close` / `save` | Session persistence via `player.json` |

mpv runs headless with `--input-ipc-server`. The socket defaults to `$XDG_RUNTIME_DIR/evo-player.sock` (legacy: `evo-music.sock`).

### Library

Music lives under **`MUSIC_ROOT`** (default `/mnt/external/music`). Top-level folders are **genres**; `incoming/` is skipped for browsing and used as a beet import staging area.

| Command | Behaviour |
|---------|-----------|
| `genres` / `tracks <genre>` | List genres or tracks (JSON uses per-genre tag caches) |
| `browse [path]` | Directory browser rooted at `MUSIC_ROOT` |
| `playlist` / `playlist <name>` | List or load `.m3u` playlists |
| `favorite toggle <path>` | Like/unlike; rebuilds genre and `all` playlists |
| `retag <path> <genre>` | Move file + update beets entry |
| `sync` + `import` + `soundcloud` | SoundCloud likes via yt-dlp → `incoming/` → `beet import` |
| `build all\|quick` | Rebuild playlists, refresh tag caches, warm art (and waveforms on `all`) |
| `cache` / `art` / `mixes migrate` | Tag caches, cover art search/embed, legacy folder migration |

Liked tracks are stored in **`likes.json`**; playlists are generated `.m3u` files under the cache `playlists/` directory, not hand-edited lists.

### Background jobs

Heavy work (`build`, `import`, `soundcloud`, `art embed`) runs under `run_exclusive_job` with a flock on `.job.lock` and status in `job.json`. Exit code `2` means another job is already running — the UI surfaces this via `job status --json` and a 2 s poll while the dashboard is open.

## Storage layout

Paths come from `evo-player-lib.sh` (override with env vars like `EVO_MUSIC_ROOT`, `EVO_PLAYER_SOCKET`).

| Path | Contents |
|------|----------|
| `MUSIC_ROOT/<genre>/` | Audio files (mp3, flac, ogg, m4a, opus, wav) |
| `MUSIC_ROOT/incoming/` | Downloads before beet import |
| `MUSIC_STATE/` (default `MUSIC_ROOT/.cache`) | Runtime cache and index |
| `…/player.json` | Last path, genre, playlist name, position |
| `…/likes.json` | Favourites map |
| `…/playlists/*.m3u` | Generated playlists (`all`, per-genre, `current`) |
| `…/tracks/<genre>.tags.json` | Cached track metadata for fast browse |
| `…/art/` | Cover art (content-addressed + per-folder aliases) |
| `…/waveforms/` | Precomputed waveform JSON for the scrubber |
| `~/.config/evoshell/music.toml` | Optional: SoundCloud sync source, `skip` dirs |

Legacy state under `~/.local/state/evoshell/music/` is migrated into `MUSIC_STATE` on first use.

## Shell integration

| Entry point | Action |
|-------------|--------|
| `evo-ipc shell toggle evo.player` | Show/hide dashboard (generic plugin IPC) |
| `evo-ipc shell summon evo.player` / `hide` | Open or close without toggle |
| `evo-bar-player toggle` | Same as toggle; also pins window via Hypr rules |
| `evo-bar-hypr restore-dashboards` | Open shopify + player on workspace 10 at session start |
| Bar **media** tray icon | `evo-bar-player toggle` (`MediaWidget.qml`) |

`shell.qml` calls `openDashboardOnly("evo.player")` during startup (with shopify) once both dashboard loaders are ready. Hyprland matches window title `evo.player` for tiling and workspace placement.

## Distinction from other media pieces

| Piece | Role |
|-------|------|
| **`evo.player`** + `evo-player` | Owned library on disk, mpv backend, full manager UI |
| **`evo.media`** + `MediaModule` | MPRIS read-only popup for the active desktop player |
| **`evo-film`** + `evo.library` | Film/TV index and playback (not music) |
| **`evo.audio`** | System volume service (tray dial) |

Do not add an `evo-media` script — that name collides with the MPRIS popup plugin.

## Handy commands

```bash
evo-player status --json
evo-player build quick
evo-player browse drum\&bass --json
evo-ipc shell toggle evo.player
evo-bar-player toggle
journalctl -t evoshell -f
```

## Where to change things

| Goal | Start here |
|------|------------|
| Now playing layout, browse UI, playlists | `plugins/player/PlayerModule.qml` |
| Window open/close, monitor targeting | `plugins/player/Player.qml` |
| Playback, library logic, caching | `~/.local/bin/evo-player`, `evo-player-lib.sh` |
| Dashboard IPC, startup open | `shell.qml` |
| Tray icon → player window | `plugins/bar/widgets/MediaWidget.qml` |
| Hypr workspace / pin rules | `~/.config/hypr/` (`evo-bar-hypr`, `windows.lua`) |

Broader evoshell architecture, naming conventions, and plugin model: `AGENTS.md` and `skills/evoshell/SKILL.md`.
