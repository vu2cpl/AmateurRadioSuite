# Amateur Radio Suite

A single macOS container app that hosts independent amateur-radio control apps as
**plugins** in one window — switchable between a vertical sidebar and horizontal tabs.

Each app stays in its own repository and ships as a standalone `.app`; the suite
loads it through the [`RadioPluginKit`](https://github.com/VU3ESV/RadioPluginKit)
contract. The host links **only the contract** — it does not compile in any plugin.
Plugins are **discovered and installed at runtime** (browse a catalog or sideload a
`.radioplugin`) and run **out-of-process** as sandboxed ExtensionKit extensions, so
adding a plugin never requires rebuilding the suite.

## Plugins

Plugins are installed from within the app (**Manage Plugins → Browse / Install from
File**), not built in. Apps published as installable plugins:

| Plugin | Source repo |
|---|---|
| LP-700 | [LP-700-App](https://github.com/VU3ESV/LP-700-App) |
| LP-100A | [LP-100A-App](https://github.com/VU3ESV/LP-100A-App) |
| Band Pass Filter | [BandPassFilterControllerApp](https://github.com/VU3ESV/BandPassFilterControllerApp) |
| Antenna Switch | [AntennaSwitchController](https://github.com/VU3ESV/AntennaSwitchController) |

Planned: SPE amplifier (MacExpert), SO2R Box.

## Build & run

The suite builds standalone — its only dependency is `RadioPluginKit` (resolved from
its Git URL), so **no sibling repos are needed**:

```sh
./build-app.sh
open "dist/Amateur Radio Suite.app"
```

A bundled `.app` is required for the window to activate normally (a raw `swift run`
binary has no `Info.plist` / activation policy).

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full developer guide — how the suite and
plugin architecture work, with diagrams, and exactly what an app must do to be hosted.
See [PLAN.md](PLAN.md) for the per-app integration plan, and
[PLUGIN-PLATFORM.md](PLUGIN-PLATFORM.md) for the plan to open the plugin contract to
third-party developers (browse + install, crash isolation, styling, error/notification handling).

Requires macOS 14+.
