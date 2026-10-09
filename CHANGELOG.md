# Changelog

All notable changes to the Amateur Radio Suite (container app). Format follows
[Keep a Changelog](https://keepachangelog.com/); the suite is pre-1.0. Sections are headed by the
release tag on [vu2cpl/AmateurRadioSuite](https://github.com/vu2cpl/AmateurRadioSuite/releases)
and its date.

## [Unreleased]

## [0.1.29] — 2026-10-09

The fork's first release since v0.1.15. It merges Vinod VU3ESV's upstream v0.1.16–v0.1.28
(listed below; his full notes are on
[VU3ESV/AmateurRadioSuite releases](https://github.com/VU3ESV/AmateurRadioSuite/releases))
and adds the fork's update check. The number continues after his v0.1.28 so that no tag here
means something different from the same tag upstream. (This section was drafted as
`[0.1.16]` before the merge.) Released 2026-10-09 as
[v0.1.29](https://github.com/vu2cpl/AmateurRadioSuite/releases/tag/v0.1.29):
`AmateurRadioSuite-0.1.29.dmg` / `.zip` (notarized + stapled, universal) and `SHA256SUMS`.

### Merged from upstream — Vinod VU3ESV's v0.1.16–v0.1.28
- **v0.1.16** — the host declares the custom extension point `org.vu3esv.radiosuite.plugin`,
  the actual fix for the empty plugins view
  ([#19](https://github.com/VU3ESV/AmateurRadioSuite/pull/19)).
- **v0.1.17** — the host loads third-party plugins: live discovery of installed extensions,
  and the macOS enable/disable browser opened from **Manage Plugins**
  ([#20](https://github.com/VU3ESV/AmateurRadioSuite/pull/20)).
- **v0.1.18 / v0.1.19** — `scripts/package-plugin-app.sh` (embed + sign + notarize + install a
  plugin app) and the distribution model: install the plugin's app, not just its
  `.radioplugin` ([#21](https://github.com/VU3ESV/AmateurRadioSuite/pull/21),
  [#22](https://github.com/VU3ESV/AmateurRadioSuite/pull/22)).
- **v0.1.20** — releases ship **RadioSuiteHost**, the Xcode hosting build with the DemoSDR
  sample extension embedded, signed + notarized by `scripts/package-host-signed.sh`; the lean
  SwiftPM build declares no extension point and can only show placeholders
  ([#23](https://github.com/VU3ESV/AmateurRadioSuite/pull/23)).
- **v0.1.21** — CI actions on the Node 24 runtime
  ([#24](https://github.com/VU3ESV/AmateurRadioSuite/pull/24)).
- **v0.1.22** — the Plugins manager is resizable and its controls no longer overlap; the app
  icon is back on the RadioSuiteHost build; the signing identity is picked by SHA-1
  ([#25](https://github.com/VU3ESV/AmateurRadioSuite/pull/25)).
- **v0.1.23** — the Suite DMG itself is codesigned, notarized and stapled
  ([#26](https://github.com/VU3ESV/AmateurRadioSuite/pull/26)).
- **v0.1.24** — hosted plugin panes stay alive across tab and sidebar switches, so a plugin
  keeps its connection and state ([#27](https://github.com/VU3ESV/AmateurRadioSuite/pull/27)).
- **v0.1.25** — each plugin shows its own app icon in the sidebar and the Plugin Manager;
  codesign retries when Apple's timestamp service is unavailable
  ([#28](https://github.com/VU3ESV/AmateurRadioSuite/pull/28)).
- **v0.1.26 / v0.1.27** — screenshots in the README and guides; ARCHITECTURE documents the
  pane keep-alive ([#29](https://github.com/VU3ESV/AmateurRadioSuite/pull/29),
  [#30](https://github.com/VU3ESV/AmateurRadioSuite/pull/30)).
- **v0.1.28** — his CI skips a release for docs-only changes
  ([#31](https://github.com/VU3ESV/AmateurRadioSuite/pull/31),
  [#32](https://github.com/VU3ESV/AmateurRadioSuite/pull/32)). Not used here: this fork has
  no CI release workflow (see below).

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
- **The release is now the hosting build**, RadioSuiteHost, as upstream since v0.1.20 — v0.1.15
  shipped the lean SwiftPM build, which can only show placeholders for out-of-process plugins.
  Universal (arm64 + x86_64) for the app and the embedded DemoSDR extension, like v0.1.15.
- Releases are cut **locally** (`scripts/package-host-signed.sh` + `gh release create`); the
  signing cert and notary credentials stay on the build machine, so there is no CI release
  pipeline. The merge keeps upstream's `.github/workflows/release.yml` deleted: on this repo it
  would publish an ad-hoc build on every PR merge, with no signing secrets.
- `scripts/package-host-signed.sh` gains a local mode: `DEV_ID` signs with a Developer ID
  already in the keychain, `NOTARY_PROFILE` notarizes with a `notarytool` keychain profile
  (`ARS-NOTARY`). Without them it behaves as before (CI `.p12` + Apple ID secrets, or ad-hoc).
  It now builds for `generic/platform=macOS` (universal; `platform=macOS` built arm64 only on
  Xcode 27), and zips with `--norsrc`.
- Release zips use `ditto -c -k --norsrc --keepParent`, so they carry no AppleDouble `._*`
  entries (v0.1.15's `--sequesterRsrc` zip had 15; a non-Apple unzipper can write them into
  the bundle and break its seal). `notarize.sh` (the lean build) does the same.
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
