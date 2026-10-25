import Foundation
import CoreGraphics

struct FeedMonitoringEvent: Equatable, Sendable {
    let sessionID: UUID
    let id = UUID()
}

enum FeedDetectionUpdate: Equatable, Sendable {
    case referenceReady, referenceRestarted, referenceUnstable, countdown(Int), cancelled, capture
}

struct FeedMonitoringStatusEvent: Equatable, Sendable {
    let sessionID: UUID
    let update: FeedDetectionUpdate
    let id = UUID()
}

/// Monotone Zeit und kleine Kopien statt gehaltener Kamera-Puffer begrenzen Aufwand und Speicher.
struct FeedMonitoringConfiguration: Sendable, Codable {
    static let regularInterval = 1.0
    static let intervalKey = "feedMonitoringInterval"
    static let thresholdKey = "feedMonitoringThreshold"
    static let inactivityKey = "feedMonitoringInactivity"
    static let cooldownKey = "feedMonitoringCooldown"
    static let stabilityThresholdKey = "feedMonitoringStabilityThreshold"
    static let stabilityIntervalKey = "feedMonitoringStabilityInterval"
    static let imageReferenceKey = "feedMonitoringImageReference"
    static let objectnessKey = "feedMonitoringObjectness"
    let interval: Double
    let threshold: Double
    let inactivity: Double
    let cooldown: Double
    let stabilityThreshold: Double
    let stabilityInterval: Double
    let usesImageReference: Bool
    let usesObjectness: Bool
    var adaptationSpeed: Int = 1
    var usesDictation: Bool = false
    var compensatesExposure: Bool { true }

    init(interval: Double = 1, threshold: Double = 0.08, inactivity: Double = 300, cooldown: Double = 4,
         stabilityThreshold: Double = 0.025, stabilityInterval: Double = 0.2,
         usesImageReference: Bool = true, usesObjectness: Bool = false) {
        // Der reguläre Vergleich läuft fest jede Sekunde; Referenz und Countdown
        // behalten ihre schnelleren Messungen für die zwingende Ruheprüfung.
        self.interval = Self.regularInterval
        self.threshold = Self.clamp(threshold, to: 0.002...0.5, fallback: 0.08)
        self.inactivity = Self.clamp(inactivity, to: 30...1800, fallback: 300)
        self.cooldown = Self.clamp(cooldown, to: 1...120, fallback: 4)
        self.stabilityThreshold = Self.clamp(stabilityThreshold, to: 0.001...0.2, fallback: 0.025)
        self.stabilityInterval = Self.clamp(stabilityInterval, to: 0.1...1, fallback: 0.2)
        self.usesImageReference = usesImageReference
        self.usesObjectness = usesObjectness
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        var result = Self(interval: Self.regularInterval,
             threshold: defaults.object(forKey: thresholdKey) as? Double ?? 0.08,
             inactivity: defaults.object(forKey: inactivityKey) as? Double ?? 300,
             cooldown: defaults.object(forKey: cooldownKey) as? Double ?? 4,
             stabilityThreshold: defaults.object(forKey: stabilityThresholdKey) as? Double ?? 0.025,
             stabilityInterval: defaults.object(forKey: stabilityIntervalKey) as? Double ?? 0.2,
             usesImageReference: true, usesObjectness: true)
        result.adaptationSpeed = defaults.object(forKey: "feedAdaptationSpeed") as? Int ?? 1
        result.usesDictation = defaults.object(forKey: "itemVoiceNamingEnabled") as? Bool ?? true
        return result
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}

struct FeedChangeDetector: Sendable {
    private(set) var configuration: FeedMonitoringConfiguration
    private(set) var diagnostics = FeedDiagnosticsSnapshot()
    // Der Grund entsteht direkt im Entscheidungszweig, statt nachträglich aus
    // dem UI-Zustand geraten zu werden. Zeiten beziehen sich auf diesen Vergleich.
    private(set) var lastDecision = "Noch kein Vergleich"
    private(set) var comparedCountdownSeconds: Double?
    private(set) var comparedCooldownRemaining = 0.0
    private(set) var comparedReturnedToBackground = false
    private(set) var comparedWaitingForStability = false
    private var previous: [UInt8]?
    private var background: [UInt8]?
    private var reference = FeedBackgroundReference()
    var allowsReferenceAdjustment: Bool
    private var candidate: [UInt8]?
    private var lastCountdown: Int?
    private var lastCaptured: [UInt8]?
    private var pendingCapture: [UInt8]?
    private var returnedToBackground = false
    private var waitingForStableFrame = false
    private var awaitingCapture = false
    private var lastSample: Double?
    private var lastActivity: Double
    private var lastCapture: Double?
    private var noiseFloor = 0.0
    private var pendingNoiseFloor = 0.0
    private var candidateFrames: [[UInt8]] = []
    private var candidateStableSince: Double?
    private var candidateLastStableFrame: [UInt8]?
    private var candidateLastStableTime: Double?
    private var unstableComparisons = 0
    private var emptyComparisons = 0
    private var objectTracker = FeedObjectTracker()
    private(set) var objectRegions: [CGRect] = []
    private var backgroundRegions: [CGRect] = []
    private var savedRegions: [CGRect]?
    private var pendingRegions: [CGRect] = []
    private var initialFrames: [[UInt8]] = []
    private var evaluatedBackgroundScore = 0.0
    private var evaluatedSavedScore: Double?
    private var imageBackgroundDifference = 0.0
    private var imageSavedDifference: Double?
    private var evaluatedObjectThreshold = 0.18
    private var evaluatedImageThreshold = 0.08
    private var objectPreviousDifference = 0.0
    private var objectBackgroundDifference = 0.0
    private var objectSavedDifference: Double?
    private var preparation = FeedCountdownPreparation()
    private var feedbackPausedUntil = 0.0
    private var consecutiveAborts = 0
    private(set) var repeatedAbortRevision = 0
    private var automaticThresholds: FeedAutomaticThresholds?
    var automaticAdjustmentRevision: Int { automaticThresholds?.revision ?? 0 }

    // Die Sicherheitsmarge kommt aus tatsächlich gemessenen ruhigen Frames.
    // Die Bewegungsgrenze hängt weiterhin nicht von der Sensitivitätsstufe ab.
    private var changeThreshold: Double {
        max(configuration.threshold * (automaticThresholds?.changeFactor ?? 1), noiseFloor * 2.5 + 0.006)
    }
    private var baseStabilityThreshold: Double {
        max(configuration.stabilityThreshold * (automaticThresholds?.stabilityFactor ?? 1), noiseFloor * 1.75 + 0.003)
    }
    private var stabilityThreshold: Double {
        baseStabilityThreshold * 1.25
    }
    // Vor dem sichtbaren Countdown genügen weichere Grenzen; die Aufnahme
    // selbst muss weiterhin die unveränderte, strengere Ruheprüfung bestehen.
    private var preparationThreshold: Double { stabilityThreshold * 3 }
    private var maximumStableSampleGap: Double { max(0.5, configuration.stabilityInterval * 2.5) }

    init(configuration: FeedMonitoringConfiguration, now: Double, allowsReferenceAdjustment: Bool = true,
         automaticallyAdjustThresholds: Bool = false) {
        self.configuration = configuration
        self.allowsReferenceAdjustment = allowsReferenceAdjustment
        lastActivity = now
        automaticThresholds = automaticallyAdjustThresholds ? FeedAutomaticThresholds() : nil
    }

    func needsSample(at now: Double) -> Bool {
        guard !awaitingCapture, now >= feedbackPausedUntil else { return false }
        let interval = background == nil ? configuration.stabilityInterval
            : (candidate != nil || waitingForStableFrame || emptyComparisons == 1
                ? configuration.stabilityInterval : configuration.interval)
        return lastSample.map { now - $0 + 0.000001 >= interval } ?? true
    }

    func hasTimedOut(at now: Double) -> Bool { now - lastActivity >= configuration.inactivity }

    /// Vergleichsbilder und Countdown beibehalten, wenn die Sitzung ihre Toleranz anpasst.
    mutating func updateConfiguration(_ configuration: FeedMonitoringConfiguration,
                                      automaticallyAdjustThresholds: Bool? = nil) {
        let sourceChanged = self.configuration.usesImageReference != configuration.usesImageReference
            || self.configuration.usesObjectness != configuration.usesObjectness
        self.configuration = configuration
        // Helligkeitsbilder und Saliency-Karten dürfen niemals gegeneinander verglichen werden.
        if sourceChanged { resetComparison() }
        if let enabled = automaticallyAdjustThresholds {
            if enabled {
                if automaticThresholds == nil { automaticThresholds = FeedAutomaticThresholds() }
            } else { automaticThresholds = nil }
        }
    }

    mutating func resetComparison() {
        diagnostics = FeedDiagnosticsSnapshot()
        previous = nil
        background = nil
        reference = FeedBackgroundReference()
        candidate = nil
        lastCountdown = nil
        lastCaptured = nil
        pendingCapture = nil
        returnedToBackground = false
        waitingForStableFrame = false
        awaitingCapture = false
        lastSample = nil
        noiseFloor = 0
        pendingNoiseFloor = 0
        candidateFrames.removeAll()
        candidateStableSince = nil
        candidateLastStableFrame = nil
        candidateLastStableTime = nil
        unstableComparisons = 0
        emptyComparisons = 0
        objectTracker = FeedObjectTracker()
        objectRegions = []
        backgroundRegions = []
        savedRegions = nil
        pendingRegions = []
        initialFrames = []
        evaluatedBackgroundScore = 0
        evaluatedSavedScore = nil
        imageBackgroundDifference = 0
        imageSavedDifference = nil
        objectBackgroundDifference = 0
        objectSavedDifference = nil
        preparation = FeedCountdownPreparation()
        feedbackPausedUntil = 0
        consecutiveAborts = 0
        if automaticThresholds != nil { automaticThresholds = FeedAutomaticThresholds() }
    }

    mutating func captureCompleted(at now: Double, succeeded: Bool = true) {
        guard awaitingCapture else { return }
        awaitingCapture = false
        // Nur eine erfolgreich gespeicherte Aufnahme ersetzt die letzte Motivreferenz.
        if succeeded, let pendingCapture {
            lastCaptured = pendingCapture
            savedRegions = pendingRegions
            returnedToBackground = false
            lastCapture = now
            noiseFloor = max(noiseFloor, pendingNoiseFloor)
            emptyComparisons = 0
            consecutiveAborts = 0
            automaticThresholds?.recordSuccess(at: now)
        } else {
            waitingForStableFrame = true
            recordAbort()
        }
        pendingCapture = nil
        lastSample = now
    }

    mutating func compare(_ sample: [UInt8], at now: Double, canCapture: Bool,
                          includeDiagnostics: Bool = false, regions: [CGRect] = []) -> FeedDetectionUpdate? {
        guard !sample.isEmpty, configuration.usesImageReference || configuration.usesObjectness, needsSample(at: now) else { return nil }
        lastDecision = "Keine neue Motivänderung erkannt"
        comparedCountdownSeconds = candidateStableSince.map { now - $0 }
        if configuration.usesObjectness {
            let previousRegions = objectRegions
            objectTracker.update(regions, at: now)
            objectRegions = objectTracker.regions
            objectPreviousDifference = FeedObjectGeometry.difference(objectRegions, previousRegions)
            if objectPreviousDifference >= 0.03 { lastActivity = now }
        }
        comparedCooldownRemaining = lastCapture.map { max(0, configuration.cooldown - (now - $0)) } ?? 0
        comparedReturnedToBackground = returnedToBackground
        comparedWaitingForStability = waitingForStableFrame
        // Ein verworfener Ausreißer darf nicht zur nächsten Bewegungsreferenz
        // werden: sonst würde auch das Zurückkehren zum ruhigen Motiv abbrechen.
        let baseline = candidateLastStableFrame ?? previous
        // Die feste Vorgangsreferenz kann beim Abbruch oder Auslösen verschwinden.
        // Für die Diagnose deshalb den tatsächlich geprüften Vergleich bewahren.
        let stabilityComparison: FeedDiagnosticComparison? = includeDiagnostics
            ? (candidate.map { FeedDiagnosticComparison.measuring(sample, against: $0, threshold: stabilityThreshold, compensatesExposure: configuration.compensatesExposure) }
               ?? preparation.diagnosticComparison(for: sample, tolerance: preparationThreshold, compensatesExposure: configuration.compensatesExposure)
               ?? (background == nil ? reference.diagnosticComparison(for: sample,
                    tolerance: configuration.stabilityThreshold * 1.25, allowsAdjustment: allowsReferenceAdjustment, compensatesExposure: configuration.compensatesExposure) : nil))
            : nil
        // Nur bei sichtbarer Diagnose zusätzliche Vergleichswerte berechnen.
        // defer bildet den Zustand nach dem Vergleich ab, auch bei Abbruch oder Aufnahme.
        defer {
            if includeDiagnostics {
                diagnostics = diagnosticsSnapshot(for: sample, previous: baseline,
                                                  stabilityComparison: stabilityComparison, at: now)
            }
        }
        previous = sample
        lastSample = now
        guard let background else {
            if !configuration.usesImageReference {
                // Objektpositionen benötigen Bestätigung, keine Ruhebedingung.
                initialFrames.append(sample)
                guard initialFrames.count >= 3 else { return nil }
                self.background = FeedStableReference.median(initialFrames) ?? sample
                backgroundRegions = objectRegions
                initialFrames.removeAll()
                noiseFloor = 0
                lastDecision = "Objektreferenz nach drei Messungen übernommen, ohne Ruheprüfung"
                return .referenceReady
            }
            switch reference.compare(sample, at: now, tolerance: configuration.stabilityThreshold * 1.25,
                                     allowsAdjustment: allowsReferenceAdjustment, compensatesExposure: configuration.compensatesExposure) {
            case .collecting:
                lastDecision = "Hintergrundreferenz: ruhige Frames sammeln (1,5 Sekunden erforderlich)"
                return nil
            case .restarted:
                lastDecision = "Hintergrundreferenz: Stillhalte-Schwelle überschritten, Referenzversuch neu gestartet"
                lastActivity = now
                return .referenceRestarted
            case .unstable:
                lastDecision = "Hintergrundreferenz: wiederholt instabil, Hinweis ausgelöst"
                lastActivity = now
                return .referenceUnstable
            case .ready(let frame):
                lastDecision = "Hintergrundreferenz nach 1,5 ruhigen Sekunden übernommen"
                self.background = frame
                backgroundRegions = objectRegions
                noiseFloor = reference.noiseFloor
                return .referenceReady
            }
        }
        guard let baseline, baseline.count == sample.count, background.count == sample.count else {
            lastDecision = "Unvereinbare Vergleichsframes, Referenzen zurückgesetzt"
            resetComparison()
            return .cancelled
        }
        let temporalDifference = difference(sample, baseline)
        evaluatedImageThreshold = changeThreshold
        evaluatedObjectThreshold = max(0.025, min(0.8, FeedObjectGeometry.threshold * configuration.threshold / 0.08 * (automaticThresholds?.changeFactor ?? 1)))
        imageBackgroundDifference = configuration.usesImageReference ? difference(sample, background) : 0
        imageSavedDifference = configuration.usesImageReference ? lastCaptured.map { difference(sample, $0) } : nil
        objectBackgroundDifference = configuration.usesObjectness ? FeedObjectGeometry.difference(objectRegions, backgroundRegions) : 0
        objectSavedDifference = configuration.usesObjectness ? savedRegions.map { FeedObjectGeometry.difference(objectRegions, $0) } : nil
        let noObject = !configuration.usesImageReference && objectRegions.isEmpty
        let backgroundDifference = noObject ? 0 : fusedScore(image: imageBackgroundDifference, objects: objectBackgroundDifference)
        let savedDifference = lastCaptured.map { _ in fusedScore(image: imageSavedDifference ?? 0, objects: objectSavedDifference ?? 0) }
        evaluatedBackgroundScore = backgroundDifference
        evaluatedSavedScore = savedDifference
        // Die stärkste belastbare Änderung im Fenster steuert die Anpassung.
        // Bereits gespeicherte Motive zählen ohne bestätigtes Entfernen nicht als neu.
        let signal = !returnedToBackground ? min(backgroundDifference, savedDifference ?? backgroundDifference) : backgroundDifference
        let normalizedNoise = configuration.usesImageReference ? noiseFloor / max(configuration.threshold, 0.002) : 0
        // Die Anpassungsregel erwartet ein Signal ohne ihren eigenen Faktor,
        // sonst würde sie schon vor Erreichen des Aufnahmegrenzwerts stoppen.
        let adjustmentSignal = signal * (automaticThresholds?.changeFactor ?? 1)
        automaticThresholds?.configure(speed: configuration.adaptationSpeed, dictation: configuration.usesDictation)
        automaticThresholds?.observe(signal: adjustmentSignal, noiseFloor: normalizedNoise, baseThreshold: 1,
                                     at: now, countdownRunning: candidate != nil)
        if temporalDifference >= stabilityThreshold { lastActivity = now }
        if backgroundDifference < 1 {
            let wasCounting = candidate != nil
            if wasCounting { recordAbort() }
            lastDecision = wasCounting
                ? "Countdown abgebrochen: Motiv entspricht wieder dem Hintergrund (unter Änderungsschwelle)"
                : "Kein Motiv: Hintergrunddifferenz liegt unter der Änderungsschwelle"
            candidate = nil
            lastCountdown = nil
            waitingForStableFrame = false
            preparation = FeedCountdownPreparation()
            clearCandidateHistory()
            // Ein einzelner zufälliger Hintergrundtreffer darf dasselbe Motiv
            // nicht erneut freigeben. Zwei klare Leer-Frames bestätigen Entfernen.
            if backgroundDifference < 0.6 {
                emptyComparisons += 1
                if emptyComparisons >= 2 { returnedToBackground = true }
            } else { emptyComparisons = 0 }
            return wasCounting ? .cancelled : nil
        }
        emptyComparisons = 0
        // Die Motivbedingung gilt für jeden Countdown-Frame, nicht nur beim Start.
        // Sonst könnte ein knapp als neu erkanntes Motiv vor der Aufnahme wieder
        // unter die Änderungsschwelle zum letzten Foto zurückfallen.
        if let savedDifference,
           savedDifference < 1,
           !returnedToBackground {
            let wasCounting = candidate != nil
            if wasCounting { recordAbort() }
            lastDecision = wasCounting
                ? "Countdown abgebrochen: Motiv entspricht wieder dem zuletzt gespeicherten Foto (unter Änderungsschwelle)"
                : "Doppelte Aufnahme verhindert: Motiv entspricht dem zuletzt erfolgreich gespeicherten Foto"
            candidate = nil
            lastCountdown = nil
            waitingForStableFrame = false
            preparation = FeedCountdownPreparation()
            clearCandidateHistory()
            return wasCounting ? .cancelled : nil
        }
        if let candidate {
            // Immer gegen dasselbe Vorgangs-Referenzfoto prüfen, damit langsame Bewegung nicht durchrutscht.
            let fixedDifference = difference(sample, candidate)
            guard !configuration.usesImageReference || (fixedDifference <= stabilityThreshold && temporalDifference <= stabilityThreshold) else {
                unstableComparisons += 1
                candidateStableSince = nil
                candidateFrames.removeAll()
                // Ein kleiner Ausreißer setzt die drei ruhigen Sekunden zurück.
                // Deutliche oder zwei aufeinanderfolgende Bewegungen brechen ab.
                if max(fixedDifference, temporalDifference) <= stabilityThreshold * 2.5,
                   unstableComparisons < 2 {
                    lastDecision = "Countdown-Ruhezeit zurückgesetzt: einzelner mäßiger Ausreißer; drei neue ruhige Sekunden erforderlich"
                    lastCountdown = 3
                    return .countdown(3)
                }
                lastDecision = "Countdown abgebrochen: deutliche oder wiederholte Bewegung gegen vorherigen Frame/feste Referenz"
                recordAbort()
                self.candidate = nil
                lastCountdown = nil
                waitingForStableFrame = true
                lastActivity = now
                clearCandidateHistory()
                return .cancelled
            }
            unstableComparisons = 0
            // Zeit ohne geprüfte Frames ist kein Nachweis für Ruhe. Bei einer
            // Messlücke beginnt die volle Ruhezeit mit diesem Frame erneut.
            let hadSampleGap = candidateLastStableTime.map { now - $0 > maximumStableSampleGap } ?? false
            if hadSampleGap {
                candidateStableSince = now
                candidateFrames.removeAll()
                lastCountdown = nil
                comparedCountdownSeconds = 0
            }
            if candidateStableSince == nil { candidateStableSince = now }
            candidateLastStableFrame = sample
            candidateLastStableTime = now
            candidateFrames.append(sample)
            if candidateFrames.count > 9 { candidateFrames.removeFirst() }
            let elapsed = now - (candidateStableSince ?? now)
            if elapsed + 0.000001 >= 3, candidateFrames.count >= 3 {
                guard canCapture else {
                    lastDecision = "Countdown abgeschlossen, aber Kamera/Aufnahme noch beschäftigt"
                    return nil
                }
                guard comparedCooldownRemaining == 0 else {
                    lastDecision = "Countdown abgeschlossen, aber geänderte Speicherpause noch nicht abgelaufen"
                    return nil
                }
                lastDecision = "Aufnahme ausgelöst: gemeinsamer Szenenwert ≥ 1 gegen Hintergrund und letzte Aufnahme; gewählte Bild-Ruheprüfung erfüllt, Kamera frei"
                pendingRegions = objectRegions
                // Die erfolgreiche Fotoreferenz entsteht aus mehreren ruhigen
                // Messframes, statt aus einem möglicherweise verrauschten Einzelbild.
                pendingCapture = FeedStableReference.median(candidateFrames) ?? sample
                pendingNoiseFloor = FeedStableReference.noiseFloor(candidateFrames, reference: pendingCapture ?? sample, compensatesExposure: configuration.compensatesExposure)
                self.candidate = nil
                awaitingCapture = true
                lastActivity = now
                clearCandidateHistory()
                return .capture
            }
            let number = max(1, 3 - Int(elapsed + 0.000001))
            lastDecision = hadSampleGap
                ? "Countdown-Ruhezeit zurückgesetzt: Messlücke, drei durchgehend geprüfte ruhige Sekunden erforderlich"
                : "Countdown läuft: beide Stillhalte-Vergleiche innerhalb der Schwelle"
            guard number != lastCountdown else { return nil }
            lastCountdown = number
            return .countdown(number)
        }
        // Der Hintergrund- und Fotoreferenzvergleich belegen bereits ein gültiges
        // Motiv. Auch vor dem allerersten Foto darf eine langsam entstandene
        // Änderung auslösen, ohne großen Sprung zwischen zwei einzelnen Frames.
        waitingForStableFrame = true
        guard !configuration.usesImageReference || preparation.compare(sample, at: now, tolerance: preparationThreshold,
                                  maximumGap: maximumStableSampleGap, compensatesExposure: configuration.compensatesExposure) else {
            lastDecision = "Countdown wartet: eine durchgehend geprüfte ruhige Sekunde vor dem Start erforderlich"
            return nil
        }
        guard canCapture else {
            lastDecision = "Erfassung wartet: Kamera/Aufnahme beschäftigt"
            return nil
        }
        guard comparedCooldownRemaining == 0 else {
            lastDecision = "Erfassung wartet: Speicherpause nach letzter erfolgreicher Aufnahme"
            return nil
        }
        preparation = FeedCountdownPreparation()
        lastDecision = configuration.usesImageReference
            ? "Countdown gestartet: Szenenwert erreicht und Bild eine Sekunde ruhig"
            : "Countdown gestartet: bestätigte Objektänderung, ohne Ruheprüfung"
        candidate = sample
        candidateStableSince = now
        candidateFrames = [sample]
        candidateLastStableFrame = sample
        candidateLastStableTime = now
        unstableComparisons = 0
        lastCountdown = 3
        waitingForStableFrame = false
        return .countdown(3)
    }

    /// Hinweise unterbrechen die Erfassung, ohne Hintergrund und letztes Foto zu verlieren.
    /// Danach muss die Vorprüfung erneut Ruhe nachweisen; Pausenzeit zählt niemals mit.
    mutating func pauseForFeedback(at now: Double, duration: Double) {
        feedbackPausedUntil = max(feedbackPausedUntil, now + duration)
        if background == nil { reference = FeedBackgroundReference(); initialFrames.removeAll() }
        candidate = nil
        lastCountdown = nil
        preparation = FeedCountdownPreparation()
        waitingForStableFrame = background != nil
        clearCandidateHistory()
        lastDecision = "Erfassung für Hinweis pausiert; anschließend neue Ruheprüfung erforderlich"
    }

    private mutating func recordAbort() {
        automaticThresholds?.recordAbort()
        preparation = FeedCountdownPreparation()
        consecutiveAborts += 1
        // Auch feste Toleranzstufen melden wiederholte Fehlversuche.
        if consecutiveAborts.isMultiple(of: 5) { repeatedAbortRevision += 1 }
    }

    private mutating func clearCandidateHistory() {

        candidateFrames.removeAll()
        candidateStableSince = nil
        candidateLastStableFrame = nil
        candidateLastStableTime = nil
        unstableComparisons = 0
    }

    private func diagnosticsSnapshot(for sample: [UInt8], previous: [UInt8]?,
                                     stabilityComparison: FeedDiagnosticComparison?, at now: Double) -> FeedDiagnosticsSnapshot {
        func comparison(with frame: [UInt8]?, threshold: Double) -> FeedDiagnosticComparison? {
            guard configuration.usesImageReference, let frame, frame.count == sample.count else { return nil }
            return .measuring(sample, against: frame, threshold: threshold, compensatesExposure: configuration.compensatesExposure)
        }
        let displayedStabilityThreshold = candidate == nil && waitingForStableFrame
            ? preparationThreshold : stabilityThreshold
        var snapshot = FeedDiagnosticsSnapshot(
            previousComparison: comparison(with: previous, threshold: displayedStabilityThreshold),
            backgroundComparison: comparison(with: background, threshold: changeThreshold),
            savedPhotoComparison: comparison(with: lastCaptured, threshold: changeThreshold),
            stabilityComparison: configuration.usesImageReference ? stabilityComparison : nil, noiseFloor: noiseFloor,
            effectiveChangeThreshold: changeThreshold, effectiveStabilityThreshold: displayedStabilityThreshold,
            automaticThresholdAdjustment: automaticThresholds != nil,
            dynamicChangeFactor: automaticThresholds?.changeFactor ?? 1,
            dynamicStabilityFactor: automaticThresholds?.stabilityFactor ?? 1)
        snapshot.sceneScore = min(evaluatedBackgroundScore, returnedToBackground ? evaluatedBackgroundScore : evaluatedSavedScore ?? evaluatedBackgroundScore)
        snapshot.sceneThreshold = 1
        snapshot.fusionImageThreshold = evaluatedImageThreshold
        snapshot.fusionObjectThreshold = evaluatedObjectThreshold
        snapshot.objectPreviousDifference = configuration.usesObjectness ? objectPreviousDifference : nil
        snapshot.objectBackgroundDifference = configuration.usesObjectness ? objectBackgroundDifference : nil
        snapshot.objectSavedDifference = objectSavedDifference
        snapshot.currentObjectRegions = objectRegions
        snapshot.backgroundObjectRegions = backgroundRegions
        snapshot.savedObjectRegions = savedRegions
        snapshot.imageBackgroundDifference = configuration.usesImageReference ? imageBackgroundDifference : nil
        snapshot.imageSavedDifference = imageSavedDifference
        snapshot.imageStabilityRequired = configuration.usesImageReference
        snapshot.wouldCapture = awaitingCapture
        guard background != nil else {
            snapshot.phase = .reference
            return snapshot
        }
        let backgroundProgress = evaluatedBackgroundScore
        let motifProgress = returnedToBackground ? backgroundProgress : (evaluatedSavedScore ?? backgroundProgress)
        // Ein leerer Hintergrund bleibt unzulässig, auch wenn er vom letzten Motiv abweicht.
        let change = FeedDiagnosticsSnapshot.progress(min(backgroundProgress, motifProgress))
        let phase: FeedDiagnosticsSnapshot.Phase = awaitingCapture ? .capturing
            : (candidate != nil ? .countdown : (waitingForStableFrame ? .movement : .monitoring))
        let capture = awaitingCapture ? 1
            : (candidate != nil ? candidateStableSince.map { FeedDiagnosticsSnapshot.progress((now - $0) / 3) } ?? 0 : 0)
        snapshot.phase = phase
        snapshot.changeProgress = change
        snapshot.captureProgress = capture
        return snapshot
    }

    private func fusedScore(image: Double, objects: Double) -> Double {
        FeedSceneFusion.score(image: image / evaluatedImageThreshold,
                              objects: objects / evaluatedObjectThreshold,
                              useImage: configuration.usesImageReference, useObjects: configuration.usesObjectness)
    }

    /// Einheitliche regionale Metrik für Motiv, Bewegung und Referenzbildung.
    private func difference(_ sample: [UInt8], _ baseline: [UInt8]) -> Double {
        FeedSceneComparison.measure(sample, against: baseline, compensatesExposure: configuration.compensatesExposure).score
    }

    static func difference(_ sample: [UInt8], _ baseline: [UInt8]) -> Double {
        FeedSceneComparison.measure(sample, against: baseline).score
    }
}
