import SwiftUI

/// Discrete text-size steps mapped to Dynamic Type; persisted across launches.
@Observable
@MainActor
final class FontScaleSettings {
    private static let storageKey = "fontScaleStep"

    /// Slightly above system default — the app’s “normal” size (⌘0).
    private static let defaultStep = 3

    private static let sizes: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
    ]

    private(set) var step: Int {
        didSet {
            let clamped = Self.clamp(step)
            if clamped != step {
                step = clamped
                return
            }
            UserDefaults.standard.set(step, forKey: Self.storageKey)
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        Self.sizes[step]
    }

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.storageKey) as? Int
        step = Self.clamp(stored ?? Self.defaultStep)
    }

    func increase() {
        step += 1
    }

    func decrease() {
        step -= 1
    }

    func reset() {
        step = Self.defaultStep
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, 0), sizes.count - 1)
    }
}
