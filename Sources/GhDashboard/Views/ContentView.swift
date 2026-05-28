import SwiftUI
import Core

struct ContentView: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(viewModel: viewModel)
            } content: {
                ItemListView(viewModel: viewModel)
            } detail: {
                DetailView(item: viewModel.selectedItem)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(viewModel.isLoading)
                    .help("Refresh all hosts (⌘R)")

                    Button {
                        viewModel.isSearching = true
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    .help("Search items (⌘F)")

                    if let item = viewModel.selectedItem, let url = URL(string: item.url) {
                        Link(destination: url) {
                            Label("Open in Browser", systemImage: "safari")
                        }
                        .help("Open in browser")
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                viewModel.setRefreshPaused(phase != .active)
            }
            .task {
                await viewModel.startPeriodicRefresh()
            }

            if viewModel.isSearching {
                SearchOverlayView(viewModel: viewModel)
            }
        }
    }
}
