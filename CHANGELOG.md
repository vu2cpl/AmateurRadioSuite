# Changelog

All notable changes to the Amateur Radio Suite (container app). Format follows
[Keep a Changelog](https://keepachangelog.com/); the suite is pre-1.0. Sections are headed by the
release tag on [vu2cpl/AmateurRadioSuite](https://github.com/vu2cpl/AmateurRadioSuite/releases)
and its date.

## [Unreleased]

## [0.1.16] — 2026-10-09

### Added — update check
- **Check for Updates** against this repo's GitHub releases: about 10 s after launch, at most
  once a day, one anonymous `GET` of `api.github.com/repos/vu2cpl/AmateurRadioSuite/releases/latest`;
  if the tag is newer than `CFBundleShortVersionString`, a dialog with the release notes and
  **Download** (opens the release page) / **Skip This Version** / **Remind Me Later**.
  **Check for Updates…** in the app menu (after About) always reports; **Settings → General →
  Updates → Check for updates automatically** (default on) turns the daily check off. Nothing
  is downloaded or installed automatically. `Sources/RadioSuite/UpdateChecker.swift` is
  byte-identical across VU2CPL's Swift apps; both entry points get it through `SuiteScene`.
- Refined 2026-10-09: only a successful check (HTTP 200 with a `tag_name`) stores the time — a
  failed one (offline, timeout, any HTTP error including the 403 rate limit, bad JSON) stores
  nothing and is retried at the next launch, or after 1 h while running; an hourly timer
  repeats the daily check for as long as the suite runs (never while one of its dialogs is
  open); and a development build (version containing "dev", e.g. `build-app.sh`'s
  `0.0.0-dev` fallback) never checks on its own — Check for Updates… still works.

### Changed — release engineering
- Releases are cut **locally** (`./notarize.sh <version>` + `gh release create`); the signing
  cert and notary credentials stay on the build machine, so there is no CI release pipeline.
- `notarize.sh` zips with `ditto -c -k --norsrc --keepParent`, so the release `.zip` carries no
  AppleDouble `._*` entries (v0.1.15's `--sequesterRsrc` zip had 15; a non-Apple unzipper can
  write them into the bundle and break its seal).
- MIT `LICENSE` file added to the repository.

## [0.1.15] — 2026-06-03, and everything before it

### Added — release engineering
- **Notarized releases.** `notarize.sh` builds the universal bundle, re-signs it with the
  Developer ID + hardened runtime + secure timestamp (replacing `build-app.sh`'s ad-hoc
  signature), submits to Apple's notary service, staples the ticket, and packages a stapled
  `.zip` and `.dmg` that pass Gatekeeper with no right-click-Open / `xattr` dance. v0.1.15 was
  the first notarized release.

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
