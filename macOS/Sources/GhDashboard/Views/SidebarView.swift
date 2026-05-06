import SwiftUI
import Core

struct SidebarView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        List(DashboardSection.allCases, id: \.self, selection: $viewModel.section) { sec in
            Label {
                HStack {
                    Text(sec.label)
                    Spacer()
                    Text("\(viewModel.sectionCount(sec))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } icon: {
                Image(systemName: sec.systemImage)
            }
            .tag(sec)
        }
        .listStyle(.sidebar)
        .navigationTitle("Dashboard")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                if let configError = viewModel.configError {
                    Label(configError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                }
                ForEach(viewModel.errorsByHost.sorted(by: { $0.key < $1.key }), id: \.key) { host, error in
                    Label("\(host): \(error)", systemImage: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                }
                if let lastFetch = viewModel.lastFetch {
                    Text("Updated \(lastFetch, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
