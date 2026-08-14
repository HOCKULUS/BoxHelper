import SwiftUI
import TipKit
import UIKit
import Foundation
import Zip
import MobileCoreServices
import UniformTypeIdentifiers
import StoreKit

private struct PromotedApp: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let url: URL
    let iconSetName: String // e.g. "AppIcon"
}


struct SettingsView: View {

    @EnvironmentObject var accentColorManager: AccentColorManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @Environment(\.requestReview) var requestReview
    //@Environment(\.windowScene) private var windowScene: UIWindowScene?
    @State private var showAppUpgrade = false
    //@State var sliderValue: Double =  105/*: UserDefaults.standard.double(forKey: "sliderValue"*/
    
    @State private var sliderIndex: Double = 0 // Index des Arrays
    //@State private var showImages: Bool = true //UserDefaults.standard.object(forKey: "showImages") == nil ? true : UserDefaults.standard.bool(forKey: "showImages")
    

    
    //@State private var selectedFile: URL?

    
    @State private var isImporting = false
    @State private var showLicenseView = false // Zum Anzeigen des Sheets
    @AppStorage("openBoxQRSettingsFromCreate") private var openBoxQRSettingsFromCreate: Bool = false
    @AppStorage("settingsPromotedAppsImpressionCount") private var settingsPromotedAppsImpressionCount: Int = 0
    @State private var navigateToBoxQRSettings = false
    @State private var launchIconTapCounter = 0
    
    struct ZipFile: Identifiable {
        var id = UUID()
        var name: String
        var path: String
        var date: String
        var size: String
    }
    
    let addOldIOSVersion = oldIOSVersion()
    private let settingsRainbowItemCount = 8
    
    private func settingsColor(at position: Int) -> Color {
        switch position {
        case 0:
            Color.newRed
        case 1:
            Color.newOrange
        case 2:
            Color.newYellow
        case 3:
            Color.newLime
        case 4:
            Color.newOlive
        case 5:
            Color.newBlue
        case 6:
            Color.newDarkPurple
        case 7:
            Color.newPink
        default:
            Color.gray
        }
    }
    
    private let promotedApps: [PromotedApp] = [
        PromotedApp(
            name: "Unloader",
            description: "Turn App Privacy Reports into action: see which apps talk to which domains, spot trackers in real time and push block/allow changes straight to your Pi-hole in seconds.",
            url: URL(string: "https://apps.apple.com/de/app/boxhelper/id6737223705")!,
            iconSetName: "unloader"
        ),
        PromotedApp(
            name: "SnapStackShrink",
            description: "Shrink hundreds of your Images to free up space. Perfect for anyone with a big photo collection and a small phone.",
            url: URL(string: "https://apps.apple.com/de/app/snapstackshrink/id6737287248")!,
            iconSetName: "SnapStackShrink"
        )
    ]

    private var shouldShowExpandedPromotedApps: Bool {
        settingsPromotedAppsImpressionCount < 5
    }

    private var moreAppsURL: URL? {
        URL(string: "https://apps.apple.com/de/developer/tobias-michael-rudolf-heine/id1775358445")
    }

    var body: some View {
        NavigationStack {
            Form {
                if #unavailable(iOS 18) {
                    //TipView(addOldIOSVersion)
                }
                if !promotedApps.isEmpty {
                    if shouldShowExpandedPromotedApps {
                        Section {
                            ForEach(promotedApps) { app in
                                Link(destination: app.url) {
                                    HStack(spacing: 12) {
                                        VStack {
                                            Image(app.iconSetName)
                                                .resizable()
                                                .frame(width: 52, height: 52)
                                                .scaledToFill()
                                            Spacer()
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(app.name)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            Text(app.description)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.forward.app.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    } else if let moreAppsURL {
                        Button(action: {
                            
                                UIApplication.shared.open(moreAppsURL)
                            
                        }) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                        .fill(.black)
                                        .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                    
                                    Image(systemName: "sparkles")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                        .foregroundColor(.newYellow)
                                }
                                .padding(.trailing, 10) // Mehr Abstand zum Text
                                Text("Explore more great apps")
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Image(systemName: "arrow.up.forward.app.fill")
                                    .foregroundStyle(Color.primary.opacity(0.5))
                            }
                            
                        }
                    }
                }
                Section {
                    NavigationLink(destination: CreateSettingsView(iconBackgroundColor: settingsColor(at: 0))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 0))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("TabView.Label.Create")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                    /*
                    NavigationLink(destination: SettingsBoxView(iconBackgroundColor: settingsColor(at: 1))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 1))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "square.grid.2x2.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Items")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            
                            Spacer()
                        }
                    }
                    .disabled(true)
                    .navigationTitle(Text("Settings"))
                    NavigationLink(destination: SettingsBoxView(iconBackgroundColor: settingsColor(at: 2))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 2))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "location.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Locations")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            
                            Spacer()
                        }
                    }
                    .disabled(true)
                    .navigationTitle(Text("Settings"))
                     */
                    NavigationLink(destination: SettingsImagesView(iconBackgroundColor: settingsColor(at: 1))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 1))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "photo.on.rectangle.angled")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Images")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                    NavigationLink(destination: SettingsStorageView(iconBackgroundColor: settingsColor(at: 2))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 2))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "externaldrive.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Storage & Backup")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                    NavigationLink(destination: SettingsInteractionAppearanceView(iconBackgroundColor: settingsColor(at: 3))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 3))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "slider.horizontal.3")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Bedienung & Darstellung")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                    NavigationLink(destination: SettingsAutomateView(iconBackgroundColor: settingsColor(at: 4))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 4))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "puzzlepiece.extension.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Automate")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                    /*
                    NavigationLink(destination: SettingsTipsView(iconBackgroundColor: settingsColor(at: 5))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(settingsColor(at: 5))
                                    .frame(width: 30, height: 30)

                                Image(systemName: "lightbulb.max.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10)

                            Text("Tips")
                                .foregroundColor(.primary)
                                .font(.system(size: 16))
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                     */
                    /*
                    NavigationLink(destination: SettingsRoadmapView()) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(Color.customBlueGreen)
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "map.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Roadmap")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                    */
                    NavigationLink(destination: SettingsLicenseView(iconBackgroundColor: settingsColor(at: 5))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 5))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "bookmark.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Licenses")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                    NavigationLink(destination: SettingsSupportView(iconBackgroundColor: settingsColor(at: 6))) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 6))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "questionmark.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Support")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                    
                    Button(action: {
                        if let url = URL(string: "https://apps.apple.com/de/app/boxhelper/id6737223705?action=write-review") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(settingsColor(at: 7))
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "star.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            Text("Write a review ♥")
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app.fill")
                                .foregroundStyle(Color.primary.opacity(0.5))
                        }
                        
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/HOCKULUS/BoxHelper") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(Color.black)
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image("GitHub_Invertocat_White")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            Text("Repository öffnen")
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app.fill")
                                .foregroundStyle(Color.primary.opacity(0.5))
                        }
                        
                    }
                }
                /*Section {
                    NavigationLink(destination: SettingsSupportView()) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(Color.NewBreeze)
                                    .frame(width: 30, height: 30) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "square.2.layers.3d.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 10) // Mehr Abstand zum Text
                            
                            Text("Automate")
                                .foregroundColor(.primary) // Passt sich dem Dark-/Light-Mode an
                                .font(.system(size: 16)) // Einheitliche Schriftgröße
                            Spacer()
                        }
                    }
                    .navigationTitle(Text("Settings"))
                }*/
                if #available(iOS 26.0, *) {
                    
                } else {
                    Spacer()
                        .listRowBackground(Color.clear)
                }
                
                Section {
                    VStack {
                        HStack {
                            Spacer()
                            Image("AppLogo")
                                .resizable()
                                .frame(width: 65, height: 65)
                                .onTapGesture {
                                    // Hidden shortcut: 5 taps replay the launch screen.
                                    launchIconTapCounter += 1
                                    if launchIconTapCounter >= 5 {
                                        launchIconTapCounter = 0
                                        NotificationCenter.default.post(name: .replayLaunchScreen, object: nil)
                                    }
                                }
                            Spacer()
                        }
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String{
                            Text("BoxHelper v\(version)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        else{
                            Text("BoxHelper")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        Text("© 2024-\(String(Calendar.current.component(.year, from: Date()))) HOCKULUS")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("Open Source")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("GNU AGPLv3")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("♥")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .scrollDismissesKeyboard(.immediately)
            .listSectionSpacing(8)
            .navigationDestination(isPresented: $navigateToBoxQRSettings) {
                CreateSettingsView(iconBackgroundColor: settingsColor(at: 0), scrollToQRCodeSection: true)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if openBoxQRSettingsFromCreate {
                    openBoxQRSettingsFromCreate = false
                    DispatchQueue.main.async {
                        navigateToBoxQRSettings = true
                    }
                }
            }
            .onChange(of: openBoxQRSettingsFromCreate) { _, newValue in
                guard newValue else { return }
                openBoxQRSettingsFromCreate = false
                DispatchQueue.main.async {
                    navigateToBoxQRSettings = true
                }
            }
        }
        .onAppear {
            if !promotedApps.isEmpty && settingsPromotedAppsImpressionCount < 5 {
                settingsPromotedAppsImpressionCount += 1
            }
        }
        .sheet(isPresented: $showAppUpgrade) {
            //UnlockFeatures(showAppUpgrade: $showAppUpgrade)
        }
    }
    func changeIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Dieses Gerät unterstützt keine alternativen Icons.")
            return
        }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Fehler beim Wechseln des Icons: \(error.localizedDescription)")
                
            } else {
                print("Icon erfolgreich gewechselt!")
            }
        }
    }
    /*
    private func showDocumentPicker() {
        let documentPicker = DocumentPicker(selectedFileURL: $selectedFile)
        let viewController = UIHostingController(rootView: documentPicker)

        // Hier musst du den aktuellen View Controller erhalten und den Picker präsentieren
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let topController = window.rootViewController {
               topController.present(viewController, animated: true)
        }
    }
    */
    func shareFile1(fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

        // Finde die aktuell aktive Szene und ihr Fenster
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let topVC = keyWindow.rootViewController {
            topVC.present(activityViewController, animated: true, completion: nil)
        }
    }
    func checkAndRequestAppReview() {
        let requestReviewKey = "requestAppReview"
        let lastRequestKey = "lastAppReviewRequestDate"
        let boxes = loadBoxes()
        // Mindestanzahl an Boxen erreicht und Bewertungsanforderung erlaubt
        if boxes.count >= 10 && (UserDefaults.standard.bool(forKey: requestReviewKey) == false) {
            let shown = true
            UserDefaults.standard.set(shown, forKey: requestReviewKey)
            
            // Bewertungsaufforderung nur, wenn seit der letzten Anfrage mindestens 30 Tage vergangen sind
            if let lastRequest = UserDefaults.standard.object(forKey: lastRequestKey) as? Date {
                let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
                if daysSinceLastRequest >= 30 {
                    requestAppReview()
                    UserDefaults.standard.set(Date(), forKey: lastRequestKey)
                }
            } else {
                // Erster Aufruf, wenn noch kein Datum gespeichert ist
                requestAppReview()
                UserDefaults.standard.set(Date(), forKey: lastRequestKey)
            }
        }
    }
func requestAppReview() {
        if #available(iOS 14.0, *) {
            // Die Bewertungsanfrage braucht die aktive Scene des aktuellen Fensters.
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                if #available(iOS 18.0, *) {
                    AppStore.requestReview(in: windowScene)
                } else {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
        } else {
            print("App-Bewertung ist nur ab iOS 14 mit einer Scene verfügbar.")
        }
    }
}
