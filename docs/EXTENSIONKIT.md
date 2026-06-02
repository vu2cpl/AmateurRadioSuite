# Out-of-process plugins (ExtensionKit) — developer & integration notes

Third-party plugins run **out of process** as sandboxed, crash-isolated ExtensionKit
extensions. A plugin crash stays in the plugin's process; the host keeps running and the
supervisor restarts or quarantines it. This is the decided model for any non-first-party
plugin (see [PLUGIN-PLATFORM.md](../PLUGIN-PLATFORM.md)).

## How it fits together

```
Container (host process)                 Plugin (.appex, separate sandboxed process)
  ExtensionPluginSource ──discovers──▶  EXExtensionPointIdentifier = org.vu3esv.radiosuite.plugin
  EXHostViewController  ──embeds UI──▶  the extension's SwiftUI scene
  PluginSupervisor      ──restart/quarantine on crash
        ▲                                     │
        └──── typed channel (Codable) ────────┘
              HostToExtensionMessage / ExtensionToHostMessage  (RadioPluginKit 1.2)
```

- **Discovery** — the host browses installed extensions declaring our extension point id
  (`RadioExtensionPoint.identifier`) and lists them in *Manage Plugins*, reading each
  `plugin.json` manifest for name/version/capabilities without launching code.
- **Hosting** — `EXHostViewController` connects to the extension process and embeds its UI
  in the plugin's tab.
- **Channel** — host and extension exchange the `RadioPluginKit` Codable messages
  (`activate`/`deactivate`/state, and `report`/`notify`/`setBadge`/`log` back).
- **Crash control** — `PluginSupervisor` (implemented + tested in the host) records crashes;
  it restarts with exponential backoff and, on a crash-loop (N within a window), quarantines
  the plugin ("Try again" clears it). **Safe Mode** disables all non-built-in plugins.

## ⚠️ Build requirement: an Xcode app-extension target

**SwiftPM cannot build `.appex` extension bundles.** Producing a real extension (and the
host's `EXHostViewController` wiring, which needs the matching entitlements/signing) requires
an **Xcode** project with:

- a host **app** target (the suite) with the *Extension Host* capability, and
- one or more **app-extension** targets whose `Info.plist` declares the extension point.

This is done: the [`Xcode/`](../Xcode/) workspace provides the host app + a sample
`DemoSDRExtension.appex` target.

### Building the Xcode workspace

```sh
cd Xcode
xcodegen generate        # only if you changed project.yml; the .xcodeproj is committed
open RadioSuite.xcodeproj
# or headless:
xcodebuild -project RadioSuite.xcodeproj -scheme RadioSuiteHost \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

- `RadioSuiteHost` (app) reuses the package's `Sources/RadioSuite` verbatim (**excluding
  `RadioSuiteApp.swift`** — the Xcode target's `@main` is `Host/HostApp.swift`) and links
  **only `RadioPluginKit`** — no plugin apps. It adds the `Host/` layer:
  `HostApp.swift` (the host `@main`, which installs the out-of-process provider),
  `ExtensionHostView.swift` (`EXHostViewController` hosting + `ExtensionDiscovery`), and
  `ExtensionHosting.swift` (`ExtensionHostProvider` + `ExtensionPluginSource`).
- `DemoSDRExtension` (`.appex`, `type: extensionkit-extension`) is the sample out-of-process
  plugin; the app embeds it under `Contents/Extensions/`.
- The project is **XcodeGen-authored** (`Xcode/project.yml`) but the generated `.xcodeproj` is
  committed — open and edit it in Xcode directly; XcodeGen is only needed to regenerate.

### How the live tab is wired (done)

`Sources/RadioSuite` exposes an `OutOfProcessHosting` **seam** (a provider protocol + the
`bootstrap` hook). The plain SwiftPM build leaves it nil, so `swift build` stays a lean
in-process build with no ExtensionKit. The Xcode `HostApp` fills it: at launch it installs
`ExtensionHostProvider`, which

1. discovers installed extensions via `AppExtensionIdentity.matching(appExtensionPointIDs:)`
   and surfaces each as a `.discovered` `PluginEntry` (through `ExtensionPluginSource`) — no
   `plugin.json` required for embedded/installed `.appex`es;
2. makes such an entry **runnable** (`PluginEntry.isRunnable`) and renders its UI by handing
   the matching `AppExtensionIdentity` to `ExtensionHostView` (`EXHostViewController`).

**Correlation convention:** an out-of-process plugin's `manifest.id` **equals its extension's
bundle identifier**. That is the key the provider hosts by, so a discovered extension and an
on-disk `plugin.json` with the same `id` refer to the same plugin (and de-duplicate).

**Remaining for a *running* demo:** Developer-ID signing + the runtime extension approval flow
(needs an Apple Developer account). The code path — discover → entry → `EXHostViewController`
— is complete and compiles; the project builds and embeds the extension with ad-hoc signing.

## Extension `Info.plist` (required keys)

```xml
<key>EXAppExtensionAttributes</key>
<dict>
    <key>EXExtensionPointIdentifier</key>
    <string>org.vu3esv.radiosuite.plugin</string>
</dict>
```

Ship a `plugin.json` (see [sample-plugin/plugin.json](sample-plugin/plugin.json)) alongside the
extension so the host can show it pre-launch with `isolation: "out-of-process"`.

## Reference skeleton

[extension-template/](extension-template/) contains a starting point: the SwiftUI view, the
`AppExtension` entry, and the `Info.plist`. It is **reference material for an Xcode extension
target** — it is intentionally not part of the SwiftPM build.
