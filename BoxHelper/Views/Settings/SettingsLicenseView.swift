//
//  SettingsLicenseView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 31.01.25.
//

//
//  SettingsAppereance.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//

import SwiftUI
struct SettingsLicenseView: View {
    var iconBackgroundColor: Color = .newBlue
    @EnvironmentObject var accentColorManager: AccentColorManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    var body: some View {
        Form{
            Section {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous) // Abgerundete Ecken statt Kreis
                                .fill(iconBackgroundColor)
                                .frame(width: 70, height: 70) // Beibehaltung der Box-Größe
                            
                            Image(systemName: "bookmark.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50) // Größeres Icon für bessere Sichtbarkeit
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("Licenses")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                    }
                    HStack {
                        Text("No need to reinvent the wheel. Just download and use these open source libraries.")
                            .font(.subheadline) // Einheitliche Schriftgröße
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.bottom, 10)
                }
            }
            Section(header: Text("Lizenzen")){
                List {
                    NavigationLink(destination: LicenseListViewBoxHelper()) {
                        Text("BoxHelper")
                    }
                    NavigationLink(destination: LicenseListViewZip()) {
                        Text("Swift ZIP Framework")
                    }
                    NavigationLink(destination: LicenseListViewZoom()) {
                        Text("Zoomable Scroll View")
                    }
                }
            }
        }
        .listSectionSpacing(8)
    }
}
