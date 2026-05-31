import SwiftUI
import RadioPluginKit

/// The container window: hosts plugins either as a vertical sidebar or as
/// horizontal tabs, switchable from the View menu (⌘⌥S).
struct HostShell: View {
    @ObservedObject var model: SuiteModel
    @AppStorage("suite.layout") private var layout = Layout.sidebar

    enum Layout: String { case sidebar, tabs }

    var body: some View {
        content
            .onAppear { model.activateInitial() }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        layout = (layout == .sidebar) ? .tabs : .sidebar
                    } label: {
                        Image(systemName: layout == .sidebar ? "rectangle.topthird.inset.filled"
                                                              : "sidebar.left")
                    }
                    .help("Switch between sidebar and tabs")
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch layout {
        case .sidebar: sidebar
        case .tabs:    tabs
        }
    }

    private var sidebar: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                ForEach(model.entries) { e in
                    Label(e.title, systemImage: e.systemImage)
                        .tag(e.id)
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 200)
        } detail: {
            model.view(for: model.selection)
                .frame(minWidth: 600, minHeight: 480)
        }
    }

    private var tabs: some View {
        TabView(selection: tabSelection) {
            ForEach(model.entries) { e in
                model.view(for: e.id)
                    .tabItem { Label(e.title, systemImage: e.systemImage) }
                    .tag(e.id)
            }
        }
    }

    // Bindings that route selection changes through the model so activate/
    // deactivate fire. Sidebar selection is optional (List requirement).
    private var sidebarSelection: Binding<String?> {
        Binding(get: { model.selection },
                set: { if let id = $0 { model.select(id) } })
    }

    private var tabSelection: Binding<String> {
        Binding(get: { model.selection },
                set: { model.select($0) })
    }
}
