import Foundation
import CoreGraphics

/// Rohwerte des belichtungsbereinigten Bildvergleichs. Die Schwelle bleibt in
/// derselben Skala wie die Differenz; Übereinstimmung ist deren Gegenwert.
struct FeedDiagnosticComparison: Equatable, Sendable, Codable {
    let difference: Double
    let threshold: Double
    var globalDifference: Double? = nil
    var regionalDifference: Double? = nil
    var changedArea: Double? = nil

    var agreement: Double { 1 - FeedDiagnosticsSnapshot.progress(difference) }

    static func measuring(_ sample: [UInt8], against reference: [UInt8], threshold: Double, compensatesExposure: Bool = true) -> Self {
        let measurement = FeedSceneComparison.measure(sample, against: reference, compensatesExposure: compensatesExposure)
        return Self(difference: measurement.score, threshold: threshold,
                    globalDifference: measurement.globalDifference,
                    regionalDifference: measurement.regionalDifference, changedArea: measurement.changedArea)
    }
}

/// Diagnosewerte des vorhandenen Detektors, keine statistisch kalibrierte Wahrscheinlichkeit.
/// 100 % Änderung bedeutet, dass die konfigurierte Änderungsschwelle erreicht ist.
struct FeedDiagnosticsSnapshot: Equatable, Sendable, Codable {
    enum Phase: String, Sendable, Codable {
        case inactive = "FeedDiagnostics.Inactive"
        case reference = "FeedDiagnostics.Reference"
        case monitoring = "FeedDiagnostics.Monitoring"
        case movement = "FeedDiagnostics.Movement"
        case countdown = "FeedDiagnostics.Countdown"
        case capturing = "FeedDiagnostics.Capturing"
        case captured = "FeedDiagnostics.Captured"
    }

    var sceneScore: Double = 0
    var sceneThreshold: Double = 1
    var fusionImageThreshold: Double = 0.08
    var fusionObjectThreshold: Double = 0.18
    var objectPreviousDifference: Double?
    var objectBackgroundDifference: Double?
    var objectSavedDifference: Double?
    var imageBackgroundDifference: Double?
    var imageSavedDifference: Double?
    var currentObjectRegions: [CGRect] = []
    var backgroundObjectRegions: [CGRect] = []
    var savedObjectRegions: [CGRect]?
    var imageStabilityRequired = true
    var wouldCapture = false
    var phase: Phase = .inactive
    var changeProgress: Double?
    var captureProgress = 0.0
    var capturedPhotos = 0
    var previousComparison: FeedDiagnosticComparison?
    var backgroundComparison: FeedDiagnosticComparison?
    var savedPhotoComparison: FeedDiagnosticComparison?
    var stabilityComparison: FeedDiagnosticComparison?
    var noiseFloor: Double = 0
    var effectiveChangeThreshold: Double = 0
    var effectiveStabilityThreshold: Double = 0
    var automaticThresholdAdjustment = false
    var dynamicChangeFactor = 1.0
    var dynamicStabilityFactor = 1.0

    static func progress(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }
}

/// Zehn schnelle Einzeltipps; Pausen oder eine zu lange Folge verwerfen den bisherigen Zähler.
struct FeedDiagnosticsTapSequence {
    private(set) var count = 0
    private var startedAt: Double?
    private var lastTap: Double?

    mutating func record(at now: Double) -> Bool {
        if (lastTap.map({ now - $0 > 0.5 || now < $0 }) ?? true)
            || (startedAt.map({ now - $0 > 4.5 }) ?? false) {
            count = 0
            startedAt = now
        }
        lastTap = now
        count += 1
        guard count == 10 else { return false }
        self = Self()
        return true
    }
}
