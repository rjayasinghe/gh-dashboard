import SwiftUI

@main
struct GhDashboardApp: App {
    @State private var viewModel = DashboardViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh") { Task { await viewModel.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
