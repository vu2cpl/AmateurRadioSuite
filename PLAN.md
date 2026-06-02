# Amateur Radio Suite — Plugin Container Implementation Plan

**Goal:** A single container (host) macOS app that presents the existing radio apps as
plugins in one window, switchable between a **vertical sidebar** and **horizontal tabs**.
Each existing app keeps all its internal code and continues to ship as a standalone `.app`.

**Chosen approach:** Static SwiftPM plugins — the container links each app as a *library*
conforming to a shared `RadioPlugin` protocol and registers it. Type-safe, low-risk.
Adding/removing a plugin edits a registry and recompiles the container.

> **Opening this to third-party developers** (browse + install at runtime, crash
> isolation, styling, error/notification handling) is planned separately in
> [PLUGIN-PLATFORM.md](PLUGIN-PLATFORM.md). This document covers the first-party,
> static base it builds on.

---

## 1. Apps in scope

| App | Repo | Module | macOS | State | Connection |
|---|---|---|---|---|---|
| LP-700 | `../LP-700-App` | `LP700App` | 13→14 | `MeterViewModel` (ObservableObject) | WebSocket + REST |
| LP-100A | `../LP-100A-App` | `LP100AApp` | 13→14 | `MeterViewModel` (ObservableObject) | WebSocket + REST |
| Band Pass Filter | `../BandPassFilterControllerApp` | `BandPassFilterController` | 13→14 | `ControllerViewModel` + `@AppStorage` | HTTP poll + Bonjour |
| SPE Amp (MacExpert) | `../macexpert-spe` | `MacExpert` | 14 | `AmplifierViewModel` (`@Observable`) | Serial (ORSSerialPort) / WebSocket |
| SO2R Box | `../SO2RBoxApp` | `SO2RBoxApp` | 14 | `AppState` (god object) | USB HID + 2 TCP servers |

Two structural facts that drive the design:

1. **Only one `@main App` may own the process.** Each app's `App`/scenes/`AppDelegate`
   must be demoted to a plugin; the container owns process lifecycle.
2. **Type names collide** (`ContentView` ×5; `WSClient`/`ConfigClient`/`MeterViewModel`/
   `AppDelegate` ×2). Keeping each app as its **own Swift module** namespaces them — no renames.

---

## 2. Architecture

```
Container app  (@main, owns the process)
   └─ depends on → RadioPluginKit (shared contract)  ← each plugin also depends on it
   └─ depends on → 5 plugin library products (LP700, LP100A, BPF, SPE, SO2R)

Each repo gains:
   • dependency on RadioPluginKit
   • a thin adapter type conforming to RadioPlugin
   • a .library product (for the container)
   • a thin @main wrapper executable (keeps standalone .app)
```

### Layout of the new workspace (`AmateurRadioSuite/`)

```
AmateurRadioSuite/
  Package.swift                      # container exe + local-path deps on the 6 packages
  Sources/
    RadioSuite/                      # the container app
      RadioSuiteApp.swift            # @main App, single AppDelegate, scenes
      HostShell.swift                # sidebar ⇄ tabs container + toggle
      PluginRegistry.swift           # the static list of plugins
      SettingsHub.swift              # aggregates each plugin's settingsView
      CommandRouter.swift            # routes menu commands to active plugin
  ../RadioPluginKit/                 # NEW shared contract package (sibling repo)
    Package.swift
    Sources/RadioPluginKit/
      RadioPlugin.swift
      PluginHost.swift
      PluginMetadata.swift
      PluginCommand.swift
```

`RadioPluginKit` is its own small package (sibling dir) so all six packages can depend on
it by local path without a cycle.

---

## 3. The contract — `RadioPluginKit`

Pure Swift (no `@objc` needed for static linking). Designed so a future move to dynamic
`.bundle` loading is mechanical (only the loader + target type change, not this API).

```swift
// PluginMetadata.swift
public struct PluginMetadata: Identifiable, Sendable {
    public let id: String           // stable, e.g. "lp700"
    public let title: String        // sidebar/tab label
    public let systemImage: String  // SF Symbol
    public let version: String
    public init(id: String, title: String, systemImage: String, version: String) { … }
}

// PluginCommand.swift  — a menu item the container surfaces, routed to the active plugin
public struct PluginCommand: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let shortcut: KeyboardShortcut?
    public let action: @MainActor () -> Void
}

// PluginHost.swift — services the container injects INTO each plugin
@MainActor public protocol PluginHost: AnyObject {
    func log(_ message: String, plugin: String)
    func defaults(for pluginID: String) -> UserDefaults   // namespaced prefs
    // future: shared event bus (broadcast active band / TX state between plugins)
}

// RadioPlugin.swift
@MainActor public protocol RadioPlugin {
    static var metadata: PluginMetadata { get }
    init(host: PluginHost)
    func makeRootView() -> AnyView
    func activate()                 // tab selected / plugin should connect-or-resume
    func deactivate()               // tab hidden  / plugin should pause (NOT for SO2R servers)
    var menuCommands: [PluginCommand] { get }
    var settingsView: AnyView? { get }
}

public extension RadioPlugin {      // sensible defaults so simple plugins stay short
    func activate() {}
    func deactivate() {}
    var menuCommands: [PluginCommand] { [] }
    var settingsView: AnyView? { nil }
}
```

**Lifecycle contract (important):**
- `activate()` — called when the plugin's tab becomes visible.
- `deactivate()` — called when the tab is hidden. Default policy: **keep connections live**;
  use `deactivate()` only for genuinely tab-bound UI cost (e.g. pause a high-rate animation).
- **Background-critical plugins (SO2R)** start their servers/HID at *plugin construction /
  app launch*, NOT in `activate()`, and stop only at app quit. Tab visibility never tears
  down a logger's CW/OTRSP connection.

---

## 4. Container app

### 4.1 `Package.swift` (container)

```swift
// swift-tools-version:5.9
let package = Package(
  name: "RadioSuite",
  platforms: [.macOS(.v14)],                       // unified target
  products: [ .executable(name: "RadioSuite", targets: ["RadioSuite"]) ],
  dependencies: [
    .package(path: "../RadioPluginKit"),
    .package(path: "../LP-700-App"),
    .package(path: "../LP-100A-App"),
    .package(path: "../BandPassFilterControllerApp"),
    .package(path: "../macexpert-spe"),
    .package(path: "../SO2RBoxApp"),
  ],
  targets: [
    .executableTarget(name: "RadioSuite", dependencies: [
      .product(name: "RadioPluginKit", package: "RadioPluginKit"),
      .product(name: "LP700Plugin",  package: "LP-700-App"),
      .product(name: "LP100APlugin", package: "LP-100A-App"),
      .product(name: "BPFPlugin",    package: "BandPassFilterControllerApp"),
      .product(name: "SPEPlugin",    package: "macexpert-spe"),
      .product(name: "SO2RPlugin",   package: "SO2RBoxApp"),
    ]),
  ]
)
```

### 4.2 `PluginRegistry.swift`

The single edit point for adding/removing a plugin (static model):

```swift
@MainActor enum PluginRegistry {
    static func all(host: PluginHost) -> [RadioPlugin] {
        [ LP700Plugin(host: host),
          LP100APlugin(host: host),
          BPFPlugin(host: host),
          SPEPlugin(host: host),
          SO2RPlugin(host: host) ]
    }
}
```

### 4.3 `HostShell.swift` — sidebar ⇄ tabs toggle

```swift
struct HostShell: View {
    let plugins: [RadioPlugin]
    @State private var selection: String          // plugin id
    @AppStorage("suite.layout") private var layout = Layout.sidebar
    enum Layout: String { case sidebar, tabs }

    var body: some View {
        switch layout {
        case .sidebar:
            NavigationSplitView {
                List(plugins, id: \.metadata.id, selection: $selection) { p in
                    Label(p.metadata.title, systemImage: p.metadata.systemImage).tag(p.metadata.id)
                }
            } detail: { pluginView(for: selection) }
        case .tabs:
            TabView(selection: $selection) {
                ForEach(plugins, id: \.metadata.id) { p in
                    p.makeRootView()
                        .tabItem { Label(p.metadata.title, systemImage: p.metadata.systemImage) }
                        .tag(p.metadata.id)
                }
            }
        }
    }
}
```

- Each plugin's view is built **once** and cached (so switching tabs doesn't recreate the
  viewmodel / drop the connection). Drive `activate()`/`deactivate()` off `selection` changes.
- The Layout toggle is exposed in a **View** menu command (`⌘⌥S` to switch).

### 4.4 Other container responsibilities
- **Single `AppDelegate`** — merges the LP apps' `applicationShouldTerminateAfterLastWindowClosed`,
  `applicationShouldHandleReopen`, and wake/reconnect observers into one.
- **`SettingsHub`** — a `Settings` scene with a `TabView` collecting every plugin's `settingsView`.
- **`CommandRouter`** — builds `.commands { … }` from the active plugin's `menuCommands`,
  so LP-700's ⌘K / peak-mode shortcuts act on the visible meter.
- **About panel** — move SO2R's AppKit `NSApp.orderFrontStandardAboutPanel` here (one for the suite).
- **MenuBarExtra** — optional, container-owned, reflecting the active plugin. Per-app
  `MenuBarExtra`s are removed.

---

## 5. Per-app changes (identical shape)

For **every** app — additive, no internal rewrite:

1. Add `.package(path: "../RadioPluginKit")` dependency.
2. Add adapter file `XPlugin.swift` conforming to `RadioPlugin` (public).
3. Demote the `@main App`: move scene `.task`/`.onAppear` startup → `activate()`;
   teardown → `deactivate()` (or app-launch/quit for background-critical). Remove the
   app's `Settings`/`MenuBarExtra`/`Commands`/`AppDelegate` from the plugin path.
4. Add a `.library` product exposing the plugin module.
5. Keep standalone: a thin `@main` wrapper that renders `XPlugin(host:).makeRootView()`.
6. Bump platform to `.macOS(.v14)` where needed.

### Example — LP-700 `Package.swift` after

```swift
platforms: [.macOS(.v14)],
products: [
  .executable(name: "LP-700-App", targets: ["LP700AppMain"]),   // standalone, unchanged behavior
  .library(name: "LP700Plugin",  targets: ["LP700Plugin"]),     // for the container
],
dependencies: [ .package(path: "../RadioPluginKit") ],
targets: [
  .target(name: "LP700App", …),                                  // existing internal code (unchanged)
  .target(name: "LP700Plugin", dependencies: ["LP700App",
            .product(name: "RadioPluginKit", package: "RadioPluginKit")]),
  .executableTarget(name: "LP700AppMain", dependencies: ["LP700Plugin"]),
  .testTarget(name: "LP700AppTests", dependencies: ["LP700App"]),
]
```

### Example — LP-700 adapter (`LP700Plugin.swift`)

```swift
import SwiftUI, RadioPluginKit, LP700App   // ContentView/MeterViewModel are internal to LP700App;
                                           // expose them via `public` or build the adapter inside LP700App

public struct LP700Plugin: RadioPlugin {
    public static let metadata = PluginMetadata(id: "lp700", title: "LP-700",
                                                systemImage: "gauge", version: "…")
    @MainActor let vm: MeterViewModel
    public init(host: PluginHost) { vm = MeterViewModel(defaults: host.defaults(for: "lp700")) }
    public func makeRootView() -> AnyView { AnyView(ContentView(vm: vm)) }
    public func activate()   { vm.bootstrap() }     // was WindowGroup .task
    public func deactivate() {}                     // keep connection live
    public var menuCommands: [PluginCommand] { /* ⌘K connect, peak modes, range … */ [] }
}
```

> Note: to reference `ContentView`/`MeterViewModel` from a separate plugin target they must be
> `public`. Cleaner alternative: put the adapter **inside** the `LP700App` target so they stay
> `internal`, and make only `LP700Plugin` public. Recommended.

### Standalone wrapper (`main.swift` / `App.swift` in `LP700AppMain`)

```swift
@main struct LP700Standalone: App {
    @State private var plugin = LP700Plugin(host: StandaloneHost())
    var body: some Scene { WindowGroup("LP-700") { plugin.makeRootView() } }
}
```
`StandaloneHost` is a trivial `PluginHost` (logs to console, returns `.standard` defaults).

### Per-app specifics & effort

| App | Effort | Notes |
|---|---|---|
| **LP-700** | Low | Move `Commands` → `menuCommands`; drop `MenuBarExtra`; wake observers → root `.onAppear`. |
| **LP-100A** | Low | Same as LP-700; it uses singleton `Window` + `applicationShouldHandleReopen` — both become container concerns. |
| **BPF** | Low | Namespace `@AppStorage` keys via `host.defaults(for:"bpf")`. Sidebar-in-tab is fine. |
| **SPE Amp** | Low–Med | `@Observable` is fine. Verify `ExpertIcon.icns` loads via the plugin's `Bundle.module`, not main bundle. ORSSerialPort rides along. Code lives in `MacExpert/` (not `Sources/`) — confirm target `path:`. |
| **SO2R** | Med–High | TCP servers (17701/17702) + USB HID start at **load**, stop at **quit** — NOT in `activate/deactivate`. Move AppKit About panel to container. Fix `DispatchQueue.main.sync`-from-network-queue hazard (now shares the main thread with 4 other UIs). |

---

## 6. Cross-cutting / packaging

- **Deployment target:** unify on **macOS 14**. LP-700/LP-100A/BPF bump from 13; BPF can drop
  its macOS-13 `@MainActor`-avoidance workarounds.
- **Entitlements:** the container ships the **union** — USB/HID (SO2R, SPE serial), serial port,
  network client, **incoming TCP listener** (SO2R servers), and Bonjour (BPF). Almost certainly
  **Developer-ID, unsandboxed** (as the standalone apps likely already are).
- **One `Info.plist`** for the suite bundle; `NSPrincipalClass` not needed in the static model.
- **Signing:** single hardened-runtime signature over the merged binary. No
  `disable-library-validation` needed (static linking, unlike the dynamic-bundle path).
- **Resources:** each plugin keeps its own `Bundle.module`; no resource-name collisions across modules.

---

## 7. Sequencing

1. **`RadioPluginKit`** — author the contract package. (½ day)
2. **Container shell** — `RadioSuiteApp` + `HostShell` (sidebar/tabs toggle) + `PluginRegistry`
   with a dummy plugin to prove the host. (½ day)
3. **LP-700 + LP-100A** — first real plugins; proves contract + module namespacing end-to-end. (1 day)
4. **BPF** — `@AppStorage` namespacing + sidebar-in-tab. (½ day)
5. **SPE Amp** — external dep + resource bundle through a plugin. (½–1 day)
6. **SO2R** — background-critical lifecycle, AppKit About move, concurrency fix. (1–2 days)
7. **Unify** — Settings hub, command routing, About, Info.plist/entitlements, signing, packaging. (1 day)

## 8. Risks & mitigations
- **SO2R servers/lifecycle** — biggest risk; bind to app lifetime not tab visibility (designed above).
- **Entitlement union / signing** — broad permissions; validate with a hardened-runtime test build early.
- **`public` access creep** — keep adapters inside each app target so internals stay `internal`.
- **Shared main thread** — SO2R's `main.sync` hazard must be fixed before integration.
- **Future dynamic loading** — contract is already shaped so switching to `.bundle` loading later
  only changes the loader and target type, not `RadioPlugin`.
