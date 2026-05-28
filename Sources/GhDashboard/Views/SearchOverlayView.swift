import SwiftUI
import Core

struct SearchOverlayView: View {
    @Bindable var viewModel: DashboardViewModel
    @FocusState private var fieldFocused: Bool
    @State private var highlightedIndex: Int? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                searchField

                if !viewModel.searchResults.isEmpty {
                    Divider()
                    resultsList
                }
            }
            .frame(width: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(.top, 80)
        }
        .onAppear { fieldFocused = true }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveHighlight(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveHighlight(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if let idx = highlightedIndex, idx < viewModel.searchResults.count {
                viewModel.selectSearchResult(viewModel.searchResults[idx])
            }
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .imageScale(.medium)

            TextField("Search items…", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldFocused)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    highlightedIndex = viewModel.searchResults.isEmpty ? nil : 0
                }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    highlightedIndex = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { idx, item in
                    SearchResultRow(item: item, isHighlighted: highlightedIndex == idx)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.selectSearchResult(item) }
                        .onHover { inside in
                            if inside { highlightedIndex = idx }
                        }

                    if idx < viewModel.searchResults.count - 1 {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private func dismiss() {
        viewModel.isSearching = false
        viewModel.searchQuery = ""
        highlightedIndex = nil
    }

    private func moveHighlight(by delta: Int) {
        let count = viewModel.searchResults.count
        guard count > 0 else { return }
        let current = highlightedIndex ?? (delta > 0 ? -1 : count)
        highlightedIndex = (current + delta + count) % count
    }
}

private struct SearchResultRow: View {
    let item: DashboardItem
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.section.systemImage)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("#\(item.number)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(item.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                HStack(spacing: 8) {
                    Text(item.repo)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(item.section.label)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}
