import SwiftUI

/// Einstellungen verlinken nur das gemeinsame Popup, statt Cloud-Schalter zu duplizieren.
struct InventoryCloudSettingsLink: View {
    var iconBackgroundColor: Color = .newYellow
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            HStack {
                // Dieselbe Icon-Kachel wie die benachbarten Einstellungsseiten.
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconBackgroundColor)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "icloud.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, 10)
                Text("iCloud")
                    .font(.system(size: 16))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
        }
        .tint(.primary)
        .accessibilityHint("iCloud-Status und Freigaben öffnen")
        .sheet(isPresented: $isPresented) { InventoryCloudDashboard() }
    }
}
