//
//  UserDefaultsManager.swift
//  BoxHelper
//
//  Created by HOCKULUS on 07.11.24.
//
import SwiftUI
import UIKit
import ImageIO

class UserDefaultsManager {
    @MainActor static let shared = UserDefaultsManager()

    // Kompatibilitätsadapter für bestehende Views; Inventar gehört ausschließlich in SwiftData.
    @MainActor
    func loadBoxData(for uuid: UUID) -> MovingBox? {
        loadBoxes().first { $0.id == uuid }
    }

    @MainActor @discardableResult
    func saveBoxData(_ box: MovingBox) -> Bool {
        var boxes = loadBoxes()
        if let index = boxes.firstIndex(where: { $0.id == box.id }) { boxes[index] = box }
        else { boxes.append(box) }
        return saveBoxes(boxes)
    }

    @MainActor @discardableResult
    func saveBoxes(_ boxes: [MovingBox]) -> Bool {
        InventoryStorageState.shared.save { try InventoryPersistence.saveBoxes(boxes) }
    }

    @MainActor @discardableResult
    func saveItems(_ items: [Items]) -> Bool {
        InventoryStorageState.shared.save { try InventoryPersistence.saveItems(items) }
    }

    @MainActor @discardableResult
    func saveLocations(_ locations: [Locations]) -> Bool {
        InventoryStorageState.shared.save { try InventoryPersistence.saveLocations(locations) }
    }

    @MainActor
    func loadBoxes() -> [MovingBox] { InventoryStorageState.shared.readSnapshot().boxes }

    @MainActor
    func loadItems() -> [Items] { InventoryStorageState.shared.readSnapshot().items }

    @MainActor
    func loadLocations() -> [Locations] { InventoryStorageState.shared.readSnapshot().locations }

    // Funktion zum Speichern von Bilddaten im Dateisystem
    func saveImage(_ imageData: Data, withName name: String) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(name)
        
        do {
            // Große Bytes liegen außerhalb des kurzen Datei-Gates; erst der atomare
            // Rename bestätigt die lokale Version gegenüber laufenden Cloud-Plänen.
            try InventoryPhotoFileCoordinator.write(imageData, to: fileURL)
            // Dateioperationen dürfen im Hintergrund laufen; der Cloud-Abgleich gehört zum MainActor.
            Task { @MainActor in InventoryPersistence.mediaDidChange() }
            return fileURL
        } catch {
            print("Error saving image data: \(error)")
            return nil
        }
    }
    
    // Funktion zum Laden eines Bildes aus dem Dateisystem
    func loadImage(from fileName: String) -> UIImage? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)  // Den Dateinamen mit dem dynamischen Pfad kombinieren
        
        if let imageData = try? Data(contentsOf: fileURL) {  // Bilddaten laden
            return UIImage(data: imageData)
        } else {
            print("Fehler: Bilddaten konnten nicht geladen werden von: \(fileURL.path)")
            return nil
        }
    }

    // Lädt ein Bild bereits auf Zielgröße heruntergerechnet, damit Listen und Grids keine Originaldateien dekodieren.
    func loadThumbnail(from fileName: String, maxPixelSize: CGFloat) -> UIImage? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        let clampedPixelSize = max(1, Int(maxPixelSize.rounded(.up)))

        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            print("Fehler: Bildquelle konnte nicht erstellt werden von: \(fileURL.path)")
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: clampedPixelSize
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            print("Fehler: Thumbnail konnte nicht erstellt werden von: \(fileURL.path)")
            return nil
        }

        return UIImage(cgImage: thumbnail)
    }
    /*
    // Funktion zum Laden eines Bildes aus dem Dateisystem
    func loadImageAsThumpnail(from fileName: String) -> UIImage? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)  // Den Dateinamen mit dem dynamischen Pfad kombinieren
        
        if let imageData = try? Data(contentsOf: fileURL) {  // Bilddaten laden
            let uiImage = UIImage(data: imageData) ?? UIImage()
            uiImage.withRenderingMode(.alwaysTemplate)
            return UIImage(data: imageData)
        } else {
            print("Fehler: Bilddaten konnten nicht geladen werden von: \(fileURL.path)")
            return nil
        }
    }
     */
    // Funktion zum Laden mehrerer Bilder aus dem Dateisystem
    func loadImages(from fileNames: [String]) -> [UIImage?] {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Array zum Speichern der geladenen Bilder
        var images: [UIImage?] = []
        
        // Iteriere über die Dateinamen und lade jedes Bild
        for fileName in fileNames {
            let fileURL = documentsDirectory.appendingPathComponent(fileName)  // Kombiniere den Dateinamen mit dem Pfad
            
            if let imageData = try? Data(contentsOf: fileURL) {  // Lade die Bilddaten
                if let image = UIImage(data: imageData) {
                    images.append(image)  // Bild erfolgreich geladen, füge es zur Liste hinzu
                } else {
                    print("Fehler: Das Bild konnte nicht erstellt werden aus den Daten von: \(fileURL.path)")
                    images.append(nil)  // Bild konnte nicht erstellt werden, füge `nil` hinzu
                }
            } else {
                print("Fehler: Bilddaten konnten nicht geladen werden von: \(fileURL.path)")
                images.append(nil)  // Fehler beim Laden der Bilddaten, füge `nil` hinzu
            }
        }
        
        return images
    }
    
    // Berechnet nur die Größe der Bilddateien im Dokumentenverzeichnis.
    func getDocumentsSize() -> String {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mediaExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"]
            let mediaFiles = files.filter { mediaExtensions.contains($0.pathExtension.lowercased()) }

            let totalSize = mediaFiles.reduce(0) { (total, fileURL) -> Int in
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                return total + (attributes?[.size] as? Int ?? 0)
            }

            return formatSize(totalSize)
            
        } catch {
            print("Fehler beim Berechnen der Dokumentengröße: \(error)")
            return "0 KB"
        }
    }

    // Hilfsfunktion zur automatischen Anpassung der Größe (KB, MB, GB)
    func formatSize(_ sizeInBytes: Int) -> String {
        let sizeInKB = Double(sizeInBytes) / 1024.0
        if sizeInKB < 1024 {
            return String(format: "%.2f KB", sizeInKB)
        }

        let sizeInMB = sizeInKB / 1024.0
        if sizeInMB < 1024 {
            return String(format: "%.2f MB", sizeInMB)
        }

        let sizeInGB = sizeInMB / 1024.0
        return String(format: "%.2f GB", sizeInGB)
    }
    
    // Medienbereinigung entfernt auch ihre SwiftData-Referenzen; ZIP-Backups bleiben erhalten.
    @MainActor
    func clearDocumentsDirectory() {
        let report = buildImageInventoryReport()
        _ = deleteImages(report.assignedImages + report.unassignedImages, detachReferences: true)
    }
    
    // Funktion zum Speichern des Slider-Werts in UserDefaults
    func saveSliderValue(_ value: Double) {
        UserDefaults.standard.set(value, forKey: "sliderValue")
    }
    
    func loadSliderValue() -> Double {
        let savedValue = UserDefaults.standard.double(forKey: "sliderValue")
        return savedValue != 0 ? savedValue : 50
    }
    
    // Speichern und Laden von sliderValue2
    func saveSliderValue2(_ value: Double) {
        UserDefaults.standard.set(value, forKey: "sliderValue2")
    }

    func loadSliderValue2() -> Double {
        let savedValue = UserDefaults.standard.double(forKey: "sliderValue2")
        return savedValue != 0 ? savedValue : 500
    }

    // Speichern und Laden von sliderValue3
    func saveSliderValue3(_ value: Double) {
        UserDefaults.standard.set(value, forKey: "sliderValue3")
    }

    func loadSliderValue3() -> Double {
        let savedValue = UserDefaults.standard.double(forKey: "sliderValue3")
        return savedValue != 0 ? savedValue : 0.5
    }
    
    // Speichern und Laden von sliderValue3
    func saveSliderValue4(_ value: Int) {
        UserDefaults.standard.set(value, forKey: "sliderValue4")
    }

    func loadSliderValue4() -> Int {
        let savedValue = UserDefaults.standard.integer(forKey: "sliderValue4")
        return savedValue != 0 ? savedValue : 100
    }
    
    func saveShowImages(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showImages")
    }
    
    func loadShowImages() -> Bool {
        return UserDefaults.standard.bool(forKey: "showImages")
    }
    func saveShowTags(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showTags")
    }
    
    func loadShowTags() -> Bool {
        return UserDefaults.standard.bool(forKey: "showTags")
    }
    
    func saveBlockedTags(_ value: [String]) {
        UserDefaults.standard.set(value, forKey: "blockedTags")
    }
    
    func loadBlockedTags() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "blockedTags") ?? []
    }
    
    func saveShowDetails(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showDetails")
    }
    
    func loadShowDetails() -> Bool {
        return UserDefaults.standard.bool(forKey: "showDetails")
    }
    
    func saveShowDetailsLocation(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showDetailsLocation")
    }
    
    func loadShowDetailsLocation() -> Bool {
        return UserDefaults.standard.bool(forKey: "showDetailsLocation")
    }
    
    func saveShowQRCodeLogo(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showQRCodeLogo")
    }
    
    func loadShowQRCodeLogo() -> Bool {
        return UserDefaults.standard.bool(forKey: "showQRCodeLogo")
    }
    
    func saveShowQRCodeLocation(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showQRCodeLocation")
    }
    
    func loadShowQRCodeLocation() -> Bool {
        return UserDefaults.standard.bool(forKey: "showQRCodeLocation")
    }
    
    func saveShowQRCodeLocationColor(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showQRCodeLocationColor")
    }
    
    func loadShowQRCodeLocationColor() -> Bool {
        return UserDefaults.standard.bool(forKey: "showQRCodeLocationColor")
    }
    
    func saveShowQRCodeName(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showQRCodeName")
    }
    
    func loadShowQRCodeName() -> Bool {
        return UserDefaults.standard.bool(forKey: "showQRCodeName")
    }
    
    func saveShowDetailsItems(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showDetailsItems")
    }
    
    func loadShowDetailsItems() -> Bool {
        return UserDefaults.standard.bool(forKey: "showDetailsItems")
    }
    
    func saveShowDetailsItemsCounter(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showDetailsItemsCounter")
    }
    
    func loadShowDetailsItemsCounter() -> Bool {
        return UserDefaults.standard.bool(forKey: "showDetailsItemsCounter")
    }
    
    func saveShowDetailsTagCounter(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showDetailsTagCounter")
    }
    
    func loadShowDetailsTagCounter() -> Bool {
        return UserDefaults.standard.bool(forKey: "showDetailsTagCounter")
    }
    
    func saveShowDetailsImagesCounter(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showDetailsImagesCounter")
    }
    
    func loadShowDetailsImagesCounter() -> Bool {
        return UserDefaults.standard.bool(forKey: "showDetailsImagesCounter")
    }
    
    func saveShowDetailsDate1(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showDetailsDate1")
    }
    
    func loadShowDetailsDate1() -> Bool {
        return UserDefaults.standard.bool(forKey: "showDetailsDate1")
    }
    
    func saveShowDetailsDate2(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showDetailsDate2")
    }
    
    func loadShowDetailsDate2() -> Bool {
        return UserDefaults.standard.bool(forKey: "showDetailsDate2")
    }
    
    func saveBoxName(_ value: String) {
        UserDefaults.standard.set(value, forKey: "BoxName")
    }
    
    func loadBoxName() -> String? {
        if let boxName = UserDefaults.standard.string(forKey: "BoxName") {
            return boxName
        } else {
            return nil // Oder du lässt den Wert `nil` als Rückgabewert
        }
    }
    
    func saveShowBoxNameSheme(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showBoxNameSheme")
    }

    func loadShowBoxNameSheme() -> Bool {
        if UserDefaults.standard.object(forKey: "showBoxNameSheme") == nil {
            return true // Standardwert, falls nichts gespeichert
        }
        return UserDefaults.standard.bool(forKey: "showBoxNameSheme")
    }
    func saveUseBoxUUIDasBoxName(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "useBoxUUIDasBoxName")
    }
    func loadUseBoxUUIDasBoxName() -> Bool {
        if UserDefaults.standard.object(forKey: "useBoxUUIDasBoxName") == nil {
            return false // Standardwert, falls nichts gespeichert
        }
        return UserDefaults.standard.bool(forKey: "useBoxUUIDasBoxName")
    }
    
    func saveShowBoxNumberSheme(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showBoxNumberSheme")
    }

    func loadShowBoxNumberSheme() -> Bool {
        if UserDefaults.standard.object(forKey: "showBoxNumberSheme") == nil {
            return true // Standardwert, falls nichts gespeichert
        }
        return UserDefaults.standard.bool(forKey: "showBoxNumberSheme")
    }
    
    
    func savePressAndHold(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "pressAndHold")
    }

    func loadPressAndHold() -> Bool {
        if UserDefaults.standard.object(forKey: "pressAndHold") == nil {
            if #available(iOS 18, *) {
                return true
            } else {
                return false
            }
        }
        else {
            if #available(iOS 18, *) {
                return UserDefaults.standard.bool(forKey: "pressAndHold")
            } else {
                return false
            }
        }
    }
    
    init() {
        if #available(iOS 18, *) {
            UserDefaults.standard.register(defaults: ["pressAndHold": true])
        } else {
            UserDefaults.standard.register(defaults: ["pressAndHold": false])
        }
    }
    
    func savePageOnLauch(_ value: String) {
        UserDefaults.standard.set(value, forKey: "PageOnLauch")
    }
    
    func loadPageOnLauch() -> String {
        //print ("lastState: \(UserDefaults.standard.string(forKey: "lastState"))")
        if let lastState = UserDefaults.standard.string(forKey: "PageOnLauch") {
            return lastState
        }
        else {
            return "Last"
        }
    }
    
    func saveLastState(_ value: String) {
        print ("LastState: \(value)")
        UserDefaults.standard.set(value, forKey: "lastState")
    }
    
    func loadLastState() -> String {
        //print ("lastState: \(UserDefaults.standard.string(forKey: "lastState"))")
        if let lastState = UserDefaults.standard.string(forKey: "lastState") {
            return lastState
        }
        else {
            return ""
        }
    }
    
    func loadLauchscreen() -> Bool {
        LaunchPresentationPolicy.shouldShow()
    }

    func saveLauchscreen(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: LaunchPresentationPolicy.showKey)
    }

    func saveDynamicQRCode(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "dynamicQRCode")
    }

    func loadDynamicQRCode() -> Bool {
        if UserDefaults.standard.object(forKey: "dynamicQRCode") == nil {
            return false
        }
        return true
    }

    func saveCreateItemImageInputSource(_ value: String) {
        UserDefaults.standard.set(value, forKey: "createItemImageInputSource")
    }

    func loadCreateItemImageInputSource() -> String {
        if let value = UserDefaults.standard.string(forKey: "createItemImageInputSource"),
           !value.isEmpty {
            return value
        }
        return "camera"
    }

    func saveCreateNewItemInputAutofocusMode(_ value: String) {
        UserDefaults.standard.set(value, forKey: "createNewItemInputAutofocusMode")
    }

    func loadCreateNewItemInputAutofocusMode() -> String {
        if let value = UserDefaults.standard.string(forKey: "createNewItemInputAutofocusMode"),
           !value.isEmpty {
            return value
        }
        return "smart"
    }

    func saveCreateLastFocusedField(_ value: String) {
        UserDefaults.standard.set(value, forKey: "createLastFocusedField")
    }

    func loadCreateLastFocusedField() -> String {
        UserDefaults.standard.string(forKey: "createLastFocusedField") ?? "none"
    }

    func saveUseShortQRCodeURL(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "useShortQRCodeURL")
    }

    func loadUseShortQRCodeURL() -> Bool {
        if UserDefaults.standard.object(forKey: "useShortQRCodeURL") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "useShortQRCodeURL")
    }
    
    func saveQRCodeNumber(_ value: Int) {
        UserDefaults.standard.set(value, forKey: "qrCodeNumber")
    }

    func getQRCodeNumber() -> Int {
        let value = UserDefaults.standard.integer(forKey: "qrCodeNumber")
        return value > 0 ? value : 1
    }

    func saveQRCodeCopies(_ value: Int) {
        UserDefaults.standard.set(value, forKey: "qrCodeCopies")
    }

    func getQRCodeCopies() -> Int {
        let value = UserDefaults.standard.integer(forKey: "qrCodeCopies")
        return value > 0 ? value : 1
    }
    
    // Funktion zum Löschen eines Bildes aus dem Dateisystem
    @MainActor
    func deleteImage(named fileName: String){
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)  // Den Dateipfad erstellen
        
        var mediaChanged = false
        defer { if mediaChanged { InventoryPersistence.mediaDidChange() } }
        do {
            // Normale Fotos können bereits in CloudKit liegen, obwohl ihr Asset lokal
            // noch fehlt. Der native Auftrag gilt deshalb unabhängig von fileExists.
            if InventoryCloudMediaStore.isValidFilename(fileName) {
                try InventoryPersistence.deleteCloudPhotos([fileName])
                mediaChanged = true
            }
            if fileManager.fileExists(atPath: fileURL.path) {
                try InventoryPhotoFileCoordinator.remove(fileURL)
                mediaChanged = true
            }
        } catch {
            InventoryStorageState.shared.report(error)
        }
    }

    func duplicateImage(named fileName: String, to newFileName: String) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sourceURL = documentsDirectory.appendingPathComponent(fileName)
        let destinationURL = documentsDirectory.appendingPathComponent(newFileName)

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        var didChangeFiles = false
        defer {
            // Erst eine atomar bestätigte Kopie wird dem Cloud-Abgleich gemeldet.
            if didChangeFiles { Task { @MainActor in InventoryPersistence.mediaDidChange() } }
        }
        do {
            // Eine fehlgeschlagene Kopie erhält die bisherige Zieldatei. Der kurze
            // Rename-Gate verhindert, dass ein älterer Cloud-Download sie ersetzt.
            try InventoryPhotoFileCoordinator.copy(from: sourceURL, to: destinationURL)
            didChangeFiles = true
            return destinationURL
        } catch {
            print("Fehler beim Duplizieren des Bildes: \(error)")
            return nil
        }
    }
    // Die Größe umfasst den persistenten SwiftData-Store und seine SQLite-Nebendateien.
    @MainActor
    func getInventoryStorageSize() throws -> String {
        formatSize(try InventoryPersistence.storageSize())
    }

    // Ein einziger Commit verhindert, dass beim Leeren einzelne Tabellen zurückbleiben.
    @MainActor
    func clearDatabaseTables() throws {
        try InventoryPersistence.clearInventory()
    }

    // Erst eine eventuell ausstehende Migration abschließen, dann nur Einstellungen entfernen.
    @MainActor
    func resetSettingsKeepingDatabase() async throws {
        _ = try InventoryPersistence.snapshot()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            try await InventoryCloudSyncState.shared.resetSettingsPreference()
        }
        rebuildSpotlightIndex()
    }

    // Beim vollständigen Reset muss der SwiftData-Bestand vor dem Einstellungsreset geleert sein.
    @MainActor
    func clearUserDefaults() async throws {
        try InventoryPersistence.clearInventory()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            try await InventoryCloudSyncState.shared.resetSettingsPreference()
        }
        rebuildSpotlightIndex()
    }

    func clearUUIDViaURL() {
        UserDefaults.standard.set("", forKey: "uuidViaUrl")
    }
    
    // Speichern der Akzentfarbe als Hex-Wert
    static func saveAccentColor(_ color: Color) {
        let hexColor = color.toHex()
        UserDefaults.standard.set(hexColor, forKey: "accentColor")
    }
    
    // Abrufen der gespeicherten Akzentfarbe als Color
    static func loadAccentColor() -> Color {
        guard let hexColor = UserDefaults.standard.string(forKey: "accentColor") else {
            return .blue // Default-Farbe, falls keine gespeicherte Farbe existiert
        }
        return Color.fromHex(hex: hexColor)
    }
}
