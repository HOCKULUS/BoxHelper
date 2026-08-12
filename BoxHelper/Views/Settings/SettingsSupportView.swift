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
import TipKit

struct SettingsSupportView: View {
    var iconBackgroundColor: Color = .newMidnight
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var showFeedbackSheet = false

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
                            
                            Image(systemName: "questionmark.circle.fill")
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
                        Text("Support")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                    }
                    HStack {
                        Text("Join beta test to get early access to new features or get answers to your questions.")
                            .font(.subheadline) // Einheitliche Schriftgröße
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.bottom, 10)
                }
            }
            Button(action: {
                if let url = URL(string: "https://testflight.apple.com/join/S6NyJzEq") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Text("Join Beta Test")
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app.fill")
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
            }
            Button(action: {
                showFeedbackSheet = true
            }) {
                HStack {
                    Text("Feedback")
                        .foregroundStyle(Color.primary)
                        //.fontWeight(.bold)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app.fill")
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
            }
            NavigationLink(destination: SettingsFAQView()) {
                HStack {
                    Text("Frequently Asked Questions (FAQs)")
                        .foregroundColor(.primary)
                        .font(.system(size: 16))
                    Spacer()
                }
            }
            .navigationTitle(Text("Support"))
        }
        .listSectionSpacing(8)
        .sheet(isPresented: $showFeedbackSheet) {
            FeedbackReportSheet()
        }
    }
}
