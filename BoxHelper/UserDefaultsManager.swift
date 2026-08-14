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

    // Funktion zum Laden der Box-Daten basierend auf der UUID
    func loadBoxData(for uuid: UUID) -> MovingBox? {
        let boxes = loadBoxes() // Lade alle Boxen
        return boxes.first { $0.id == uuid } // Suche nach der Box mit der angegebenen UUID
    }
    
    // BoxDetailViewDirectLoad Beispiel zum Speichern einer Box
    func saveBoxData(_ box: MovingBox) {
        var boxes = loadBoxes() // Lade die existierenden Boxen

        // Wenn die Box bereits existiert, aktualisiere sie
        if let index = boxes.firstIndex(where: { $0.id == box.id }) {
            boxes[index] = box // Aktualisiere die Box
        } else {
            boxes.append(box) // Füge die neue Box hinzu
        }

        saveBoxes(boxes) // Speichere die aktualisierte Liste
    }
    
    // Funktion zum Speichern der MovingBox-Objekte
    func saveBoxes(_ boxes: [MovingBox]) {
        if let encoded = try? JSONEncoder().encode(boxes) {
            UserDefaults.standard.set(encoded, forKey: "movingBoxes")
            scheduleSpotlightReindexIfEnabled()
        }
    }
    
    // Funktion zum Speichern der Items
    func saveItems(_ items: [Items]) {
        do {
            let encoded = try JSONEncoder().encode(items) // Items in JSON-Daten umwandeln
            UserDefaults.standard.set(encoded, forKey: "itemsDatabase") // In UserDefaults speichern
            print("Items erfolgreich gespeichert.")
            scheduleSpotlightReindexIfEnabled()
        } catch {
            print("Fehler beim Speichern der Items: \(error)")
        }
    }
    
    // Funktion zum Speichern der Locations
    func saveLocations(_ locations: [Locations]) { //Dummer Fehler
        do {
            let encoded = try JSONEncoder().encode(locations) // Locations in JSON-Daten umwandeln
            UserDefaults.standard.set(encoded, forKey: "locationsDatabase") // In UserDefaults speichern
            print("Locations erfolgreich gespeichert.")
            scheduleSpotlightReindexIfEnabled()
        } catch {
            print("Fehler beim Speichern der Locations: \(error)")
        }
    }
    
    // Funktion zum Laden der MovingBox-Objekte
    func loadBoxes() -> [MovingBox] {
        if let data = UserDefaults.standard.data(forKey: "movingBoxes"),
           let boxes = try? JSONDecoder().decode([MovingBox].self, from: data) {
            return boxes
        }
        return []
    }
    
    // Funktion zum Laden der MovingBox-Objekte
    func loadItems() -> [Items] {
        if let data = UserDefaults.standard.data(forKey: "itemsDatabase"),
           let items = try? JSONDecoder().decode([Items].self, from: data) {
            return items
        }
        return []
    }
    
    // Funktion zum Speichern von Bilddaten im Dateisystem
    func saveImage(_ imageData: Data, withName name: String) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(name)
        
        do {
            try imageData.write(to: fileURL)
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
    
    // Löscht nur Mediendateien im Dokumentenverzeichnis und lässt Backups unangetastet.
    func clearDocumentsDirectory() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)

            // Backup-Dateien und Metadaten sollen bei "Alle Medien löschen" erhalten bleiben.
            let protectedFileNames: Set<String> = ["backupMetadata.json"]
            let mediaExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"]

            for file in files {
                let fileName = file.lastPathComponent
                let fileExtension = file.pathExtension.lowercased()

                if protectedFileNames.contains(fileName) || fileExtension == "zip" {
                    continue
                }

                // Nur Mediendateien löschen, andere Dateien im Dokumentenordner bleiben erhalten.
                if mediaExtensions.contains(fileExtension) {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Fehler beim Löschen der Dokumente: \(error)")
        }
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
        if UserDefaults.standard.object(forKey: "showLauchscreen4") != nil {
            return UserDefaults.standard.bool(forKey: "showLauchscreen4")
        } else {
            return true // Default fallback
        }
    }
    
    func saveLauchscreen(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "showLauchscreen4")
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
    func deleteImage(named fileName: String){
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)  // Den Dateipfad erstellen
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)  // Bild löschen
                print("Bild erfolgreich gelöscht: \(fileURL.path)")
            } else {
                print("Fehler: Datei existiert nicht: \(fileURL.path)")
            }
        } catch {
            print("Fehler beim Löschen des Bildes: \(error)")

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

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Fehler beim Duplizieren des Bildes: \(error)")
            return nil
        }
    }
    // Berechnet nur die Größe der Datenbanktabellen in UserDefaults.
    func getUserDefaultsSize() -> String {
        let keys = ["movingBoxes", "itemsDatabase", "locationsDatabase"]
        let totalSize = keys.reduce(0) { partialResult, key in
            partialResult + (UserDefaults.standard.data(forKey: key)?.count ?? 0)
        }
        return formatSize(totalSize)
    }

    // Löscht nur die in UserDefaults gespeicherten Datenbank-Tabellen.
    func clearDatabaseTables() {
        saveBoxes([])
        saveItems([])
        saveLocations([])
        scheduleSpotlightReindexIfEnabled()
    }

    // Setzt Einstellungen zurück, behält aber Datenbankinhalte.
    func resetSettingsKeepingDatabase() {
        let defaults = UserDefaults.standard

        // Datenbankwerte sichern, damit sie nach dem Reset erhalten bleiben.
        let movingBoxes = defaults.data(forKey: "movingBoxes")
        let items = defaults.data(forKey: "itemsDatabase")
        let locations = defaults.data(forKey: "locationsDatabase")

        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }

        // Gesicherte Tabellen zurückschreiben.
        if let movingBoxes {
            defaults.set(movingBoxes, forKey: "movingBoxes")
        }
        if let items {
            defaults.set(items, forKey: "itemsDatabase")
        }
        if let locations {
            defaults.set(locations, forKey: "locationsDatabase")
        }
    }

    // Löscht alle UserDefaults-Werte (inkl. Datenbanktabellen).
    func clearUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
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
