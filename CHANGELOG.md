# Changelog

All notable changes to the Amateur Radio Suite (container app). Format follows
[Keep a Changelog](https://keepachangelog.com/); the suite is pre-1.0 so dates, not versions.

## [Unreleased]

### Added — release engineering
- **Notarized releases.** `notarize.sh` builds the universal bundle, re-signs it with the
  Developer ID + hardened runtime + secure timestamp (replacing `build-app.sh`'s ad-hoc
  signature), submits to Apple's notary service, staples the ticket, and packages a stapled
  `.zip` and `.dmg` that pass Gatekeeper with no right-click-Open / `xattr` dance.
- Releases are cut **locally** (`./notarize.sh <version>` + `gh release create`); the signing
  cert and notary credentials stay on the build machine, so there is no CI release pipeline.

### Added — Phase 5 (polish)
- Unified **Settings** hub: a General pane (layout, Safe Mode, onboarding) plus a pane per
  plugin that provides a `settingsView`.
- Single host **About** panel for the suite.
- **Command palette** — searchable switcher for plugins and the active plugin's commands.
- **State restoration** — the suite reopens to the last-active plugin and layout.
- First-run **onboarding** sheet.

### Added — Phase 4 (browse + install)
- `PluginCatalog`/`CatalogEntry` index format and `CatalogService` (multi-source fetch,
  user-addable custom catalogs, persisted sources).
- `PackageInstaller` — install a `.radioplugin` (zip): SHA-256 verify → unzip → validate
  manifest/host compatibility → place where discovery finds it; uninstall.
- Plugin Browser: Installed (enable/uninstall) + Browse (install/update) tabs, sideload from
  file, catalog-source management. Sample `docs/catalog/` catalog + package.
- _Deferred:_ code-signature/notarization verification (needed before running untrusted
  plugins; gated on a signing identity) — installs are checksum-verified and land as `discovered`.

### Added — Phase 3 (out-of-process tier, ExtensionKit)
- SDK 1.2 extension-point contract + typed Codable host↔extension channel.
- `PluginSupervisor` — restart-with-backoff and crash-loop quarantine; host **Safe Mode**.
- `Xcode/` workspace (XcodeGen-authored, committed): host app + sample `DemoSDRExtension.appex`,
  built and embedded; `EXHostViewController` hosting + `AppExtensionIdentity` discovery compile.
- _Parked:_ signed runtime / extension approval (requires an Apple Developer account).

### Added — Phase 2 (dynamic discovery)
- `PluginManager` merges built-in + installed plugin sources; installed plugins discovered from
  `plugin.json` under Application Support without recompiling. "Manage Plugins" UI.

### Added — Phase 1 (SDK hardening)
- RadioPluginKit 1.1: `RadioPluginManifest`, `PluginCapability`, `PluginError`,
  `PluginNotification`/`PluginBadge`; enriched `PluginHost` (report/notify/setBadge) and
  `RadioPlugin` (manifest/state).
- `RadioPluginUI` design system: `RadioTheme` + `StatusBadge`/`Banner`/`EmptyStateView`.

### Added — foundation
- Container app hosting radio apps as **static SwiftPM plugins** behind the `RadioPlugin`
  contract; sidebar ⇄ tabs toggle; per-plugin namespaced defaults; routed menu commands.
- First-party plugins: **LP-700, LP-100A, Band Pass Filter, Antenna Switch**.
- Universal (arm64 + x86_64) `.app` build with an app icon (`build-app.sh`, `make-icon.sh`).
- RadioPluginKit consumed as a versioned Git dependency (tags 1.0.0 → 1.2.0).

### Notes
- SPE Amp (MacExpert) intentionally excluded — it is an upstream fork.
- LP-700 #6 / LP-100A #1 / BPF #4 carry plugin support on `plugin-architecture` branches (open PRs).
