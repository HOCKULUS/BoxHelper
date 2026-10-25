import SwiftUI
import UIKit

/// Independent button actions prevent a Form row from triggering several icon changes at once.
struct AppIconSettingsSection: View {
    @ObservedObject private var controller = AppIconController.shared
    private let choices: [(name: String, preview: String, label: LocalizedStringKey)] = [
        ("AppIcon", "AppLogoPreview", "Default"),
        ("AppIconFirst", "AppLogoFirstPreview", "1st"),
        ("AppIconSkeuomorph", "AppLogoSkeuomorphPreview", "Classic"),
        ("AppIconPride", "AppLogoPridePreview", "Pride"),
        ("AppIconReal", "AppLogoRealPreview", "Realistic"),
        ("AppIconClassic", "AppLogoClassicPreview", "3D")
    ]

    var body: some View {
        Section(header: Text("Icon")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(choices, id: \.name) { choice in
                        Button { controller.changeIcon(to: choice.name) } label: {
                            VStack {
                                Image(choice.preview)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                Text(choice.label).font(.footnote).foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(controller.isChanging)
                    }
                }
            }
            .cornerRadius(14)
        }
        .alert("Iconwechsel nicht möglich", isPresented: Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.dismissError() } }
        )) {
            Button("OK", role: .cancel) { controller.dismissError() }
        } message: {
            Text(controller.errorMessage ?? "")
        }
    }
}
