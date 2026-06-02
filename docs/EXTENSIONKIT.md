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

The contract and the host-side crash-control logic already live in this SwiftPM repo
(`RadioPluginKit` 1.2 + `PluginSupervisor`); the remaining `EXHostViewController` hosting and
the sample `.appex` land once the build gains an Xcode extension target. Two paths:

1. **Add an Xcode workspace** alongside the package (app + extension targets) — keeps the
   SwiftPM packages as libraries the Xcode targets consume.
2. **Generate it** (e.g. XcodeGen/Tuist) so the project file stays declarative.

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
