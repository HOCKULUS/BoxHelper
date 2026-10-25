import SwiftUI

/// Alle drei Fragen teilen ein Layout mit unverdeckten Tippflächen und einem
/// eigenen Platz für die Ortszeile. Zusätzlicher Text verschiebt keine anderen Elemente.
struct CreateAutomaticDictationFeedback<Locations: View>: View {
    let transcript: String
    let audioLevel: Double
    let skip: () -> Void
    let question: LocalizedStringKey
    // Die Standortauswahl bleibt nach Aufnahmeende ohne aktives Mikrofonsignal sichtbar.
    var isListening = true
    @ViewBuilder let locations: (CGFloat, Float) -> Locations
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.createDictationAvailableRect) private var availableRect
    @Environment(\.createCameraShutterFrame) private var shutterFrame
    @State private var startedAt = Date()

    private var hasTranscript: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            let fallback = CGRect(x: 0, y: geometry.safeAreaInsets.top, width: geometry.size.width,
                                  height: max(0, geometry.size.height - geometry.safeAreaInsets.top
                                              - geometry.safeAreaInsets.bottom))
            let available = availableRect ?? fallback
            let layout = CreateDictationFeedbackLayout(size: available.size,
                                                       skipCenterY: shutterFrame.map { $0.midY - available.minY })
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                let phase = reduceMotion ? Float(0) : Float(timeline.date.timeIntervalSince(startedAt) * 3)
                ZStack(alignment: .topLeading) {
                    // Die Ortszeile bleibt über dem festen Skip-Button. Ein niedriger
                    // Bildschirm scrollt diesen Inhalt, statt ihn seitlich umzubrechen.
                    ScrollView(.vertical) {
                        feedback(layout: layout, phase: phase)
                            .frame(width: available.width, height: layout.contentHeight)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                    .defaultScrollAnchor(.bottom)
                    .frame(width: available.width, height: layout.viewportHeight)

                    skipButton
                        .position(x: layout.skipFrame.midX, y: layout.skipFrame.midY)
                }
                .frame(width: available.width, height: available.height)
                .position(x: available.midX, y: available.midY)
            }
        }
    }

    private func feedback(layout: CreateDictationFeedbackLayout, phase: Float) -> some View {
        ZStack(alignment: .topLeading) {
            if isListening {
                ZStack {
                    DictationIntelligenceGlow(phase: phase, audioLevel: audioLevel)
                    Image(systemName: "microphone.fill")
                        // Das Verhältnis der ursprünglichen 280-Punkte-Leuchtfläche
                        // zum 92-Punkte-Symbol bleibt bei jeder Fenstergröße gleich.
                        .font(.system(size: layout.microphoneFrame.width * (92.0 / 280.0), weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 8)
                }
                .frame(width: layout.microphoneFrame.width, height: layout.microphoneFrame.height)
                .position(x: layout.microphoneFrame.midX, y: layout.microphoneFrame.midY)
                .allowsHitTesting(false)
                .accessibilityLabel(Text("CreateItem.Dictation"))
            }

            transcriptLabel(layout: layout)
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                .overlay {
                    DictationTranscriptGradient(phase: phase)
                        .opacity(0.85)
                        .mask { transcriptLabel(layout: layout) }
                        .accessibilityHidden(true)
                }
                .position(x: layout.transcriptFrame.midX, y: layout.transcriptFrame.midY)
                .allowsHitTesting(false)

            Text(question)
                .font(.system(size: 22 * layout.textScale, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(width: min(440, layout.transcriptFrame.width),
                       height: hasTranscript ? 24 * layout.textScale : layout.transcriptFrame.height)
                // Frage und Diktat bleiben innerhalb ihres reservierten Textbereichs.
                .scaleEffect(hasTranscript ? 0.72 : 1)
                .foregroundStyle(hasTranscript ? Color.secondary : Color.primary)
                .position(x: layout.transcriptFrame.midX,
                          y: hasTranscript ? layout.transcriptFrame.midY - layout.questionRise
                                           : layout.questionFrame.midY)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: hasTranscript)
                .allowsHitTesting(false)

            // Zusätzliche Inhalte erhalten die gemeinsame Phase, falls sie animiert sind.
            locations(layout.locationFrame.width, phase)
                .frame(width: layout.locationFrame.width, height: layout.locationFrame.height)
                .position(x: layout.locationFrame.midX, y: layout.locationFrame.midY)
        }
    }

    private func transcriptLabel(layout: CreateDictationFeedbackLayout) -> some View {
        Text(transcript.replacingOccurrences(of: "\n", with: " "))
            .font(.system(size: 22 * layout.textScale, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .truncationMode(.tail)
            .frame(width: min(440, layout.transcriptFrame.width), height: layout.transcriptFrame.height)
    }

    private var skipButton: some View {
        Button(action: skip) {
            Image(systemName: "chevron.forward.dotted.chevron.forward")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: CreateDictationFeedbackLayout.skipSize, height: CreateDictationFeedbackLayout.skipSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(DictationSkipButtonSurface())
        .accessibilityLabel(Text("CreateItem.SkipDictation"))
    }
}

extension CreateAutomaticDictationFeedback where Locations == EmptyView {
    init(transcript: String, audioLevel: Double, skip: @escaping () -> Void, question: LocalizedStringKey) {
        self.transcript = transcript
        self.audioLevel = audioLevel
        self.skip = skip
        self.question = question
        locations = { _, _ in EmptyView() }
    }
}

/// Der Farbeffekt liegt 15° schräg zur Horizontalen innerhalb der Textmaske.
private struct DictationTranscriptGradient: View {
    let phase: Float

    var body: some View {
        GeometryReader { geometry in
            let angle = Angle.degrees(15)
            let cosine = CGFloat(cos(angle.radians))
            let sine = CGFloat(sin(angle.radians))
            let size = geometry.size

            // Die gedrehte Fläche vergrößern, damit alle Buchstaben bis zum Rand
            // Farbe erhalten und keine transparenten Ecken entstehen.
            MeshGradientView(maskTimer: .constant(phase), gradientSpeed: .constant(0.03))
                .frame(width: size.width * cosine + size.height * sine,
                       height: size.width * sine + size.height * cosine)
                .rotationEffect(angle)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }
}

private struct DictationSkipButtonSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}
