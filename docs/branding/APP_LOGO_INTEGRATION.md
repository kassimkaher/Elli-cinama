# App Logo / Brand Mark Integration

## Concept

An original, generic geometric mark for a premium sports + cinema streaming app:

- a **pale-gold motion chevron** `>` — speed / sports energy;
- flowing into a **solid-gold play triangle** — cinema / streaming / play.

Together they read as **fast-forward / live motion / play**. Clean, geometric, legible at
small icon sizes, and designed for **dark surfaces**. It does not copy any existing TV,
cinema, sports, or broadcaster logo.

Palette: accent gold `#E8B14C` on deep charcoal `#0E0D0C` (the app's existing tokens).

## Assets

Source assets (regenerable) live in `abk_flutter/assets/brand/`:

| File | Use |
|---|---|
| `abk_icon.png` (1024²) | full tile: dark bg + gold mark + subtle radial glow — iOS / macOS / legacy Android launcher |
| `abk_icon_foreground.png` (1024², transparent) | Android **adaptive** foreground (safe-zone padded), on solid `#0E0D0C` background |
| `abk_mark.png` (512², transparent) | mark-only reference export |

Regeneration (deterministic, no external services): the mark geometry is drawn by
`scratchpad/gen_icon.py` (Pillow). The **same geometry** is drawn in-app by a Flutter
`CustomPainter`, so the icon and in-app mark stay identical.

## In-app usage (one shared widget)

`lib/shared/widgets/brand.dart` → `AbkLogo` (vector `CustomPaint`, crisp at any size):

| Constructor | Treatment | Used in |
|---|---|---|
| `AbkLogo.chip(size)` | accent-gold tile + dark mark (matches the app's chip aesthetic) | login form mark, sidebar brand, launch screen |
| `AbkLogo.mark(size)` | gold mark on transparent (brand moment on dark) | login desktop split |
| `AbkWordmark` | mark + “ABK” text | sidebar (labelled) |

**Placeholder `A` removed** everywhere it appeared:
- `features/auth/presentation/login_screen.dart` (form chip + desktop split “ABK”),
- `features/shell/adaptive_shell.dart` (`_Brand` sidebar mark),
- `features/launch/launch_screen.dart` (launch brand).

Verified by `test/widget/brand_test.dart` (no `A`/`ABK` text placeholder; renders in dark
+ light; no overflow) and `find`-based checks.

## App icon integration

Generated with **`flutter_launcher_icons` 0.14.4** (`dart run flutter_launcher_icons`),
configured in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  image_path: "assets/brand/abk_icon.png"
  android: true
  min_sdk_android: 21
  adaptive_icon_background: "#0E0D0C"
  adaptive_icon_foreground: "assets/brand/abk_icon_foreground.png"
  ios: true
  remove_alpha_ios: true
  macos:
    generate: true
    image_path: "assets/brand/abk_icon.png"
```

Platform coverage generated:
- **Android** — legacy `mipmap` icons + **adaptive** icon (`mipmap-anydpi-v26/ic_launcher.xml`, foreground + `#0E0D0C` background), `colors.xml` added.
- **iOS** — full `AppIcon.appiconset` (21 sizes), alpha flattened (`remove_alpha_ios`).
- **macOS** — `AppIcon.appiconset` (7 sizes).
- **Windows / Linux** — no runner scaffolding yet (added when those phases start); the source asset path is ready to reuse.

## Adaptive / theme considerations

- The mark is gold on dark → high contrast; the in-app **chip** uses a gold tile so it also
  stands out on the dark UI (never muddy on dark surfaces).
- Works in **dark** and **light** themes (tested), **Arabic RTL** / **English LTR** (the
  mark is direction-neutral; the play triangle intentionally points inline-forward), and
  across **compact → large** widths (fixed `size`, no layout dependence).
- Vector `CustomPainter` in-app → crisp at every density; PNG icon supersampled for clean
  small-size rendering.

## Regenerating

1. Edit geometry in `scratchpad/gen_icon.py` (and mirror in `brand.dart` if the shape
   changes), run it to refresh `assets/brand/*.png`.
2. `dart run flutter_launcher_icons` to regenerate platform icons.
