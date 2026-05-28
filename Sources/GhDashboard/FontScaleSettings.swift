import SwiftUI

@Observable
@MainActor
final class FontScaleSettings {
    private static let storageKey = "fontScaleStep"
    private static let defaultStep = 3

    private static let scales: [CGFloat] = [
        0.70, 0.80, 0.90, 1.00, 1.10, 1.20, 1.35, 1.50, 1.65, 1.80, 2.00, 2.20,
    ]

    private(set) var step: Int {
        didSet { UserDefaults.standard.set(step, forKey: Self.storageKey) }
    }

    var scale: CGFloat {
        Self.scales[step]
    }

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.storageKey) as? Int
        step = Self.clamp(stored ?? Self.defaultStep)
    }

    func increase() { step = Self.clamp(step + 1) }
    func decrease() { step = Self.clamp(step - 1) }
    func reset() { step = Self.defaultStep }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, 0), scales.count - 1)
    }
}
