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
import Intents
import IntentsUI

struct ShortcutTile: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let gradient: LinearGradient
    let developer: String
    let fileName: String // Name der .shortcut Datei im Bundle
}

struct SettingsAutomateView: View {
    var iconBackgroundColor: Color = .newBreeze
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showAddToSiriSheet = false
    @State private var selectedSiriShortcut: SiriShortcutDefinition = .openAutomations
    @State private var showSiriError = false
    @State private var siriErrorMessage = ""
    let shortcuts: [ShortcutTile] = [
        ShortcutTile(
            title: "Create location with gps",
            iconName: "location.fill",
            gradient: LinearGradient(
                gradient: Gradient(colors: [.yellow, .red]),
                startPoint: .topTrailing,
                endPoint: .bottomLeading),
            developer: "HOCKULUS",
            fileName: "Create location with gps.shortcut"
        ),
        ShortcutTile(
            title: "Delete all unused locations",
            iconName: "trash.fill",
            gradient: LinearGradient(
                gradient: Gradient(colors: [.yellow, .red]),
                startPoint: .topTrailing,
                endPoint: .bottomLeading),
            developer: "HOCKULUS",
            fileName: "Delete all unused locations.shortcut"
        ),
        ShortcutTile(
            title: "Move all boxes to one location",
            iconName: "location.fill",
            gradient: LinearGradient(
                gradient: Gradient(colors: [.yellow, .red]),
                startPoint: .topTrailing,
                endPoint: .bottomLeading),
            developer: "HOCKULUS",
            fileName: "Move all boxes to one location.shortcut"
        ),
        ShortcutTile(
            title: "Move all items from one box to another",
            iconName: "rectangle.grid.2x2.fill",
            gradient: LinearGradient(
                gradient: Gradient(colors: [.yellow, .red]),
                startPoint: .topTrailing,
                endPoint: .bottomLeading),
            developer: "HOCKULUS",
            fileName: "Move all items from one box to another.shortcut"
        ),
        ShortcutTile(
            title: "Turn all box tags into items",
            iconName: "tag.fill",
            gradient: LinearGradient(
                gradient: Gradient(colors: [.yellow, .red]),
                startPoint: .topTrailing,
                endPoint: .bottomLeading),
            developer: "HOCKULUS",
            fileName: "Turn all box tags into items.shortcut"
        )
        // Weitere Tiles hinzufügen...
    ]

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
                            
                            Image(systemName: "puzzlepiece.extension.fill")
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
                        Text("Automate")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                    }
                    HStack {
                        Text("BoxHelper unlocks powerful accessibility and lets you automate your inventory like never before.")
                            .font(.subheadline) // Einheitliche Schriftgröße
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.bottom, 10)
                }
            }
            Section(header: Text("Automations")) {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(shortcuts) { shortcut in
                            Button(action: {
                                //print("Shortcut-Pfad:", Bundle.main.path(forResource: "NewBox", ofType: "shortcut") ?? "Nicht gefunden")
                                if let url = Bundle.main.url(forResource: shortcut.fileName, withExtension: nil) {
                                    shareFile(fileURL: url)
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: shortcut.iconName)
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        Spacer()
                                        /*Text(shortcut.developer)
                                            .font(.footnote)
                                            .foregroundStyle(Color.white.opacity(0.6))
                                        */
                                    }
                                    Spacer()
                                    HStack {
                                        Text(shortcut.title)
                                            .font(.headline)
                                            .lineLimit(2)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                }
                                .padding()
                                .frame(height: 120)
                                .background(shortcut.gradient)
                                .cornerRadius(20)
                                //.shadow(radius: 4)
                            }
                        }
                        Button(action: {
                            if let url = URL(string: "shortcuts://") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                HStack {
                                    Text("Create your own shortcuts")
                                        .font(.headline)
                                        .lineLimit(2)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                            }
                            
                            .padding()
                            .frame(height: 120)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.gray, .gray]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                          
                            .cornerRadius(20)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)
            /*
            Section(header: Text("Siri")) {
                ForEach(SiriShortcutDefinition.allCases) { shortcut in
                    Button {
                        selectedSiriShortcut = shortcut
                        showAddToSiriSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text(shortcut.title)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Öffnet den offiziellen iOS-Dialog „Zu Siri hinzufügen“.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareURL = shareURL {
                    ShareSheet(activityItems: [shareURL])
                }
            }
            .sheet(isPresented: $showAddToSiriSheet) {
                AddToSiriSheet(shortcut: makeShortcut(for: selectedSiriShortcut)) { errorMessage in
                    siriErrorMessage = errorMessage
                    showSiriError = true
                }
            }
            .alert("Siri", isPresented: $showSiriError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(siriErrorMessage)
            }
             */
        }
        .listSectionSpacing(8)
       
    }

    private func makeShortcut(for definition: SiriShortcutDefinition) -> INShortcut? {
        let activity = NSUserActivity(activityType: definition.activityType)
        activity.title = definition.shortTitle
        activity.suggestedInvocationPhrase = definition.suggestedPhrase
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = NSUserActivityPersistentIdentifier(definition.activityType)
        activity.userInfo = ["source": "settings_automation"]
        return INShortcut(userActivity: activity)
    }

    func shareFile(fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

        // Find the current active scene and its window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let topVC = keyWindow.rootViewController {
                // Ensure that it's iPad where the popover presentation happens
                if let popoverController = activityViewController.popoverPresentationController {
                    // Specify the source view or barButtonItem for the popover
                    popoverController.sourceView = topVC.view  // Use the root view or a specific button view
                    popoverController.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 1, height: 1) // Use a small area (adjust as needed)
                }
                // Present the activity view controller
                topVC.present(activityViewController, animated: true, completion: nil)
        }
    }
}

private enum SiriShortcutDefinition: String, CaseIterable, Identifiable {
    case openAutomations
    case createBox
    case findItem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAutomations:
            return String(localized: "Zu Siri hinzufügen: Automationen öffnen")
        case .createBox:
            return String(localized: "Zu Siri hinzufügen: Kiste erstellen")
        case .findItem:
            return String(localized: "Zu Siri hinzufügen: Gegenstand finden")
        }
    }

    var shortTitle: String {
        switch self {
        case .openAutomations: return String(localized: "Automationen öffnen")
        case .createBox: return String(localized: "Kiste erstellen")
        case .findItem: return String(localized: "Gegenstand finden")
        }
    }

    var activityType: String {
        "de.hockulus.boxhelper.\(rawValue)"
    }

    var suggestedPhrase: String {
        switch self {
        case .openAutomations:
            return String(localized: "BoxHelper Automationen")
        case .createBox:
            return String(localized: "Neue Kiste in BoxHelper")
        case .findItem:
            return String(localized: "Finde Gegenstand in BoxHelper")
        }
    }
}

private struct AddToSiriSheet: UIViewControllerRepresentable {
    let shortcut: INShortcut?
    let onError: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        guard let shortcut else {
            let controller = UIViewController()
            DispatchQueue.main.async {
                onError("Siri-Kurzbefehl konnte nicht erstellt werden.")
                dismiss()
            }
            return controller
        }

        let controller = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, INUIAddVoiceShortcutViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func addVoiceShortcutViewController(
            _ controller: INUIAddVoiceShortcutViewController,
            didFinishWith voiceShortcut: INVoiceShortcut?,
            error: Error?
        ) {
            dismiss()
        }

        func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
            dismiss()
        }
    }
}
