# Contributing

Agents welcome :)

## Commit messages

```
type: imperative lowercase subject
```

| Part | Rule |
|------|------|
| type | `fix`, `feat`, `chore`, `docs`, `refactor`, or `test` |
| subject | imperative, lowercase, no trailing period |

### Examples

```
fix: carousel cli paths use EVOSHELL_BIN
feat: personal directory in settings and config
fix: system menu fieldsets use notch legend
chore: add catppuccin wallpaper pack
docs: commit message convention
```

Add a body only when the reason or breaking change is not obvious.

## Branching

Default branch: `master`. All pull requests target `master`.

Topic branches use GitHub Flow — one focused change per branch, deleted after merge.

```
<type>/<subject>
```

| Part | Rule |
|------|------|
| type | same as commits: `fix`, `feat`, `chore`, `docs`, `refactor`, or `test` |
| subject | lowercase kebab-case |

### Examples

```
feat/personal-directory
fix/menu-fieldset-notch
feat/bar-tray-widget-toggle
chore/ci-static-contracts
docs/commit-message-convention
```

### Workflow

- Branch from `master`
- Keep one concern per branch
- First commit on the branch should match `type: subject`
- Delete the topic branch after merge
