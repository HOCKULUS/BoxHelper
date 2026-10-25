import SwiftUI

/// Match the editable title in BoxDetailView's principal toolbar item.
struct CreateFormTitle: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var settingsTarget: String? = nil
    var autofocusName = false
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ZStack {
            TextField(placeholder, text: $text)
                .focused($isNameFocused)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, settingsTarget == nil ? 5 : 28)
                .padding(.vertical, 5)
                .padding(.top, -1)
                .task(id: autofocusName) {
                    guard autofocusName else { return }
                    // Die Toolbar muss zuerst eingebaut sein. Beim Formularwechsel
                    // wird die Aufgabe abgebrochen, bevor sie die Tastatur öffnen kann.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    isNameFocused = true
                }
                .onDisappear { isNameFocused = false }
            if let settingsTarget {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        UserDefaults.standard.set(settingsTarget, forKey: "createNameSettingsTarget")
                        NotificationCenter.default.post(name: .openSettingsFromCreate, object: nil)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open automatic naming settings")
                    .padding(.trailing, 6)
                }
            }
        }
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white)
            .cornerRadius(19)
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .frame(width: UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac
                   ? UIScreen.main.bounds.width / 5 : UIScreen.main.bounds.width / 2.5)
    }
}

/// Native toolbar placement keeps the title outside the scrolling form on every device.
struct CreateFormToolbar<Title: View>: ToolbarContent {
    @ViewBuilder let title: () -> Title

    var body: some ToolbarContent {
        // Stabile Kennungen erlauben den Austausch der Formularinhalte, ohne
        // die Toolbar-Plätze beim Moduswechsel neu anzulegen.
        ToolbarItem(id: "createFormTitle", placement: .principal) {
            title()
        }
        ToolbarItem(id: "createFormFeedback", placement: .topBarTrailing) {
            CreateFeedbackButton()
        }
    }
}

/// Matches the floating glass controls used by the list's Select All button.
struct CreateControlSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect()
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

/// All three forms use the same footer; the camera shutter is a separate overlay.
struct CreateSaveControls: View {
    let leftButton: AnyView
    let rightButton: AnyView
    let isDisabled: Bool
    let color: Color
    let save: () -> Void

    var body: some View {
        HStack {
            leftButton
            Spacer()
            Button(action: save) {
                Label("Speichern", systemImage: "square.and.arrow.down")
                    .padding(10)
            }
            .buttonStyle(.plain)
            .modifier(CreateControlSurface())
            .disabled(isDisabled)
            Spacer()
            rightButton
        }
        .tint(color)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

/// A brief, translucent confirmation shown over the form after a successful save.
struct CreateSavedConfirmation: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.green)
            Text("Saved")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
    }
}
