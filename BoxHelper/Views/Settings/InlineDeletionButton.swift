import SwiftUI

/// Alle Löschaktionen verwenden dieselbe zweistufige Bestätigung direkt in der Liste.
@MainActor
struct InlineDeletionButton: View {
    let title: LocalizedStringKey
    var systemImage = "trash"
    var sliderTitle: LocalizedStringKey = "Zum Löschen schieben"
    var confirmationMessage: LocalizedStringKey? = nil
    var progressTitle: LocalizedStringKey = "Wird gelöscht …"
    var successMessage: LocalizedStringKey? = nil
    var failureMessage: LocalizedStringKey = "Löschen fehlgeschlagen. Bitte versuche es erneut."
    var isDisabled = false
    var accessibilityIdentifier = "deletion"
    let action: @MainActor () async throws -> Void
    @State private var isArmed = false
    @State private var isDeleting = false
    @State private var hasCompleted = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            if isDeleting {
                ProgressView(progressTitle).frame(maxWidth: .infinity)
            } else if isArmed {
                SlideToConfirmDeletion(isDisabled: isDisabled,
                                       title: sliderTitle,
                                       accessibilityLabel: title,
                                       accessibilityIdentifier: accessibilityIdentifier + ".confirmSlider",
                                       cancelAccessibilityIdentifier: accessibilityIdentifier + ".cancel",
                                       onCancel: { isArmed = false },
                                       onConfirm: performDeletion)
                if let confirmationMessage {
                    Text(confirmationMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Button(role: .destructive) {
                    errorMessage = nil
                    hasCompleted = false
                    isArmed = true
                } label: {
                    Label(title, systemImage: systemImage)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .tint(.red)
                .disabled(isDisabled)
                .accessibilityIdentifier(accessibilityIdentifier + ".open")
            }
            if hasCompleted, let successMessage {
                Text(successMessage).font(.footnote).foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(failureMessage).font(.footnote).foregroundStyle(.red)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onDisappear { isArmed = false }
    }

    private func performDeletion() {
        guard isArmed, !isDeleting, !isDisabled else { return }
        isDeleting = true
        errorMessage = nil
        // Erst die zweite Interaktion führt die Aktion aus; doppelte Aufträge sind gesperrt.
        Task {
            defer {
                isDeleting = false
                isArmed = false
            }
            do {
                try await action()
                hasCompleted = true
            } catch {
                hasCompleted = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
