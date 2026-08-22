# Agent guide

Short reference for this LazyVim config — layout, explorer, sessions, and Cursor integration.

## Layout

```
┌─────────────────────────────────────────────────────────┐
│  status bar (lualine tabline)                           │
├──────────────┬──────────────────────────────────────────┤
│   explorer   │  blank / tabs / blank (editor_chrome)    │
│   (snacks)   ├──────────────────────────────────────────┤
│              │  editor buffer                           │
└──────────────┴──────────────────────────────────────────┘
```

- **lualine** — status bar only (`laststatus = 0`). No bufferline.
- **editor-chrome** — 3-row tab strip above the editor; remaps `:q` / `ZZ` to close buffer tabs, not windows.
- **snacks explorer** — persistent left sidebar, aligned with the tab strip via `style_explorer_gap()`.

## Key files

| File | Role |
|------|------|
| `lua/config/editor-chrome.lua` | Tab strip, mouse tabs, quit semantics, explorer alignment |
| `lua/plugins/lualine.lua` | Status-only lualine; boots editor-chrome |
| `lua/plugins/finder.lua` | Snacks explorer, files picker, projects list, auto-open |
| `lua/plugins/session.lua` | Persistence limited to `~` and `~/projects/*` |
| `lua/modular/highlights.lua` | Snacks picker highlights |
| `lua/theme-icons.lua` | Theme-synced mini.icons colours |

## Explorer & finders

Configured in `lua/plugins/finder.lua` (snacks.nvim).

- Sidebar: 30 cols, no preview, `git_status = false`
- `hidden = true`, `ignored = true` — show all files (dotfiles + gitignored). Needed at `~` because `.gitignore` is `*`.
- Files picker excludes `node_modules` only
- Auto-opens after session restore or when a file buffer loads; not on bare `nvim` (projects picker instead)

## Projects & sessions

- Bare `nvim` → projects picker (`<leader>fp`): `~`, `~/projects/*`, recent git roots
- Pick a project → restore its persistence session → explorer opens with files
- Sessions only **saved** for `~` and `~/projects/*`
- Launches with args (`nvim foo.lua`) skip the projects picker

## Cursor

Say **"open in nvim"** to push files via `evo nvim-open`. See `skills/nvim-open/SKILL.md`.

## When editing

1. Tabs live in editor-chrome — don't re-enable bufferline without a plan.
2. Keep `laststatus = 0` and the 3-row chrome height unless redesigning.
3. Explorer is a sidebar, not a full-screen UI — don't add it to `hide_ft`.
4. Theme: colours in `theme-icons.lua` and `modular/highlights.lua`; colorscheme from `~/.themes/current/neovim.lua`.
