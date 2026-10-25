import SwiftUI

/// Flüchtige Messwerte. Grün bedeutet: Die jeweilige Bedingung ist erfüllt;
/// bei Ruhe gilt eine Obergrenze, bei Änderung eine Untergrenze.
struct CreateFeedDiagnosticsOverlay: View {
    let snapshot: FeedDiagnosticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("FeedSources.Score", value: number(snapshot.sceneScore) + " / " + number(snapshot.sceneThreshold),
                reached: snapshot.sceneScore >= snapshot.sceneThreshold)
            row("FeedSources.Decision", value: String(localized: snapshot.wouldCapture ? "FeedSources.Yes" : "FeedSources.Wait"), reached: snapshot.wouldCapture)
            row("FeedDiagnostics.Change", value: snapshot.changeProgress.map(percent) ?? "—", reached: (snapshot.changeProgress ?? 0) >= 1)
            row("FeedDiagnostics.Capture", value: "\(percent(snapshot.captureProgress)) · #\(snapshot.capturedPhotos)", reached: snapshot.captureProgress >= 1)
            Divider()
            Text("FeedDiagnostics.ComparisonLegend").font(.caption2).foregroundStyle(.secondary)
            comparisonRow("FeedDiagnostics.Previous", comparison: snapshot.previousComparison, isStability: true)
            comparisonRow("FeedDiagnostics.Background", comparison: snapshot.backgroundComparison)
            comparisonRow("FeedDiagnostics.Saved", comparison: snapshot.savedPhotoComparison)
            comparisonRow("FeedDiagnostics.Stability", comparison: snapshot.stabilityComparison, isStability: true)
            Divider()
            measurementRow("FeedDiagnostics.ImageBackground", difference: snapshot.imageBackgroundDifference, threshold: snapshot.fusionImageThreshold)
            measurementRow("FeedDiagnostics.ImageSaved", difference: snapshot.imageSavedDifference, threshold: snapshot.fusionImageThreshold)
            measurementRow("FeedDiagnostics.ObjectBackground", difference: snapshot.objectBackgroundDifference, threshold: snapshot.fusionObjectThreshold)
            measurementRow("FeedDiagnostics.ObjectSaved", difference: snapshot.objectSavedDifference, threshold: snapshot.fusionObjectThreshold)
            row("FeedDiagnostics.Objects", value: "\(snapshot.currentObjectRegions.count) / \(snapshot.backgroundObjectRegions.count) / \(snapshot.savedObjectRegions?.count ?? 0)")
            ForEach(Array(snapshot.currentObjectRegions.enumerated()), id: \.offset) { index, rect in
                Text(verbatim: String(format: "#%d x %.2f y %.2f w %.2f h %.2f", index + 1, rect.minX, rect.minY, rect.width, rect.height))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Divider()
            row("FeedDiagnostics.Noise", value: percent(snapshot.noiseFloor))
            row("FeedDiagnostics.DynamicFactors", value: "\(number(snapshot.dynamicChangeFactor)) / \(number(snapshot.dynamicStabilityFactor))")
            Text("FeedDiagnostics.ThresholdNote").font(.caption2).foregroundStyle(.secondary)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(12)
        .accessibilityElement(children: .contain)
    }

    private func number(_ value: Double) -> String { String(format: "%.2f", value) }
    private func percent(_ value: Double) -> String { String(format: "%.1f %%", value * 100) }

    private func row(_ title: LocalizedStringKey, value: String, reached: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
            Spacer(minLength: 2)
            Text(verbatim: value).foregroundStyle(reached ? Color.green : Color.primary)
        }
    }

    private func measurementRow(_ title: LocalizedStringKey, difference: Double?, threshold: Double) -> some View {
        row(title, value: difference.map { "\(percent($0)) / \(percent(threshold))" } ?? "—",
            reached: difference.map { $0 >= threshold } ?? false)
    }

    private func comparisonRow(_ title: LocalizedStringKey, comparison: FeedDiagnosticComparison?, isStability: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            row(title, value: comparison.map { "\(percent($0.agreement)) · \(percent($0.difference)) / \(percent($0.threshold))" } ?? "—",
                reached: comparison.map { isStability ? $0.difference <= $0.threshold : $0.difference >= $0.threshold } ?? false)
            if let comparison {
                Text(verbatim: "global \(comparison.globalDifference.map(percent) ?? "—") · regional \(comparison.regionalDifference.map(percent) ?? "—") · area \(comparison.changedArea.map(percent) ?? "—")")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
    }
}
