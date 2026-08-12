//
//  SettingsAppereance.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//

import SwiftUI

struct SettingsAppereanceView: View {
    var iconBackgroundColor: Color = .newOlive
    let availableColors: [Color] = [
        //.customCarmine,        // Rote Töne
        .customNeonPink,
        //.pink,                 // Pink (auch ein Rot-Ton)
        .customCoral,          // Korallenrot (in die Orange-Gelb Kategorie)
        .orange,               // Standard Orange
        .yellow,               // Standard Gelb
        //.customSunYellow,      // Sonnengelb (Gelb)
        .customMint,        // Smaragdgrün (Grün)
        .green,                // Standard Grün
        .customGreen,
        //.customDarkGreen,      // Türkis (Blau-Grün)
        .customBlueGreen,
        .teal,                 // Standard Teal
        .blue,                 // Standard Blau
        //.customIceBlue,        // Eisblau (Blau)
        //.customMidnightBlue,   // Mitternachtsblau (Blau)
        .indigo,               // Indigo (Blau-Violett)
        .customLavender,       // Lavendel (Violett)
        //.purple,               // Standard Lila/Violett
        .brown,                // Braun (neutrale Farbe)
        .gray,                  // Grau (neutrale Farbe)
        .customGray,
    ]
    @EnvironmentObject var accentColorManager: AccentColorManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @AppStorage(FirstTabListLimit.alwaysLoadAllKey) private var alwaysLoadAllFirstTabLists: Bool = false
    @AppStorage(FirstTabListLimit.customLimitKey) private var customFirstTabListLimit: Int = 0

    private var effectiveFirstTabLimit: Int {
        FirstTabListLimit.limit(customLimit: customFirstTabListLimit)
    }

    private var customFirstTabListLimitBinding: Binding<Int> {
        Binding(
            get: { self.effectiveFirstTabLimit },
            set: { self.customFirstTabListLimit = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(iconBackgroundColor)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "paintbrush.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        Spacer()
                    }
                    
                    HStack {
                        Spacer()
                        Text("Design")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                    }
                    
                    HStack {
                        Text("Customize your app appearance and set your own accent color :)")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.bottom, 10)
                }
            }
            
            if UIDevice.current.userInterfaceIdiom != .mac {
                Section(header: Text("Icon")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            Button(action: {
                                changeIcon(to: "AppIcon") // Standard Icon
                            }) {
                                VStack {
                                    Image("AppLogoPreview")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    HStack(alignment: .center ){Text("Default").font(.footnote).foregroundStyle(Color.primary)}
                                }
                            }
                            Button(action: {
                                changeIcon(to: "AppIconFirst")
                            }) {
                                VStack {
                                    Image("AppLogoFirstPreview")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    HStack(alignment: .center ){Text("1st").font(.footnote).foregroundStyle(Color.primary)}
                                }
                            }
                            Button(action: {
                                changeIcon(to: "AppIconSkeuomorph")
                            }) {
                                VStack {
                                    Image("AppLogoSkeuomorphPreview")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    HStack(alignment: .center ){Text("Classic").font(.footnote).foregroundStyle(Color.primary)}
                                }
                            }
                            Button(action: {
                                changeIcon(to: "AppIconPride")
                            }) {
                                VStack {
                                    Image("AppLogoPridePreview")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    HStack(alignment: .center ){Text("Pride").font(.footnote).foregroundStyle(Color.primary)}
                                }
                            }
                            Button(action: {
                                changeIcon(to: "AppIconReal")
                            }) {
                                VStack {
                                    Image("AppLogoRealPreview")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    HStack(alignment: .center ){Text("Realistic").font(.footnote).foregroundStyle(Color.primary)}
                                }
                            }
                            Button(action: {
                                changeIcon(to: "AppIconClassic")
                            }) {
                                VStack {
                                    Image("AppLogoClassicPreview")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    HStack(alignment: .center ){Text("3D").font(.footnote).foregroundStyle(Color.primary)}
                                }
                            }
                        }
                    }
                    .cornerRadius(14)
                }
                Section(header: Text("Color Scheme")) {
                    VStack {
                        HStack {
                            Text("Change App Color:")
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(selectedColor)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "textformat")
                                    .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                
                                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .onChange(of: selectedColor) { oldValue, newValue in
                                        // Farbe speichern und aktualisieren
                                        UserDefaultsManager.saveAccentColor(newValue)
                                        
                                            selectedColor = newValue
                                            accentColorManager.updateAccentColor(to: newValue)
                                            //selectedColor = colorToString(newValue) ?? Color.blue

                                        print("\(String(describing: colorToString(selectedColor)))")
                                    }
                                    .scaleEffect(CGSize(width: 1.8, height: 1.8))
                                    .padding(.horizontal, 13)
                                ForEach(availableColors, id: \..self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: selectedColor == color ? 47 : 50, height: selectedColor == color ? 47 : 50)
                                        .overlay(
                                            Circle()
                                                .stroke(accentColorManager.accentColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                        .onTapGesture {
                                                selectedColor = color
                                                UserDefaultsManager.saveAccentColor(color)
                                                accentColorManager.updateAccentColor(to: color)
                                        }
                                }
                                /*
                                ZStack {
                                    GeometryReader { geometry in
                                        let width = geometry.size.width
                                        let height = geometry.size.height
                                        
                                        // Oberer Bereich (Dark Appearance)
                                        VStack(spacing: 0) {
                                            Color.newContrast
                                                .environment(\.colorScheme, .dark)
                                                .frame(height: height / 2)
                                            
                                            Color.newContrast
                                                .environment(\.colorScheme, .light)
                                                .frame(height: height / 2)
                                        }
                                        .frame(width: width, height: height)
                                        .clipShape(Circle())
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-45)) // Optional – für "Diamant"-Look
                                .overlay(
                                    Circle()
                                        .stroke(accentColorManager.accentColor == Color.newContrast ? Color.gray : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        selectedColor = Color.newContrast
                                        UserDefaultsManager.saveAccentColor(Color.newContrast)
                                        accentColorManager.updateAccentColor(to: Color.newContrast)
                                    }
                                }
                                */
                            }
                            .frame(height: 50)
                            .onAppear {
                                selectedColor = accentColorManager.accentColor
                            }
                        }
                        .cornerRadius(230)
                    }
                }
                Section(header: Text("FirstTab.ListLimit.Section")) {
                    Toggle("FirstTab.ListLimit.AlwaysLoadAll", isOn: $alwaysLoadAllFirstTabLists)

                    Stepper(value: customFirstTabListLimitBinding, in: 1...500, step: 1) {
                        HStack {
                            Text("FirstTab.ListLimit.CustomLimit")
                            Spacer()
                            Text("\(effectiveFirstTabLimit)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("FirstTab.ListLimit.UseDeviceDefault") {
                        customFirstTabListLimit = 0
                    }
                    .disabled(customFirstTabListLimit == 0)

                    Text("FirstTab.ListLimit.Footer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listSectionSpacing(8)
    }
    func changeIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Dieses Gerät unterstützt keine alternativen Icons.")
            return
        }
        if(iconName == "AppIcon"){
            UIApplication.shared.setAlternateIconName(nil)
        }
        else{
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error = error {
                    print("Fehler beim Wechseln des Icons: \(error.localizedDescription)")
                    
                } else {
                    print("Icon erfolgreich gewechselt!")
                }
            }
        }
    }
}
