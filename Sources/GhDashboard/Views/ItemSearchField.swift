import SwiftUI
import Core

struct ItemSearchField: View {
    @Bindable var viewModel: DashboardViewModel
    @FocusState private var isFocused: Bool

    private var showResults: Bool {
        isFocused && !DashboardItemSearch.parseTerms(from: viewModel.searchQuery).isEmpty
    }

    var body: some View {
        TextField("Search", text: $viewModel.searchQuery)
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
            .focused($isFocused)
            .popover(isPresented: resultsPresented, arrowEdge: .bottom) {
                searchResultsList
            }
            .help("Search issues and pull requests (⌘⇧F)")
            .onChange(of: viewModel.searchFocusRequest) { _, _ in
                isFocused = true
            }
    }

    private var resultsPresented: Binding<Bool> {
        Binding(
            get: { showResults },
            set: { if !$0 { isFocused = false } }
        )
    }

    @ViewBuilder
    private var searchResultsList: some View {
        let results = viewModel.searchResults

        Group {
            if results.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No items match “\(viewModel.searchQuery)”")
                }
                .frame(width: 360, height: 120)
            } else {
                List(results) { item in
                    Button {
                        viewModel.selectSearchResult(item)
                        isFocused = false
                    } label: {
                        SearchResultRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(width: 420, height: min(CGFloat(results.count) * 52 + 8, 320))
            }
        }
    }
}

private struct SearchResultRow: View {
    let item: DashboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Label(item.section.label, systemImage: item.section.systemImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)

                Spacer(minLength: 4)

                Text(item.displayHost)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(item.repo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("#\(item.number)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
