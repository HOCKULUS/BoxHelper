import SwiftUI

/// Der Fortschrittsbogen liegt innerhalb der Taste mit freier Mitte für das Symbol.
struct CreateSensitivityButton: View {
    let level: FeedSensitivityLevel
    let isEnabled: Bool
    var dynamicFactor: Double = 1
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseColor = Color.red
    @State private var pulseIntensity = 0.0
    @State private var pulseTask: Task<Void, Never>?

    private var fraction: Double {
        // Niedrige Änderungsschwelle = hohe Empfindlichkeit. Logarithmische Skala
        // verteilt auch die empfindlichen Stufen gut sichtbar über den Bogen.
        min(1, max(0.08, log(2.5 / max(0.12, dynamicFactor)) / log(2.5 / 0.12)))
    }

    private var symbol: some View {
        Image(systemName: level == .automatic ? "wand.and.sparkles.inverse" : "cellularbars",
              variableValue: Double(level.rawValue) / 4)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: level == .automatic ? 20 : 24, weight: .medium))
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if level == .automatic {
                    Circle().trim(from: 0, to: fraction)
                        .stroke(Color.primary.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 36, height: 36).rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: fraction)
                }
                ZStack {
                    symbol.foregroundStyle(colorScheme == .dark ? Color.white : .black)
                    // Eine feste Farbe weich überblenden statt zwischen optionalen
                    // Farbwerten umzuschalten. Das kleine Größenschwingen betont den Puls.
                    symbol.foregroundStyle(pulseColor).opacity(pulseIntensity)
                }
                .scaleEffect(1 + pulseIntensity * 0.1)
                .allowsHitTesting(false)
            }
            .frame(width: 44, height: 44)
            .modifier(CreateControlSurface())
            .contentShape(.interaction, Circle())
        }
        .buttonStyle(.plain).disabled(!isEnabled)
        .contentShape(.interaction, Circle())
        .accessibilityLabel("FeedSensitivity.Title")
        .accessibilityValue(Text(LocalizedStringKey(level.titleKey)))
        .onChange(of: dynamicFactor) { old, new in
            guard level == .automatic, abs(new - old) > 0.000001 else { return }
            pulseTask?.cancel()
            pulseIntensity = 0
            pulseColor = new < old ? .red : .blue
            pulseTask = Task { @MainActor in
                do {
                    // Zwei volle Atemzüge mit kontinuierlichem Ein- und Ausschwingen.
                    for _ in 0..<2 {
                        withAnimation(.easeInOut(duration: 0.55)) { pulseIntensity = 1 }
                        try await Task.sleep(for: .milliseconds(550))
                        withAnimation(.easeInOut(duration: 0.55)) { pulseIntensity = 0 }
                        try await Task.sleep(for: .milliseconds(550))
                    }
                } catch { /* Eine neue Stufe beendet die vorherige Rückmeldung. */ }
            }
        }
        .onChange(of: level) { _, _ in pulseTask?.cancel(); pulseIntensity = 0 }
        .onDisappear { pulseTask?.cancel(); pulseIntensity = 0 }
    }
}

struct SensitivityGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.glassEffect(.regular.interactive(), in: Circle()) }
        else { content.background(.regularMaterial, in: Circle()) }
    }
}
