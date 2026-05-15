import SwiftUI

@main
struct GhDashboardApp: App {
    @State private var viewModel = DashboardViewModel()
    @State private var fontScale = FontScaleSettings()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environment(fontScale)
                .dynamicTypeSize(fontScale.dynamicTypeSize)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .windowSize) {
                Button("Increase Text Size") {
                    fontScale.increase()
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Decrease Text Size") {
                    fontScale.decrease()
                }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                Button("Use Default Text Size") {
                    fontScale.reset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Refresh") { Task { await viewModel.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
