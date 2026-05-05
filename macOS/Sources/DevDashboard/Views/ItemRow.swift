import SwiftUI
import Core

struct ItemRow: View {
    let item: DashboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("#\(item.number)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                if item.isDraft {
                    Text("draft")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(.orange)
                }

                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                if let badge = item.reviewBadge {
                    Image(systemName: badge)
                        .foregroundStyle(reviewColor)
                        .help(item.reviewBadgeLabel)
                        .imageScale(.small)
                }
            }

            HStack(spacing: 8) {
                Text(item.repo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !item.labels.isEmpty {
                    Text(item.labels.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text(item.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    private var reviewColor: Color {
        switch item.reviewStatus {
        case "approved": .green
        case "changes_requested": .red
        case "pending": .yellow
        default: .secondary
        }
    }
}
