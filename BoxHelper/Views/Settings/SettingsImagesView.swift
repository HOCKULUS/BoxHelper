//
//  SettingsBoxView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//


import SwiftUI
import UIKit

struct SettingsImagesView: View {
    var iconBackgroundColor: Color = .newFlower
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    @EnvironmentObject var accentColorManager: AccentColorManager
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    private enum Option: String, CaseIterable, Identifiable {
        case tiny, medium, large

        var id: String { self.rawValue }
    }
    @State private var selectedOption: Option = .medium
    @State var sliderValue2: Double = UserDefaults.standard.double(forKey: "sliderValue2") == 0 ? 500 : UserDefaults.standard.double(forKey: "sliderValue2")
    @State var sliderValue3: Double = UserDefaults.standard.double(forKey: "sliderValue3") == 0 ? 0.5 : UserDefaults.standard.double(forKey: "sliderValue3")
    @State private var smartZoom: Bool = UserDefaults.standard.object(forKey: "smartZoom") == nil ? true : UserDefaults.standard.bool(forKey: "smartZoom")
    @State private var selectedImageOrderOption: String = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var selectedImageCropType: String = UserDefaults.standard.string(forKey: "imageCropType") ?? "default"
    @State private var imagesTabThumbnailSize: Double = UserDefaults.standard.double(forKey: "imagesTabThumbnailSize") == 0 ? 120 : UserDefaults.standard.double(forKey: "imagesTabThumbnailSize")
    @State private var assignedImages: [URL] = []
    @State private var unassignedImages: [URL] = []
    @State private var pendingDeleteImageURL: URL?
    @State private var pendingDeleteScope: DeleteScope = .unassigned
    @State private var activeDeleteAlert: ActiveDeleteAlert?

    private enum DeleteScope {
        case assigned
        case unassigned
    }

    private enum ActiveDeleteAlert: String, Identifiable {
        case singleImage
        case allAssigned
        case allUnassigned

        var id: String { rawValue }
    }
    
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
                            
                            Image(systemName: "photo.on.rectangle.angled")
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
                        Text("Images")
                            .font(.system(size: 25, weight: .bold))
                        Spacer()
                    }
                    HStack {
                        Text("Change the way images are processed and displayed")
                            .font(.subheadline) // Einheitliche Schriftgröße
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.bottom, 10)
                }
            }
            /*
            Section(header: Text("Zoom Images"), footer: Text("Automatically selects the optimal section for the main subject. However, this may lead to unexpected results.")) {
                // Picker für Auflösung und Kompression
                Picker("", selection: $selectedImageCropType) {
                    Text("intelligent").tag("auto")
                    Text("default").tag("default")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedImageCropType, initial: false ) { oldValue, newValue in
                    switch newValue {
                        case "default":
                            UserDefaults.standard.set("default", forKey: "imageCropType")
                                selectedImageCropType = "default"
                        case "auto":
                            UserDefaults.standard.set("auto", forKey: "imageCropType")
                                selectedImageCropType = "auto"
                    default:
                        UserDefaults.standard.set("default", forKey: "imageCropType")
                            selectedImageCropType = "default"
                    }
                }
                .onAppear {
                    selectedImageCropType = UserDefaults.standard.string(forKey: "imageCropType") ?? "auto"
                }
            }
             */
            Section(header: Text("Settings.ImageProcessing"), footer: Text("Medium image quality is recommended. Tiny saves storage but sacrifices detail. Large offers high-detail images but can be storage-heavy and may impact performance.")) {
                // Picker für Auflösung und Kompression
                Picker("Resolution & Compression", selection: $selectedOption) {
                    Text("Tiny").tag(Option.tiny)
                    Text("Medium").tag(Option.medium)
                    Text("Large").tag(Option.large)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedOption, initial: false ) { oldValue, newValue in
                    switch newValue {
                    case .tiny:
                        withAnimation {
                            setImageSettings(resolution: 100, compression: 0.3)
                        }
                    case .medium:
                        withAnimation {
                            setImageSettings(resolution: 500, compression: 0.5)
                        }
                    case .large:
                        withAnimation {
                            setImageSettings(resolution: 1000, compression: 0.4)
                        }
                    }
                }
                .onAppear {
                    sliderValue2 = UserDefaultsManager.shared.loadSliderValue2()
                    sliderValue3 = UserDefaultsManager.shared.loadSliderValue3()
                    loadImageSettings()
                }
            }

            Section(header: Text("Image order"), footer: Text("Selecting ‘new → old’ will use the most recent image as the preview for the box")) {
                // Picker für Auflösung und Kompression
                Picker("Image order", selection: $selectedImageOrderOption) {
                    Text("new → old").tag("new")
                    Text("old → new").tag("old")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedImageOrderOption, initial: false ) { oldValue, newValue in
                    switch newValue {
                        case "new":
                            UserDefaults.standard.set("new", forKey: "imageSortingOption")
                            selectedImageOrderOption = "new"
                        case "old":
                            UserDefaults.standard.set("old", forKey: "imageSortingOption")
                            selectedImageOrderOption = "old"
                    default:
                        UserDefaults.standard.set("new", forKey: "imageSortingOption")
                        selectedImageOrderOption = "new"
                    }
                }
                .onAppear {
                    selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                }
            }
            /*Section(
                header: Text("Images Tab"),
                footer: Text("Controls how many images are shown per row in the new images tab.")
            ) {
                HStack {
                    Text("Image size")
                    Spacer()
                    Text("\(Int(imagesTabThumbnailSize))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $imagesTabThumbnailSize, in: 72...220, step: 4)
                    .tint(accentColorManager.accentColor)
                    .onChange(of: imagesTabThumbnailSize, initial: false) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "imagesTabThumbnailSize")
                    }
            }*/

            Section(
                header: Text("Zugeordnete Bilder"),
                footer: Text("Bilder, die aktuell mindestens einer Kiste, einem Gegenstand oder einem Standort zugeordnet sind.")
            ) {
                HStack {
                    Text("\(assignedImages.count) Bilder")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        shareFiles(urls: assignedImages)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(assignedImages.isEmpty)
                    .foregroundStyle(assignedImages.isEmpty ? Color.secondary : accentColorManager.accentColor)

                    Button(role: .destructive) {
                        activeDeleteAlert = .allAssigned
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(assignedImages.isEmpty)
                    .foregroundStyle(assignedImages.isEmpty ? Color.secondary : Color.red)
                }
                .listRowSeparator(Visibility.hidden)

                if assignedImages.isEmpty {
                    Text("Keine zugeordneten Bilder gefunden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(assignedImages, id: \.path) { imageURL in
                                imageCard(url: imageURL, scope: .assigned)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Section(
                header: Text("Unzugeordnete Bilder"),
                footer: Text("Diese Bilder liegen im App-Speicher, sind aber keinem Objekt zugeordnet.")
            ) {
                HStack {
                    Text("\(unassignedImages.count) Bilder")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        shareFiles(urls: unassignedImages)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(unassignedImages.isEmpty)
                    .foregroundStyle(assignedImages.isEmpty ? Color.secondary : accentColorManager.accentColor)

                    Button(role: .destructive) {
                        activeDeleteAlert = .allUnassigned
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(unassignedImages.isEmpty)
                    .foregroundStyle(assignedImages.isEmpty ? Color.secondary : Color.red)
                }
                .listRowSeparator(Visibility.hidden)

                if unassignedImages.isEmpty {
                    Text("Keine nicht zugeordneten Bilder gefunden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(unassignedImages, id: \.path) { imageURL in
                                imageCard(url: imageURL, scope: .unassigned)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .listSectionSpacing(8)
        .onAppear {
            reloadImageInventory()
        }
        .alert(item: $activeDeleteAlert) { alertType in
            switch alertType {
            case .singleImage:
                return Alert(
                    title: Text("Bild löschen?"),
                    message: Text("Das Bild wird aus dem App-Speicher entfernt."),
                    primaryButton: .destructive(Text("Löschen")) {
                        guard let imageURL = pendingDeleteImageURL else { return }
                        let shouldDetachReferences = pendingDeleteScope == .assigned
                        _ = deleteImages([imageURL], detachReferences: shouldDetachReferences)
                        pendingDeleteImageURL = nil
                        reloadImageInventory()
                    },
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            case .allAssigned:
                return Alert(
                    title: Text("Alle zugeordneten Bilder löschen?"),
                    message: Text("Alle Bilder werden gelöscht und aus Kisten, Gegenständen und Standorten entfernt."),
                    primaryButton: .destructive(Text("Alle löschen")) {
                        _ = deleteImages(assignedImages, detachReferences: true)
                        reloadImageInventory()
                    },
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            case .allUnassigned:
                return Alert(
                    title: Text("Alle nicht zugeordneten Bilder löschen?"),
                    message: Text("Alle nicht zugeordneten Bilder werden endgültig gelöscht."),
                    primaryButton: .destructive(Text("Alle löschen")) {
                        _ = deleteImages(unassignedImages, detachReferences: false)
                        reloadImageInventory()
                    },
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            }
        }
    }
    // Funktion zur Einstellung von Auflösung und Kompression
    private func setImageSettings(resolution: Int, compression: Double) {
        sliderValue2 = Double(resolution)
        sliderValue3 = compression

        UserDefaultsManager.shared.saveSliderValue2(Double(resolution))
        UserDefaultsManager.shared.saveSliderValue3(compression)
        UserDefaults.standard.set(selectedOption.rawValue, forKey: "selectedOption")
        //updateUserDefaultsSize() // Aktualisiert die Werte in UserDefaults
    }

    // Funktion zum Laden der Einstellungen aus dem Speicher
    private func loadImageSettings() {
        let resolution = UserDefaultsManager.shared.loadSliderValue2()
        let compression = UserDefaultsManager.shared.loadSliderValue3()

        sliderValue2 = resolution
        sliderValue3 = compression

        if resolution == 100 && compression == 0.3 {
            selectedOption = .tiny
        } else if resolution == 500 && compression == 0.5 {
            selectedOption = .medium
        } else if resolution == 1000 && compression == 0.4 {
            selectedOption = .large
        } else {
            selectedOption = .medium // Standardwert
        }
    }

    private func reloadImageInventory() {
        let report = buildImageInventoryReport()
        assignedImages = report.assignedImages
        unassignedImages = report.unassignedImages
    }

    private func imageCard(url: URL, scope: DeleteScope) -> some View {
        let cardWidth: CGFloat = 116

        return VStack(alignment: .leading, spacing: 2) {
            Group {
                if let previewImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.secondary.opacity(0.15)
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: cardWidth, height: 96)
            .clipShape(Rectangle())
            .padding(.top, -10)
            .padding(.horizontal, -10)

            /*Text(url.lastPathComponent)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: cardWidth - 20, alignment: .leading)
*/
            HStack {
                Spacer()
                Button {
                    shareFiles(urls: [url])
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                //.buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    pendingDeleteImageURL = url
                    pendingDeleteScope = scope
                    activeDeleteAlert = .singleImage
                } label: {
                    Image(systemName: "trash")
                }
                //.buttonStyle(.bordered)
                .controlSize(.small)

            }
            .padding(.top, 5)
        }
        .padding(10)
        .frame(width: cardWidth)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func shareFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }

        let activityViewController = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let topVC = keyWindow.rootViewController {
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = topVC.view
                popoverController.sourceRect = CGRect(
                    x: topVC.view.bounds.midX,
                    y: topVC.view.bounds.midY,
                    width: 1,
                    height: 1
                )
            }
            topVC.present(activityViewController, animated: true, completion: nil)
        }
    }
}
            
