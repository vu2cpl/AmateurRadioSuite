# Amateur Radio Suite

A single macOS container app that hosts independent amateur-radio control apps as
**plugins** in one window — switchable between a vertical sidebar and horizontal tabs.

Each app stays in its own repository and continues to ship as a standalone `.app`;
the suite loads it through the [`RadioPluginKit`](https://github.com/VU3ESV/RadioPluginKit)
contract. Static SwiftPM plugin model — the container links each app as a library
conforming to `RadioPlugin` and registers it in [`PluginRegistry`](Sources/RadioSuite/PluginRegistry.swift).

## Plugins wired

| Plugin | Source repo |
|---|---|
| LP-700 | [LP-700-App](https://github.com/VU3ESV/LP-700-App) |
| LP-100A | [LP-100A-App](https://github.com/VU3ESV/LP-100A-App) |
| Band Pass Filter | [BandPassFilterControllerApp](https://github.com/VU3ESV/BandPassFilterControllerApp) |

Planned: SPE amplifier (MacExpert), SO2R Box.

## Build & run

This package uses **local path dependencies**, so clone the plugin repos as siblings:

```
Projects/
  RadioPluginKit/
  LP-700-App/
  LP-100A-App/
  BandPassFilterControllerApp/
  AmateurRadioApps/   ← this repo
```

```sh
./build-app.sh
open "dist/Amateur Radio Suite.app"
```

A bundled `.app` is required for the window to activate normally (a raw `swift run`
binary has no `Info.plist` / activation policy).

See [PLAN.md](PLAN.md) for the full architecture and per-app integration plan, and
[PLUGIN-PLATFORM.md](PLUGIN-PLATFORM.md) for the plan to open the plugin contract to
third-party developers (browse + install, crash isolation, styling, error/notification handling).

Requires macOS 14+.
