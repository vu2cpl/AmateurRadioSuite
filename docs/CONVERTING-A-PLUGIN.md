# Converting an app into an installable out-of-process plugin

A step-by-step **playbook** for turning a standalone radio app into a sandboxed,
crash-isolated **ExtensionKit `.appex`** that the [Amateur Radio Suite](https://github.com/VU3ESV/AmateurRadioSuite)
can **browse, install, and host** at runtime — without the suite compiling the app in.

It is written so a **fresh Claude session (or any developer)** can apply it to one app at
a time. **LP-700** is the worked reference: every step links to the real files in
[LP-700-App](https://github.com/VU3ESV/LP-700-App). To convert another app
(LP-100A, Band Pass Filter, Antenna Switch, …), repeat the steps and substitute the
values in the table below.

> Background: [ARCHITECTURE.md](https://github.com/VU3ESV/AmateurRadioSuite/blob/main/ARCHITECTURE.md)
> (esp. §8) and [docs/EXTENSIONKIT.md](https://github.com/VU3ESV/AmateurRadioSuite/blob/main/docs/EXTENSIONKIT.md).

---

## 0. Per-app variables (substitute these)

| Variable | LP-700 value | Where it's used |
|---|---|---|
| `<RepoModule>` | `LP700App` | the SwiftPM library product that holds the app's views |
| `<RootView>` | `ContentView(vm: MeterViewModel())` | the SwiftUI root the plugin shows |
| `<PluginName>` | `LP-700` | display name (manifest + Info.plist) |
| `<BundleID>` | `org.vu3esv.radiosuite.LP700` | the `.appex` bundle id **and** `plugin.json` `id` (they MUST match) |
| `<SystemImage>` | `gauge.with.dots.needle.bottom.50percent` | SF Symbol for the sidebar/tab |
| `<capabilities>` | `["network.client","notifications"]` | what the plugin touches |
| `<ExtTarget>` | `LP700Extension` | the Xcode `.appex` target/scheme name |
| `<pkg>` | `LP700.radioplugin` / `lp700.radioplugin` | the installable package filename |

**The one rule that matters:** the `.appex` **bundle identifier** must equal the
`plugin.json` **`id`**. That is the key the suite correlates a discovered extension to its
manifest by (`ExtensionHostProvider` in the suite). Use a stable reverse-DNS id and never
change it.

---

## 1. Expose a public root-view factory (keep everything else `internal`)

The `.appex` is a **separate module**, so it can't see your app's `internal` views. Add
one small `public` factory to your library — mirroring how the in-process adapter works,
nothing else becomes public.

Reference: [`Sources/LP700App/LP700Extension.swift`](https://github.com/VU3ESV/LP-700-App/blob/main/Sources/LP700App/LP700Extension.swift)

```swift
import SwiftUI

public enum <PluginName>Extension {           // e.g. LP700Extension
    @MainActor
    public static func rootView(defaults: UserDefaults? = nil) -> AnyView {
        if let defaults { AppDefaults.store = defaults }   // your app's @AppStorage backing
        return AnyView(<RootView>)                          // e.g. ContentView(vm: MeterViewModel())
    }
}
```

Verify the plain build is unaffected: `swift build && swift test`.

---

## 2. Add the ExtensionKit `.appex` target (Xcode, via XcodeGen)

SwiftPM **cannot** build `.appex` bundles, so add a tiny Xcode project. Create three files
under `Xcode/`:

**`Xcode/Extension/<ExtTarget>.swift`** — the extension entry point.
Reference: [`Xcode/Extension/LP700PluginExtension.swift`](https://github.com/VU3ESV/LP-700-App/blob/main/Xcode/Extension/LP700PluginExtension.swift)

```swift
import SwiftUI
import ExtensionFoundation
import ExtensionKit
import <RepoModule>                            // e.g. LP700App

@main
struct <ExtTarget>: AppExtension {
    var configuration: AppExtensionSceneConfiguration {
        AppExtensionSceneConfiguration(
            PrimitiveAppExtensionScene(id: "primary") {
                <PluginName>Extension.rootView()
            }
        )
    }
}
```

**`Xcode/Extension/Info.plist`** — must declare the suite's extension point.
Reference: [`Xcode/Extension/Info.plist`](https://github.com/VU3ESV/LP-700-App/blob/main/Xcode/Extension/Info.plist)

```xml
<key>EXAppExtensionAttributes</key>
<dict>
    <key>EXExtensionPointIdentifier</key>
    <string>org.vu3esv.radiosuite.plugin</string>
</dict>
```

**`Xcode/project.yml`** — XcodeGen spec. Links **only** RadioPluginKit + your own library.
Reference: [`Xcode/project.yml`](https://github.com/VU3ESV/LP-700-App/blob/main/Xcode/project.yml)

```yaml
name: <PluginName>Plugin
options: { bundleIdPrefix: org.vu3esv.radiosuite, deploymentTarget: { macOS: "14.0" } }
packages:
  RadioPluginKit: { url: https://github.com/VU3ESV/RadioPluginKit.git, from: "1.2.0" }
  <RepoModule>:   { path: .. }                 # this repo's SwiftPM package
targets:
  <ExtTarget>:
    type: extensionkit-extension
    platform: macOS
    sources: [ { path: Extension, excludes: [ plugin.json ] } ]
    info:
      path: Extension/Info.plist
      properties:
        EXAppExtensionAttributes: { EXExtensionPointIdentifier: org.vu3esv.radiosuite.plugin }
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: <BundleID>   # MUST equal plugin.json id
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "-"                  # ad-hoc for dev
    dependencies:
      - { package: RadioPluginKit, product: RadioPluginKit }
      - { package: RadioPluginKit, product: RadioPluginUI }
      - { package: <RepoModule>,   product: <RepoModule> }
```

> Keep the generated `.xcodeproj` **gitignored** (your repo's `.gitignore` likely already
> ignores `*.xcodeproj/`); regenerate it with `xcodegen generate`. Commit only `project.yml`
> + `Extension/`.

---

## 3. Write `plugin.json`

`Xcode/Extension/plugin.json` — the manifest the suite reads (without loading code).
Reference: [`Xcode/Extension/plugin.json`](https://github.com/VU3ESV/LP-700-App/blob/main/Xcode/Extension/plugin.json)

```json
{
  "id": "<BundleID>",                 // == the .appex bundle id
  "name": "<PluginName>",
  "version": "1.0.0",
  "sdkVersion": "1.2",
  "minHostVersion": "1.0",
  "isolation": "out-of-process",
  "capabilities": <capabilities>,
  "systemImage": "<SystemImage>",
  "author": "VU3ESV",
  "homepage": "https://github.com/VU3ESV/<your-repo>"
}
```

---

## 4. Package the `.radioplugin`

Add `scripts/make-radioplugin.sh` (generates the project, builds the `.appex`, zips the
package with `plugin.json` at the **archive root**).
Reference: [`scripts/make-radioplugin.sh`](https://github.com/VU3ESV/LP-700-App/blob/main/scripts/make-radioplugin.sh)

```sh
./scripts/make-radioplugin.sh        # -> dist/<pkg> + prints its sha256
```

Key details the script handles (and why):
- **`GIT_CONFIG_COUNT=1 … safe.bareRepository=all`** — lets `xcodebuild`'s SwiftPM resolve
  past a common global `safe.bareRepository=explicit` git setting, without editing config.
- **`ditto -c -k --norsrc --noextattr`** with `plugin.json` at the root — produces a clean
  zip with **no `__MACOSX/` AppleDouble dir** (a second top-level dir would break the
  suite's payload-root detection in `PackageInstaller`).

---

## 5. Add the catalog entry (in the suite repo)

The catalog is hosted from the suite. Commit the built package and add an entry.
Reference: [`docs/catalog/catalog.json`](https://github.com/VU3ESV/AmateurRadioSuite/blob/main/docs/catalog/catalog.json)
+ the committed [`lp700.radioplugin`](https://github.com/VU3ESV/AmateurRadioSuite/blob/main/docs/catalog/).

1. Copy `dist/<pkg>` → `AmateurRadioSuite/docs/catalog/<pkg>`.
2. `shasum -a 256 docs/catalog/<pkg>` → use that digest.
3. Append to `catalog.json`:

```json
{
  "id": "<BundleID>",
  "name": "<PluginName>",
  "latestVersion": "1.0.0",
  "minHostVersion": "1.0",
  "url": "https://raw.githubusercontent.com/VU3ESV/AmateurRadioSuite/main/docs/catalog/<pkg>",
  "sha256": "<digest of the committed file>",
  "systemImage": "<SystemImage>",
  "author": "VU3ESV"
}
```

The suite verifies this `sha256` on install, so the committed file and the digest must
match exactly. (`ditto` zips aren't reproducible — compute the digest from the *committed*
file, not a re-build.)

---

## 6. What works now vs. the signing gate (be honest)

After these steps, for your plugin the suite can: **browse** it (catalog), **install**
it (checksum-verified), **discover** it, and — in the Xcode host build — **host** it via
`EXHostViewController`. The full code path is in place and compiles.

**The remaining gate to a *running* third-party plugin is Apple code-signing:**
- macOS only surfaces an ExtensionKit extension (`AppExtensionIdentity.matching`) once its
  **containing app/extension is registered with the system** — i.e. signed (Developer-ID)
  and approved. A `.appex` merely unzipped into Application Support is **not** auto-registered.
- So shipping a runnable third-party plugin needs a **Developer-ID signing identity** +
  notarization + the runtime extension-approval flow. That is an account/credentials step,
  not code. Ad-hoc signing (what `make-radioplugin.sh` uses) is fine for building and for
  the discovery/catalog flow, but not for loading an untrusted extension.

Until then, an installed out-of-process plugin lists as **discovered** and renders the
"runs out-of-process" placeholder in the plain build; the Xcode host build hosts it once
the extension is registered/approved.

---

## Checklist (per app)

- [ ] Public `rootView()` factory added; `swift build && swift test` still green.
- [ ] `Xcode/Extension/<ExtTarget>.swift`, `Info.plist` (extension point), `project.yml`.
- [ ] `plugin.json` with `id` **==** the `.appex` `PRODUCT_BUNDLE_IDENTIFIER`.
- [ ] `scripts/make-radioplugin.sh` builds the `.appex` and produces `dist/<pkg>`.
- [ ] `.xcodeproj` stays gitignored; commit `project.yml` + `Extension/` + the script + the factory.
- [ ] Suite: committed `docs/catalog/<pkg>` + a `catalog.json` entry whose `sha256` matches.
- [ ] PRs opened (this app repo + the suite catalog).

*Worked reference: [LP-700-App PR](https://github.com/VU3ESV/LP-700-App/pulls) +
[AmateurRadioSuite catalog](https://github.com/VU3ESV/AmateurRadioSuite/tree/main/docs/catalog).*
