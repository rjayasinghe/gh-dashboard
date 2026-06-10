import SwiftUI
import Core

struct ItemListView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        let groups = viewModel.groupedByHost

        if viewModel.configError != nil {
            ContentUnavailableView {
                Label("Configuration Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(viewModel.configError ?? "")
            }
        } else if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groups.isEmpty {
            ContentUnavailableView {
                Label("No Items", systemImage: "tray")
            } description: {
                Text("No \(viewModel.section.label.lowercased()) found.")
            }
        } else {
            List(selection: $viewModel.selectedItemID) {
                ForEach(groups, id: \.host) { group in
                    Section {
                        ForEach(group.items) { item in
                            ItemRow(item: item)
                                .tag(item.id)
                        }
                    } header: {
                        Label(group.host, systemImage: "server.rack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .navigationTitle(viewModel.section.label)
            .onKeyPress("j") { viewModel.selectNext(); return .handled }
            .onKeyPress("k") { viewModel.selectPrevious(); return .handled }
            .onKeyPress("o") { viewModel.openSelectedItem(); return .handled }
        }
    }
}
