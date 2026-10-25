import SwiftUI

struct SettingsLocationView: View {
    var iconBackgroundColor: Color = .newYellow
    @EnvironmentObject var accentColorManager: AccentColorManager
    @State private var showLocationImageBackground: Bool = UserDefaults.standard.object(forKey: "showLocationImageBackground") == nil ? true : UserDefaults.standard.bool(forKey: "showLocationImageBackground")

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(iconBackgroundColor)
                                .frame(width: 70, height: 70)

                            Image(systemName: "location.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        Spacer()
                    }

                    Text("Locations")
                        .font(.system(size: 25, weight: .bold))

                    Text("Control how location images are used in detail views.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)
                }
            }

            Section("Background") {
                HStack {
                    Text("Use location image in detail background")
                    Spacer()
                    Toggle("", isOn: $showLocationImageBackground)
                        .tint(accentColorManager.accentColor)
                }
                .onChange(of: showLocationImageBackground, initial: false) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "showLocationImageBackground")
                }
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            showLocationImageBackground = UserDefaults.standard.object(forKey: "showLocationImageBackground") == nil ? true : UserDefaults.standard.bool(forKey: "showLocationImageBackground")
        }
    }
}
