# evoshopify

![Shopify panel](preview.png)

Shopify store revenue in an Omarchy panel. Today's KPIs and a dotted chart for every store in the data source.

## Install

```bash
omarchy plugin add https://github.com/sebday/omarchy-shopify.git
omarchy plugin enable evo.shopify
```

Open it:

```bash
omarchy-shell shell toggle evo.shopify
```

Or bind it in `~/.config/hypr/bindings.lua`:

```lua
o.rebind("SUPER + SHIFT + S", "Shopify", { panel = "evo.shopify" })
```

## Requirements

- `jq` and `curl` on `PATH`
- `pass show omarchy/ecommerce-data/api-token`

### Worker API

```json
"shopify": {
  "apiUrl": "https://data.day.marketing",
  "pollIntervalMinutes": 5,
  "timezone": "Europe/London",
  "stores": [
    { "key": "DIY", "title": "DIY" },
    { "key": "TGS", "title": "TGS" }
  ]
}
```

`apiUrl` points at the Worker and must be `https://`. Auth is bearer-only from `pass show omarchy/ecommerce-data/api-token`.

On each refresh `shopify-status` posts `/v1/sync/today` (1-day Shopify/Ads/GA4, at most every 4 minutes), then reads `GET /v1/sites/:site/kpi/summary`. Stores come from `GET /v1/sites` when `stores` is omitted.

Store borders follow the current Omarchy theme: cyan, bright green, blue, yellow, magenta. DIY is cyan and TGS is blue.

## Panel

| Key | Action |
|---|---|
| `q` / `esc` | Close |
| `r` | Refresh |
| Tab / Shift+Tab | Next / previous stat |
| `n` / `p` | Next / previous store |

Click a stat to chart it. Close the window, or press `q` or `esc`.

The panel runs `bin/shopify-status` for data and `bin/panel-config` for the poll interval and theme colours. Both go through `bin/panel-run`, which caps output and kills the command when the panel closes.

## Removing

```bash
omarchy plugin remove evo.shopify
```

That deletes the plugin directory. It does not delete:

- `~/.cache/omarchy/bar/*.json` shopify caches
- `~/.cache/omarchy/shopify-icons/`
- `pass` entry `omarchy/ecommerce-data/api-token`

Network: the configured HTTPS worker origin.
