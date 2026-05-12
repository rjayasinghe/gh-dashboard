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
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if item.isDraft {
                    Text("DRAFT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.orange)
                }

                stateBadge(item)
            }

            Text(item.title)
                .font(.title3)
                .fontWeight(.medium)
                .textSelection(.enabled)

            if let url = URL(string: item.url) {
                Link(item.url, destination: url)
                    .font(.caption)
                    .foregroundStyle(.link)
            }
        }
    }

    @ViewBuilder
    private func stateBadge(_ item: DashboardItem) -> some View {
        let color: Color = item.state.uppercased() == "OPEN" ? .green : .red
        Text(item.stateLabel)
            .font(.caption)
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
            if item.section != .myIssues && item.section != .myDoDIssues && item.section != .issueQueue {
                metadataRow("Draft", item.isDraft ? "Yes" : "No")
                HStack(spacing: 6) {
                    Text("Reviews")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    if let badge = item.reviewBadge {
                        Image(systemName: badge)
                            .foregroundStyle(reviewColor(item))
                    }
                    Text(item.reviewBadgeLabel)
                        .font(.body)
                }
            }
        }
    }

    @ViewBuilder
    private func metadataRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func labelsSection(_ item: DashboardItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Labels")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 4) {
                ForEach(item.labels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
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
                .font(.headline)

            ForEach(item.comments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.author)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                        Spacer()
                        Text(comment.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    markdownText(comment.body)
                        .font(.body)
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
        case "approved": .green
        case "changes_requested": .red
        case "pending": .yellow
        default: .secondary
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }

        return (offsets, CGSize(width: totalWidth, height: y + rowHeight))
    }
}
