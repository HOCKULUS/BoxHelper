import SwiftUI

/// Dieselben Symbole wie in den Item-Details kennzeichnen die zwei unabhängigen Eigenschaften.
struct CreateItemHandlingSection: View {
    @Binding var isHeavy: Bool
    @Binding var isFragile: Bool

    var body: some View {
        Section {
            Button { isHeavy.toggle() } label: {
                Label(isHeavy ? "Heavy" : "Not heavy", image: isHeavy
                      ? "custom.figure.strengthtraining.traditional"
                      : "custom.figure.strengthtraining.traditional.slash")
                    .foregroundStyle(isHeavy ? Color.primary : .gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityValue(Text(isHeavy ? "Heavy" : "Not heavy"))
            Button { isFragile.toggle() } label: {
                Label(isFragile ? "Fragile" : "Not fragile", image: isFragile
                      ? "custom.wineglass" : "custom.wineglass.slash")
                    .foregroundStyle(isFragile ? Color.primary : .gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityValue(Text(isFragile ? "Fragile" : "Not fragile"))
        }
    }
}
