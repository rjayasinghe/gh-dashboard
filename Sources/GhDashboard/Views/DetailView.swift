import SwiftUI
import Core

struct DetailView: View {
    let item: DashboardItem?

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(item)
                    Divider()
                    metadata(item)
                    if !item.labels.isEmpty {
                        labelsSection(item)
                    }
                    if !item.body.isEmpty {
                        Divider()
                        bodySection(item)
                    }
                    if !item.comments.isEmpty {
                        Divider()
                        commentsSection(item)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView {
                Label("No Selection", systemImage: "sidebar.right")
            } description: {
                Text("Select an item to view details.")
            }
        }
    }

    @ViewBuilder
    private func header(_ item: DashboardItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("#\(item.number)")
                    .scaledFont(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if item.isDraft {
                    Text("DRAFT")
                        .scaledFont(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.orange)
                }

                stateBadge(item)
            }

            Text(item.title)
                .scaledFont(.title3)
                .fontWeight(.medium)
                .textSelection(.enabled)

            if let url = URL(string: item.url) {
                Link(item.url, destination: url)
                    .scaledFont(.caption)
                    .foregroundStyle(.link)
            }
        }
    }

    @ViewBuilder
    private func stateBadge(_ item: DashboardItem) -> some View {
        let color: Color = item.state == .open ? .green : .red
        Text(item.stateLabel)
            .scaledFont(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }

    @ViewBuilder
    private func metadata(_ item: DashboardItem) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            metadataRow("Repo", item.repo)
            metadataRow("Host", item.displayHost)
            metadataRow("Author", item.author)
            metadataRow("Opened", item.createdAt.formatted(.relative(presentation: .named)))
            metadataRow("Updated", item.updatedAt.formatted(.relative(presentation: .named)))
            if item.section.isPRSection {
                metadataRow("Draft", item.isDraft ? "Yes" : "No")
                HStack(spacing: 6) {
                    Text("Reviews")
                        .scaledFont(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    if let badge = item.reviewBadge {
                        Image(systemName: badge)
                            .foregroundStyle(reviewColor(item))
                    }
                    Text(item.reviewBadgeLabel)
                        .scaledFont(.body)
                }
            }
        }
    }

    @ViewBuilder
    private func metadataRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .scaledFont(.body)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func labelsSection(_ item: DashboardItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Labels")
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 4) {
                ForEach(item.labels, id: \.self) { label in
                    Text(label)
                        .scaledFont(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    @ViewBuilder
    private func bodySection(_ item: DashboardItem) -> some View {
        markdownText(item.body)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func commentsSection(_ item: DashboardItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments (\(item.comments.count))")
                .scaledFont(.headline)

            ForEach(item.comments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.author)
                            .scaledFont(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                        Spacer()
                        Text(comment.createdAt, style: .relative)
                            .scaledFont(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    markdownText(comment.body)
                        .scaledFont(.body)
                        .textSelection(.enabled)
                }
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    @ViewBuilder
    private func markdownText(_ string: String) -> some View {
        let attributed = (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(string)
        Text(attributed)
            .textSelection(.enabled)
    }

    private func reviewColor(_ item: DashboardItem) -> Color {
        switch item.reviewStatus {
        case .approved: .green
        case .changesRequested: .red
        case .pending: .yellow
        case nil: .secondary
        }
    }
}
