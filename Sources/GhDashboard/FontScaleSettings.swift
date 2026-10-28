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

    var scale: CGFloat { Self.scales[step] }

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

// MARK: - Environment key

private struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

// MARK: - Scaled font helpers

private func pointSize(for style: Font.TextStyle, scale: CGFloat) -> CGFloat {
    let base: CGFloat
    switch style {
    case .largeTitle:  base = 34
    case .title:       base = 28
    case .title2:      base = 22
    case .title3:      base = 20
    case .headline:    base = 17
    case .body:        base = 17
    case .callout:     base = 16
    case .subheadline: base = 15
    case .footnote:    base = 13
    case .caption:     base = 12
    case .caption2:    base = 11
    @unknown default:  base = 17
    }
    return (base * scale).rounded()
}

extension View {
    func scaledFont(_ style: Font.TextStyle) -> some View {
        modifier(ScaledFontModifier(style: style, design: .default))
    }

    func scaledFont(_ style: Font.TextStyle, design: Font.Design) -> some View {
        modifier(ScaledFontModifier(style: style, design: design))
    }
}

private struct ScaledFontModifier: ViewModifier {
    @Environment(\.fontScale) private var scale
    let style: Font.TextStyle
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: pointSize(for: style, scale: scale), design: design))
    }
}
