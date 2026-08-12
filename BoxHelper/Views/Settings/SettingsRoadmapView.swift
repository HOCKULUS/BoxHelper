//
//  SettingsRoadmapView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//

//
//  SettingsAppereance.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//

import SwiftUI

struct SettingsRoadmapView: View {
    var iconBackgroundColor: Color = .customBlueGreen
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
                                .frame(width: 90, height: 90) // Beibehaltung der Box-Größe
                            
                            Image(systemName: "map.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60) // Größeres Icon für bessere Sichtbarkeit
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("Roadmap")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                    }
                    HStack {
                        Text("A sneak peek into the future of the app.")
                            .font(.subheadline) // Einheitliche Schriftgröße
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .listSectionSpacing(8)
    }
}
