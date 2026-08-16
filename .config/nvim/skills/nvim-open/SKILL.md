---
name: nvim-open
description: >-
  Opens files in the user's running Neovim instance via evo-nvim-open.
  Use when the user says open in nvim, open in neovim, open those files in nvim,
  push to nvim, nvim open, or wants files sent to Neovim instead of the Cursor editor.
---

# Open in Neovim

Canonical path: `~/.config/nvim/skills/nvim-open/SKILL.md` (symlinked at `~/.cursor/skills/nvim-open`).

Send files to the user's running Neovim (not the Cursor editor) using `~/.local/bin/evo-nvim-open`.

## When to use

Apply this skill when the user wants files opened in **Neovim**, including phrases like:

- "open in nvim"
- "open in neovim"
- "open those files in nvim"
- "push to nvim"

Works in a **new chat** with no prior history — use only the current message and workspace.

## Workflow

1. **Identify files** (priority order):
   - Paths the user named explicitly
   - `@`-mentioned files
   - Paths from code citations or backticks
   - Files the agent edited in this chat
   - If still unclear → ask which files

2. **Resolve to absolute paths** (expand `~`, resolve relative paths against workspace root).

3. **Run immediately** — do not open files in Cursor instead:

```bash
~/.local/bin/evo-nvim-open /abs/path/one /abs/path/two
```

Line jumps:

```bash
~/.local/bin/evo-nvim-open --line 42 /abs/path/file.lua
~/.local/bin/evo-nvim-open /abs/path/file.lua:42
```

4. **Report** which files opened, or surface the CLI error.

## Constraints

- Do **not** focus or raise the Neovim window
- Do **not** spawn Neovim if none is running — tell the user to open the project in nvim first
- Do **not** use Cursor's editor open actions when the user asked for Neovim

## Errors

| CLI message | Meaning |
|-------------|---------|
| `no neovim server running` | Start nvim first |
| `no neovim instance for workspace` | Open the project cwd in nvim (lists available cwds) |
| `file not found` | Fix the path |
