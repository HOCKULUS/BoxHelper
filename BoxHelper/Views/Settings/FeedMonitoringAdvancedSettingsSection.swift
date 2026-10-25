import SwiftUI

/// Gemeinsame Grenzwerte entsprechen der validierten Konfiguration des Kamera-Modus.
struct FeedMonitoringAdvancedSettingsSection: View {
    @AppStorage(FeedMonitoringConfiguration.thresholdKey) private var threshold = 0.08
    @AppStorage(FeedMonitoringConfiguration.inactivityKey) private var inactivity = 300.0
    @AppStorage(FeedMonitoringConfiguration.cooldownKey) private var cooldown = 4.0
    @AppStorage(FeedMonitoringConfiguration.stabilityThresholdKey) private var stabilityThreshold = 0.025
    @AppStorage(FeedMonitoringConfiguration.stabilityIntervalKey) private var stabilityInterval = 0.2

    var body: some View {
        Section {
            row("FeedMonitoring.Interval", value: seconds(FeedMonitoringConfiguration.regularInterval))
            VStack(alignment: .leading, spacing: 8) {
                row("FeedMonitoring.Threshold", value: (threshold * 100).formatted(.number.precision(.fractionLength(1))) + " %")
                Slider(value: $threshold, in: 0.002...0.5, step: 0.002)
                    .accessibilityLabel("FeedMonitoring.Threshold")
            }
            Stepper(value: $inactivity, in: 30...1800, step: 30) {
                row("FeedMonitoring.Inactivity", value: seconds(inactivity))
            }
            Stepper(value: $cooldown, in: 1...120, step: 1) {
                row("FeedMonitoring.Cooldown", value: seconds(cooldown))
            }
            VStack(alignment: .leading, spacing: 8) {
                row("FeedMonitoring.StabilityThreshold", value: (stabilityThreshold * 100).formatted(.number.precision(.fractionLength(1))) + " %")
                Slider(value: $stabilityThreshold, in: 0.001...0.2, step: 0.001)
                    .accessibilityLabel("FeedMonitoring.StabilityThreshold")
            }
            Stepper(value: $stabilityInterval, in: 0.1...1, step: 0.1) {
                row("FeedMonitoring.StabilityInterval", value: String.localizedStringWithFormat(
                    String(localized: "FeedMonitoring.FractionalSeconds"), stabilityInterval))
            }
            Button("FeedMonitoring.Reset") {
                threshold = 0.08
                inactivity = 300
                cooldown = 4
                stabilityThreshold = 0.025
                stabilityInterval = 0.2
                UserDefaults.standard.set(0, forKey: FeedSensitivityLevel.storageKey)
            }
        } header: {
            Text("FeedMonitoring.AdvancedTitle")
        }
    }

    private func row(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func seconds(_ value: Double) -> String {
        String.localizedStringWithFormat(String(localized: "FeedMonitoring.Seconds"), Int(value))
    }
}
