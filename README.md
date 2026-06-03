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

The suite ships with **no plugins and an empty catalog** — nothing is baked in. You populate
it from within the app: **Manage Plugins → Browse → “Add Plugin from File…”** points the app
at a `.radioplugin`, which is added to your (persisted) catalog; from there you Install it.
(You can also subscribe to a remote catalog URL.) Apps published as installable plugins:

| Plugin | Source repo |
|---|---|
| LP-700 | [LP-700-App](https://github.com/VU3ESV/LP-700-App) |
| LP-100A | [LP-100A-App](https://github.com/VU3ESV/LP-100A-App) |
| Band Pass Filter | [BandPassFilterControllerApp](https://github.com/VU3ESV/BandPassFilterControllerApp) |
| Antenna Switch | [AntennaSwitchController](https://github.com/VU3ESV/AntennaSwitchController) |

Planned: SPE amplifier (MacExpert), SO2R Box.

To turn one of these apps into an installable out-of-process plugin, follow
[docs/CONVERTING-A-PLUGIN.md](docs/CONVERTING-A-PLUGIN.md) — a step-by-step playbook with
**LP-700** as the worked reference (its `.appex` + `.radioplugin` + catalog entry are live).

## Build & run

The suite builds standalone — its only dependency is `RadioPluginKit` (resolved from
its Git URL), so **no sibling repos are needed**:

```sh
./build-app.sh
open "dist/Amateur Radio Suite.app"
```

A bundled `.app` is required for the window to activate normally (a raw `swift run`
binary has no `Info.plist` / activation policy). `build-app.sh` **ad-hoc-signs** the bundle —
fine for local use, but other Macs' Gatekeeper will block it.

### Notarized release

For a build that runs cleanly on any Mac, use `notarize.sh` — it re-signs with the Developer
ID + hardened runtime, submits to Apple's notary service, staples the ticket, and packages a
stapled `.zip` and `.dmg`:

```sh
# one-time: store notary credentials in the keychain
xcrun notarytool store-credentials ARS-NOTARY \
  --apple-id <apple-id> --team-id CHVNJ85C9F --password <app-specific-pw>

./notarize.sh 0.1.15          # → dist/AmateurRadioSuite-0.1.15.{zip,dmg}
```

CI does this automatically: merging a PR into `main` triggers `.github/workflows/release.yml`,
which patch-bumps the version, notarizes, and publishes a GitHub Release. It needs the repo
secrets `APPLE_CERT_BASE64`, `APPLE_CERT_PASSWORD`, `APPLE_ID`, `APPLE_APP_PASSWORD`,
`APPLE_TEAM_ID`.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full developer guide — how the suite and
plugin architecture work, with diagrams, and exactly what an app must do to be hosted.
See [PLAN.md](PLAN.md) for the per-app integration plan, and
[PLUGIN-PLATFORM.md](PLUGIN-PLATFORM.md) for the plan to open the plugin contract to
third-party developers (browse + install, crash isolation, styling, error/notification handling).

Requires macOS 14+.

## License

[MIT](LICENSE) © 2026 Manoj Ramawarrier (VU2CPL).
