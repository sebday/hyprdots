---
name: nvim-editor-chrome
description: >-
  Documents custom Neovim tabs, status bar, and explorer layout in this LazyVim
  config. Use when modifying editor chrome, lualine/tabline, snacks explorer,
  buffer tabs, project sessions, or related highlights and icons.
---

# Neovim editor chrome

LazyVim config with a custom **editor chrome** layer: lualine renders only the status bar, buffer tabs live in a dedicated 3-row window, and snacks.nvim provides a persistent left-sidebar explorer aligned with the tab strip.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  status bar (lualine tabline — file info, mode, etc.)   │
├──────────────┬──────────────────────────────────────────┤
│              │  row 1: blank gap (editor_chrome)        │
│   explorer   ├──────────────────────────────────────────┤
│   sidebar    │  row 2: buffer tabs (editor_chrome)      │
│   (snacks)   ├──────────────────────────────────────────┤
│              │  row 3: blank gap (editor_chrome)        │
│              ├──────────────────────────────────────────┤
│              │  editor buffer                           │
└──────────────┴──────────────────────────────────────────┘
```

Neovim's built-in tabline and winbar are single-row UI elements and cannot host the blank gaps above and below tabs. Those gaps plus the tab row are rendered in a fixed-height split window managed by `editor-chrome`.

## Key files

| File | Role |
|------|------|
| `lua/config/editor-chrome.lua` | Tab strip window, mouse interaction, quit semantics, explorer alignment |
| `lua/plugins/lualine.lua` | Repurposes lualine for status-only; boots editor-chrome |
| `lua/plugins/finder.lua` | Snacks explorer sidebar layout and auto-open on startup |
| `lua/modular/highlights.lua` | Snacks picker highlight groups |
| `lua/theme-icons.lua` | Theme-synced mini.icons colours |
| `lua/config/options.lua` | Sets `laststatus = 0` globally |
| `lua/plugins/session.lua` | Limit persistence saves to ~ and ~/projects/* |
| `lua/config/finder-filter.lua` | Home whitelist + ~/projects gitignore for explorer and files picker |

## Status bar

**bufferline.nvim is disabled.** Tabs are not shown in bufferline or lualine's default tabline.

**lualine is repurposed:**

- `opts.sections` content is moved to `opts.tabline` (status bar at the top).
- `opts.sections`, `opts.inactive_sections`, `opts.winbar`, and `opts.inactive_winbar` are cleared.
- `laststatus = 0` — no per-window status line.
- `showtabline = 2` — tabline (used by lualine for the status bar) always visible.
- `editor_chrome` filetype is added to `disabled_filetypes` for statusline, winbar, and tabline.

**editor-chrome enforces:**

- `laststatus = 0`, `ruler = false`, `winbar = ""` on refresh.
- An `OptionSet` autocmd resets `laststatus` if anything tries to change it.
- `hook_lualine()` patches `lualine.refresh` to re-apply chrome styling and explorer gap after each lualine redraw.

## Tabs (editor-chrome)

A dedicated `editor_chrome` buffer/window sits above the editor (`split = "above"`, `HEIGHT = 3`, `winfixheight`).

**Layout (3 rows):**

1. Blank line — visual gap under the status bar.
2. Buffer tabs — one label per listed buffer (`filename`, `●` suffix when modified).
3. Blank line — visual gap above the editor.

**Tab styling:**

- Active tab: `Visual` highlight.
- Inactive tabs: `Comment` highlight.
- Extmarks on row 2 track click targets by display width.

**Tab strip visibility:**

- Hidden on full-screen UIs: dashboard, alpha, ministarter, lazy, mason (`hide_ft`).
- Explorer sidebars are **not** hidden — they coexist with the tab strip.

**Mouse (`mouse = "a"`):**

- **Left release** on a tab → switch to that buffer in the editor window.
- **Middle release** on a tab → close that buffer (uses `snacks.bufdelete` when available).
- Click on chrome but not on a tab → bounce focus back to the editor.
- Uses `<LeftRelease>` / `<MiddleRelease>` (not press events) because `wincol` is wrong on press.

**Quit / close semantics:**

Because chrome and explorer are extra windows, default `:q` would close the editor pane and break the layout. These are remapped to buffer-tab semantics:

| Input | Behaviour |
|-------|-----------|
| `:q`, `:quit` | `ChromeQuit` — close current buffer tab; `qa` on last buffer |
| `:wq`, `:x`, `:exit` | `ChromeWquit` — write then close tab |
| `ZZ` | Write and close tab |
| `ZQ` | Close tab without writing (`!`) |
| `<C-w>q` | Close tab or window |
| `<C-w>c` | Close tab when sole editor window; otherwise `close` |

Modified-buffer guards mirror Vim's E37 unless `!` is used.

**Window lifecycle:**

- `WinClosed` restores an editor window if chrome or the last editor pane was closed.
- New editor opens to the right of the explorer root when present, otherwise below chrome.
- Focus cannot remain in the chrome window (`WinEnter` bounces back after 120ms).

**Buffer navigation keymaps** (in lualine spec): `<S-h>`, `<S-l>`, `[b`, `]b` for prev/next buffer.

## Explorer

Configured in `lua/plugins/finder.lua` via **snacks.nvim**.

**Layout:**

- `preset = "sidebar"` — full-height left split.
- `preview = false` — no file preview pane.
- Fixed width: `width = 30`, `min_width = 30`.
- `hidden = true`, `ignored = false` — show dotfiles; hide gitignored entries.
- `git_status = false` by default — enabled for `~/projects/*` so gitignore is applied in the tree.

**Finder filter** — [`lua/config/finder-filter.lua`](lua/config/finder-filter.lua):

| cwd | Explorer | `<leader>ff` |
|-----|----------|--------------|
| `~` | Git-tracked only (minus `.local/share/icons/`) + open buffers | `git_files` with same whitelist |
| `~/projects/*` | Respects `.gitignore` | `fd` with gitignore (no `--no-ignore`) |
| Other | Default snacks behaviour | Default |

**Home (`~`) whitelist details:**

- Git-tracked files from `git ls-files --cached`
- **Excludes** `.local/share/icons/` (~161k theme SVGs)
- **Includes** open nvim buffer paths under `~` (even if untracked)
- Parent directories added so the tree can expand

**Auto-open on startup:**

- **Not** shown on the projects startup screen — only opens once a real file buffer exists.
- Opens after session restore (`PersistenceLoadPost`), `BufReadPost` on a file, or when launched with a file argument (`nvim foo.lua`).
- Skipped for directory launches (`nvim .`) — snacks explorer handles those via `replace_netrw`.
- After open, `editor-chrome` refreshes to align the tab strip with the sidebar.

**Alignment with tab strip:**

`style_explorer_gap()` in editor-chrome pins a blank `winbar = " "` on the explorer sidebar root window so the explorer sits flush under the status bar, matching the blank gap row above tabs in chrome.

**Highlights** (`lua/modular/highlights.lua` → `M.snacks`):

- Picker surfaces use `p.base` background to match the editor.
- Added groups: `SnacksPickerTitle`, `SnacksPickerBoxTitle`, `SnacksPickerInputTitle`, `SnacksPickerToggle`.
- Dimmed/hidden/ignored paths use overlay tones.

**Icons** (`lua/theme-icons.lua`):

- Colours sourced from the active theme palette (Nord tones in current config).
- Applied to `MiniIcons*` highlight groups on mini.icons load.

## Projects

Configured in `lua/plugins/finder.lua` → `picker.sources.projects`.

`list_projects()` builds the picker list:

| Entry | Source |
|-------|------|
| `~` | Dotfiles repo (hypr, evoshell, nvim) |
| `~/projects/*` | Every subdirectory (sorted A–Z) |
| Recent | Git roots from recently opened files (deduped) |

Open with `<leader>fp`. It's a **fuzzy picker** — type to filter the list, Enter to open. Picking a project cds there and restores its persistence session (or opens the file picker if none exists).

Snacks' default `dev` + `fd` scan does not work for `.git` roots because `fd` ignores them without `--no-ignore`.

## Editing guidelines

When changing this layout:

1. **Do not re-enable bufferline** without reconciling tab rendering — tabs are owned by editor-chrome.
2. **Keep `laststatus = 0`** — status content belongs in lualine's tabline slot only.
3. **Preserve the 3-row chrome height** unless intentionally redesigning the gap layout.
4. **Explorer is a sidebar, not a hide_ft target** — only full-screen plugin UIs should suppress the tab strip.
5. **Test quit paths** (`:q`, `ZZ`, middle-click close) after window-layout changes.
6. **Theme changes** — icon colours live in `theme-icons.lua`; picker chrome in `modular/highlights.lua`; both should stay palette-consistent.

## Session restore

Uses LazyVim's **`folke/persistence.nvim`**. Bare **`nvim`** opens the **projects picker** (`<leader>fp` list) — no dashboard, no session loaded.

Pick a project → cds there → restores that project's saved session (or opens the file picker if none exists) → explorer opens when files load.

Skipped when launched with arguments (`nvim foo.lua`, `nvim .`, etc.).

Sessions are only **saved** for `~` and `~/projects/*`. Random file paths do not create sessions on quit.

**Manual restore** (LazyVim defaults):

| Keymap | Action |
|--------|--------|
| `<leader>qs` | Restore session for current cwd |
| `<leader>ql` | Restore last session |
| `<leader>qS` | Select a session |
| `<leader>qd` | Don't save current session |

## Related theme integration

- Colorscheme loads from `~/.themes/current/neovim.lua` via `lua/plugins/theme.lua`.
- `lua/config/autocmds.lua` watches `~/.themes/` and reloads modular highlights on theme swap.
