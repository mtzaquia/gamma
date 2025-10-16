# Theme format

A theme is a JSON document decoded as `RawTheme`. Token keys are stable identifiers; display names and groups are metadata.

| Field | Purpose |
| --- | --- |
| `id` | Logical identity supplied by the theme producer and used in diagnostics. |
| `defaults` | Font and foreground aliases applied by `.theme(...)`. |
| `colors` | Dynamic color tokens keyed by alias. |
| `fonts` | Typography tokens keyed by alias. |
| `units` | Numeric spacing, sizing, or radius tokens keyed by alias. |

Every color, font, and unit entry contains `name`, `group`, `description`, and `modes`. The first three fields are required by the schema; `name` and `group` must be non-empty. A description may be empty.

Each successfully decoded payload receives a separate runtime identity. Replacing server data therefore updates SwiftUI and resolution caches even when the logical `id` remains unchanged.

Bundled and server-provided themes use the same `RawTheme` format. `.theme(.app)` loads a generated bundled resource once per resource-and-bundle pair and reuses that decoded identity across SwiftUI body evaluations. The app may decode downloaded JSON away from the main actor, then install the resulting value with `.theme(...)`. If the payload references custom faces, download them separately and supply their local file URLs through `fontURLs:`; the theme's `fontName` values remain the authoritative PostScript names.

The build generator checks alias compatibility only among the `*.theme.json` files included in its inputs. A runtime-only server theme must preserve the alias keys compiled into the app. Gamma validates its schema and selected modes immediately, while a missing generated alias that is not referenced by the theme defaults is diagnosed when the app resolves that alias.

## Defaults

Defaults reference keys in the same document.

```json
"defaults": {
  "font": "font/body",
  "primaryTextColor": "color/text-primary",
  "secondaryTextColor": "color/text-secondary"
}
```

`font` and `primaryTextColor` are required. `secondaryTextColor` is optional. When present, Gamma installs a hierarchical foreground style with both colors.

## Colors

Each color mode contains a six-digit `#RRGGBB` value and an alpha between `0` and `1`.

```json
"color/background": {
  "name": "Background",
  "group": "Surface",
  "description": "App background",
  "modes": {
    "day": { "hex": "#F3F5FA", "alpha": 1 },
    "night": { "hex": "#111319", "alpha": 1 }
  }
}
```

Mode names are yours. The resolver chooses which mode represents light appearance and which represents dark appearance.

## Fonts

A font mode describes one face and its design metrics.

```json
"font/body": {
  "name": "Body",
  "group": "Typography",
  "description": "ios:body",
  "modes": {
    "default": {
      "fontSize": 17,
      "fontName": "NotoSans-Regular",
      "lineHeight": 24,
      "letterSpacing": 0,
      "textCase": "ORIGINAL"
    }
  }
}
```

| Field | Rule |
| --- | --- |
| `fontName` | A non-empty PostScript name. The face must be built in, registered by the app, or supplied through `.theme(..., fontURLs:)`. |
| `fontSize` | A finite value greater than zero. |
| `lineHeight` | A finite value greater than zero. |
| `letterSpacing` | A finite percentage; `0` disables kerning adjustment. |
| `textCase` | `ORIGINAL`, `UPPER`, or `LOWER`. |

The description may include an iOS text-style marker so Dynamic Type uses the matching `UIFontMetrics`. Supported markers are `ios:largeTitle`, `ios:title`, `ios:title1`, `ios:title2`, `ios:title3`, `ios:headline`, `ios:subheadline`, `ios:body`, `ios:callout`, `ios:footnote`, `ios:caption`, `ios:caption1`, and `ios:caption2`. An unmarked font uses `.body` metrics.

## Units

Units are finite numeric values. A group produces the generated alias type; all units in that group share it.

```json
"space/medium": {
  "name": "Medium",
  "group": "Spacing",
  "description": "Default content spacing",
  "modes": {
    "default": 16
  }
}
```

This group generates `Theme.SpacingAlias`; the token itself is available as `.spaceMedium` where that alias type is inferred. Responsive modes such as `compact` and `regular` remain available through a custom resolver.

## Validation

`RawTheme` rejects malformed schema during decoding. Validation checks:

- non-empty theme IDs, token keys, names, and groups;
- defaults that reference existing tokens;
- at least one mode for every token;
- color format and alpha bounds;
- font names, metrics, and text case;
- finite unit values.

The modes selected by a resolver are checked when the theme is installed and whenever its resolution context changes. That catches a structurally valid theme whose resolver asks for a mode it does not define. After supplied font files are registered, the selected primary and cascade PostScript names are also checked for availability through UIKit.

Next: [Mode resolution](modes.md) · [Diagnostics](diagnostics.md)
