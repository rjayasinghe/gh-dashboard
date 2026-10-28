import SwiftUI

@MainActor
private final class AppState: ObservableObject {
    let viewModel = DashboardViewModel()
    let fontScale = FontScaleSettings()
}

@main
struct GhDashboardApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: appState.viewModel)
                .environment(appState.fontScale)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .windowSize) {
                Button("Increase Text Size") { appState.fontScale.increase() }
                .keyboardShortcut("=", modifiers: .command)

                Button("Decrease Text Size") { appState.fontScale.decrease() }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                Button("Use Default Text Size") {
                    appState.fontScale.reset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Refresh") { Task { await appState.viewModel.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
