import SwiftUI
import TipKit

/// Der gewählte Auslöser bleibt mittig, während der andere rechts daneben Platz nimmt.
struct CreateCameraControls: View {
    let isAutomaticSelected: Bool
    let isAutomaticActive: Bool
    let sensitivity: FeedSensitivityLevel
    let isDictationSelected: Bool
    let dynamicFactor: Double
    let changeSensitivity: () -> Void
    let toggleDictation: () -> Void
    let isReady: Bool
    let isBusy: Bool
    let takePhoto: () -> Void
    let toggleAutomatic: () -> Void
    var showsDictation = true
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(FeedSensitivityLevel.hintsKey) private var hintsEnabled = true
    @Namespace private var controlPositions
    // Die Auslöser nacheinander erklären; die Hinweise dürfen sich nicht überlagern.
    @State private var controlTips = TipGroup(.ordered) {
        CreateItemCameraTip()
        CreateItemSensitivityTip()
        CreateItemDictationTip()
    }
    private enum Control: String, Identifiable {
        case photo, automatic
        var id: String { rawValue }
    }

    // Beide Auslöser nutzen dieselben kontrastierenden Farben im jeweiligen Erscheinungsbild.
    private var buttonColor: Color { colorScheme == .dark ? .white : .gray }
    private var iconColor: Color { colorScheme == .dark ? .gray : .white }

    var body: some View {
        // Feste Abstände halten die seitlichen Tasten auch auf schmalen Displays
        // an denselben Positionen relativ zum mittigen, aktiven Auslöser.
        let spacing: CGFloat = 8
        let sideDistance: CGFloat = 76
        ZStack {
            if isAutomaticSelected {
                auxiliaryControls(spacing: spacing)
                    .offset(x: -(sideDistance + (showsDictation ? 22 + spacing / 2 : 0)))
            }
            ForEach(isAutomaticSelected ? [Control.automatic, .photo] : [.photo, .automatic]) { control in
                shutterButton(for: control, sideDistance: sideDistance)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .anchorPreference(key: CreateCameraFeedbackBoundsKey.self, value: .bounds) {
            CreateCameraFeedbackBounds(shutter: $0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isAutomaticSelected)
        .onChange(of: dynamicFactor) { old, new in
            guard isAutomaticActive, sensitivity == .automatic, abs(new - old) > 0.000001,
                  !CreateAutomaticSensitivityTip.wasAdjusted else { return }
            CreateAutomaticSensitivityTip.wasAdjusted = true
        }
    }

    private var sensitivityTip: (any Tip)? {
        guard hintsEnabled else { return nil }
        if isAutomaticActive && sensitivity == .automatic {
            return CreateAutomaticSensitivityTip()
        }
        return controlTips.currentTip as? CreateItemSensitivityTip
    }

    private func auxiliaryControls(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            if showsDictation {
                // Diese Hilfen erscheinen nur neben der großen Automatikfläche.
                Button {
                    CreateItemDictationTip().invalidate(reason: .actionPerformed)
                    toggleDictation()
                } label: {
                    Image(systemName: isDictationSelected ? "microphone.fill" : "microphone.slash.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? Color.white : .black)
                        // Gleiche Breite und Höhe halten die Diktat-Taste in beiden Formularen rund.
                        .frame(width: 44, height: 44)
                        .modifier(CreateDictationControlSurface())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isReady || isBusy)
                .accessibilityLabel(Text("CreateItem.Dictation"))
                .accessibilityValue(Text(isDictationSelected ? "CreateItem.Enabled" : "CreateItem.Disabled"))
                .popoverTip(controlTips.currentTip as? CreateItemDictationTip, arrowEdge: .bottom)

            }

            // Die nächste linke Taste hat denselben Mittelpunktabstand wie der passive Auslöser rechts.
            // Die Stufenwahl betrifft zukünftige Vergleiche und bleibt auch beim
            // Fotografieren oder Diktieren bedienbar; nur Auslöser müssen warten.
            CreateSensitivityButton(level: sensitivity, isEnabled: true, dynamicFactor: dynamicFactor) {
                if CreateAutomaticSensitivityTip.wasAdjusted {
                    CreateAutomaticSensitivityTip().invalidate(reason: .actionPerformed)
                }
                CreateItemSensitivityTip().invalidate(reason: .actionPerformed)
                changeSensitivity()
            }
            .popoverTip(sensitivityTip, arrowEdge: .bottom)
            .frame(width: 44)

        }
        .frame(width: showsDictation ? 88 + spacing : 44)
    }

    private func shutterButton(for control: Control, sideDistance: CGFloat) -> some View {
        let large = isAutomaticSelected ? control == .automatic : control == .photo
        return Button {
            if control == .photo {
                CreateItemCameraTip().invalidate(reason: .actionPerformed)
                takePhoto()
            } else {
                toggleAutomatic()
            }
        } label: {
            Circle().fill(buttonColor)
                .overlay {
                    icon(for: control)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: large ? 26 : 18, weight: .medium))
                        .foregroundStyle(control == .automatic && isAutomaticActive ? Color.red : iconColor)
                        .allowsHitTesting(false)
                }
                .padding(large ? 5 : 0)
                .overlay {
                    if large { Circle().stroke(buttonColor, lineWidth: 3).allowsHitTesting(false) }
                }
                .background {
                    if large { Circle().fill(.regularMaterial) }
                }
                .frame(width: large ? 68 : 44, height: large ? 68 : 44)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                // Auch Ring und Abstand zum inneren Kreis gehören zur Tippfläche des Auslösers.
                .contentShape(.interaction, Circle())
        }
        .buttonStyle(.plain)
        // Der Stopp-Auslöser bleibt auch während Fotoaufnahme und Speichern erreichbar.
        .disabled(control == .automatic && isAutomaticActive ? false : (!isReady || isBusy))
        .accessibilityLabel(Text(LocalizedStringKey(control == .photo ? "Foto aufnehmen" : "FeedMonitoring.Toggle")))
        // Echte Layoutplätze halten auch die TipKit-Anker und Tippflächen voneinander getrennt.
        .matchedGeometryEffect(id: control.id, in: controlPositions)
        // Der aktive Auslöser bleibt fest mittig; seitliche Tasten beeinflussen ihn nicht.
        .offset(x: large ? 0 : sideDistance)
    }

    private func icon(for control: Control) -> Image {
        if control == .photo { return Image(systemName: "camera.fill") }
        return Image(systemName: isAutomaticActive ? "stop.fill" : "sparkles.2")
    }
}

/// Die Oberfläche folgt ausdrücklich dem Kreis, auch bei Liquid Glass.
private struct CreateDictationControlSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content.background(.regularMaterial, in: Circle())
        }
    }
}
