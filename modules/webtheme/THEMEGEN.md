# Theme a personal Webtheme site

Add **one** user package under `~/.config/omarchy/webtheme/sites/<id>/` so the current Omarchy palette applies on this host. Do not add a bundled package. Do not edit files under this plugin’s `sites/` directory or anything in `/usr/share/omarchy/`.

Work from the plugin repo (this directory). After writing the package, run `./bin/webtheme assemble` so open Brave/Chromium tabs hotload the CSS. No browser restart.

## Target

The launch prompt names the URL, page title, host, and a suggested `id`. Use that id unless it is invalid. `id` must match `^[A-Za-z0-9][A-Za-z0-9._-]*$`. Prefer the registrable host with `www.` stripped (`github.com` → `github`).

If this host already has a **user** package, update that package instead of creating a second one. If only a bundled package exists, leave the bundle alone and write a user override with the same `id` only when the user asked to restyle it.

## Layout

```
~/.config/omarchy/webtheme/sites/<id>/
  site.json
  style.css
```

### site.json

```json
{
  "id": "example",
  "name": "Example",
  "matches": ["https://example.com/*"],
  "enabled": true
}
```

- `name` is a short product name, not the full document title.
- `matches` are Chrome match patterns. Use `https://<host>/*`. Add `https://www.<host>/*` only when that host actually serves the same app.
- Do not add unrelated hosts, APIs, or CDNs.
- `enabled` must be `true`.

## CSS contract

`style.css` must remap the **site’s existing tokens** onto Omarchy web variables from `themed/colors.css.tpl`:

| Token | Use |
| --- | --- |
| `--bg-primary` | page / chrome background |
| `--bg-secondary` | panels, sidebars, raised surfaces (`lighter_background`) |
| `--bg-deep` | inset / shade (`dark_background`) |
| `--text-primary` | body text |
| `--text-muted` | secondary text (`dark_foreground`) |
| `--text-bright` | headings / emphasis (`bright_foreground`) |
| `--text-accent` | links, highlights, focus |
| `--border` | dividers (`muted`) |
| `--border-subtle` | hairlines (`selection`) |
| `--blue` `--cyan` `--purple` `--pink` `--green` `--orange` `--red` | semantic / chart / accent colours the site already exposes |

Those variables are injected by the extension as `colors.css` on matching tabs. Do not hard-code hex from the current wallpaper. Do not invent a second palette.

Copy the density of bundled examples:

- GitHub (`sites/github/style.css`): a few upstream tokens, not a restyle of every component.
- omarchy.org (`sites/omarchy/style.css`): map the site’s own `--color-*` names onto Omarchy vars.
- Grok / YouTube: override the background tokens the app already uses; `!important` only when the site’s stylesheet wins without it.

Prefer:

```css
:root {
  --the-site-bg: var(--bg-primary);
  --the-site-text: var(--text-primary);
}
```

Avoid restyling typography, radii, shadows, or layout. Do not hide features. Do not scrape assets.

If you can read the live page, inspect computed custom properties and map those. If you cannot, fetch the HTML/CSS and search for `--*` tokens, `color-scheme`, and background variables.

## Finish

1. Write `site.json` and `style.css`.
2. Run `./bin/webtheme assemble`.
3. Stop. Do not commit, push, install packages, touch browser flags, or edit the unpacked runtime under `~/.local/share/omarchy/webtheme/extension/` by hand.
