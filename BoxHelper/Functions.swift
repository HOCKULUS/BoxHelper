//
//  functions.swift
//  ios-app-test
//
//  Created by HOCKULUS on 15.10.24.
//
import SwiftUI
import Zip
import Vision
import CoreML
import CoreSpotlight
import UniformTypeIdentifiers

func randomColor() -> Color {
    let red = Double.random(in: 0...1)
    let green = Double.random(in: 0...1)
    let blue = Double.random(in: 0...1)
    
    return Color(red: red, green: green, blue: blue)
}

func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss dd.MM.yyyy" // Gewünschtes Format
    return formatter.string(from: date)
}

func stringToColor(_ colorString: String) -> Color? {
    let components = colorString.split(separator: ",").map { CGFloat(Double($0) ?? 0) }
    if components.count == 3 {
        return Color(red: components[0], green: components[1], blue: components[2])
    }
    return nil
}

func colorToString(_ color: Color) -> String? {
    // Umwandlung von Color zu CGColor
    guard let components = color.cgColor?.components else {
        return nil // Rückgabe nil, wenn die Umwandlung nicht gelingt
    }
    
    // RGB-Werte extrahieren
    let red = components[0]
    let green = components[1]
    let blue = components[2]
    
    // Rückgabe der RGB-Werte als String
    return "\(red),\(green),\(blue)"
}

func loadCategories() -> [String] {
    var boxes: [MovingBox] = []
    boxes = loadBoxes()

    // Gruppiere die Boxen nach Kategorie und wähle die neueste Box für jede Kategorie
    let categoriesWithLatestDate = Dictionary(grouping: boxes, by: { $0.category })
        .mapValues { boxes in
            boxes.max(by: { $0.createdAt < $1.createdAt })?.createdAt ?? Date.distantPast
        }

    // Sortiere die Kategorien nach dem neuesten Änderungsdatum (absteigend)
    let sortedCategories = categoriesWithLatestDate
        .sorted(by: { $0.value > $1.value })
        .map { $0.key }

    return sortedCategories
}


func getCategorydColor(for category: String) -> String {
    // Lade alle Boxen aus dem Speicher
    let boxes = loadBoxes()
    
    // Filtere die Boxen nach der gegebenen Kategorie
    let filteredBoxes = boxes.filter { $0.category == category }
    
    // Falls es Boxen mit dieser Kategorie gibt, gib die Farbe der zuletzt erstellten Box zurück
    if let lastBox = filteredBoxes.last {
        return lastBox.color
    }
    
    // Falls keine Box mit dieser Kategorie existiert, gib eine Standardfarbe zurück
    return colorToString(randomColor()) ?? "" // bei der definition von movingbox wird ebenfalls eine farbe generiert
}

func generateBoxName() -> String {
    let currentID = UserDefaults.standard.integer(forKey: "lastBoxID") + 1
    return String(currentID)
}

func exportDataAndImages(progressHandler: ((Double) -> Void)? = nil) throws -> URL? {
    // Backups nur erstellen, wenn mindestens eine Tabelle Inhalte enthält.
    let movingBoxes = loadBoxes()
    let locations = loadLocations()
    let itemsDatabase = loadItems()
    guard !movingBoxes.isEmpty || !locations.isEmpty || !itemsDatabase.isEmpty else {
        return nil
    }

    // Dokumentenverzeichnis Pfad ermitteln
    let fileManager = FileManager.default
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
    }
    
    progressHandler?(0.05)

    // Alle Bilder im Dokumentenverzeichnis sammeln
    let imageURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "jpg" || $0.pathExtension == "png" }

    progressHandler?(0.15)

    // UserDefaults exportieren
    let userDefaultsDict = UserDefaults.standard.dictionaryRepresentation()
    
    // Konvertiere `UserDefaults`-Werte in JSON-kompatible Formate
    var filteredUserDefaultsDict: [String: Any] = [:]
    for (key, value) in userDefaultsDict {
        if value is Data || value is NSData {
            continue  // Überspringe `Data`-Werte, da sie nicht JSON-kompatibel sind
        } else if let dateValue = value as? Date {
            // Konvertiere `Date` in einen ISO8601-String
            let dateFormatter = ISO8601DateFormatter()
            filteredUserDefaultsDict[key] = dateFormatter.string(from: dateValue)
        } else {
            filteredUserDefaultsDict[key] = value
        }
    }
    /*
    let userDefaultsURL = documentsDirectory.appendingPathComponent("userDefaults.json")
    let jsonData = try JSONSerialization.data(withJSONObject: filteredUserDefaultsDict, options: .prettyPrinted)
    try jsonData.write(to: userDefaultsURL)
    */
     
    progressHandler?(0.30)

    // MovingBoxes exportieren
    let movingBoxesURL = documentsDirectory.appendingPathComponent("boxes.json")
    let movingBoxesData = try JSONEncoder().encode(movingBoxes)
    try movingBoxesData.write(to: movingBoxesURL)
    
    progressHandler?(0.45)

    // Locations exportieren
    let locationsURL = documentsDirectory.appendingPathComponent("locations.json")
    let locationsData = try JSONEncoder().encode(locations)
    try locationsData.write(to: locationsURL)
    
    progressHandler?(0.60)

    let itemsURL = documentsDirectory.appendingPathComponent("items.json")
    let itemsData = try JSONEncoder().encode(itemsDatabase)
    try itemsData.write(to: itemsURL)
    
    progressHandler?(0.70)

    // Zu zippenen Dateien festlegen (Bilder, UserDefaults und MovingBoxes)
    var filesToZip = imageURLs
    //filesToZip.append(userDefaultsURL)
    filesToZip.append(movingBoxesURL)
    filesToZip.append(locationsURL)
    filesToZip.append(itemsURL)

    // Zip-Datei erstellen
    let randomString = String(UUID().uuidString.prefix(8)) // z.B. "A1B2C3D4"
    let zipFilePath = documentsDirectory.appendingPathComponent("\(randomString).zip")
    try Zip.zipFiles(paths: filesToZip, zipFilePath: zipFilePath, password: nil, progress: { progress in
        // ZIP-Library liefert 0...1, wir mappen auf den letzten Prozessabschnitt.
        let mappedProgress = 0.70 + (progress * 0.30)
        progressHandler?(min(max(mappedProgress, 0.0), 1.0))
        print("Zip fortschritt: \(progress)")
    })
    progressHandler?(1.0)
    
    // Erfolgreicher Export
    return zipFilePath
}

func importDataAndImages(from zipURL: URL) throws {
    // Dokumentenverzeichnis Pfad ermitteln
    let fileManager = FileManager.default
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("Fehler: Dokumentenverzeichnis nicht gefunden")
        throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dokumentenverzeichnis nicht gefunden"])
    }
    print("Dokumentenverzeichnis gefunden: \(documentsDirectory.path)")
    
    // ZIP-Datei entpacken
    let tempDirectory: URL
    do {
        tempDirectory = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: documentsDirectory, create: true)
        print("Temporäres Verzeichnis erstellt: \(tempDirectory.path)")
    } catch {
        print("Fehler beim Erstellen des temporären Verzeichnisses: \(error.localizedDescription)")
        throw error
    }
    
    do {
        try Zip.unzipFile(zipURL, destination: tempDirectory, overwrite: true, password: nil, progress: { progress in
            print("Entpackungsfortschritt: \(progress)")
        })
        print("ZIP-Datei erfolgreich entpackt.")
    } catch {
        print("Fehler beim Entpacken der ZIP-Datei: \(error.localizedDescription)")
        throw error
    }
    
    // Alle Dateien im temporären Verzeichnis sammeln
    let unzippedFiles: [URL]
    do {
        unzippedFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        print("Entpackte Dateien: \(unzippedFiles)")
    } catch {
        print("Fehler beim Abrufen der entpackten Dateien: \(error.localizedDescription)")
        throw error
    }
    
    // Überprüfen, ob die erforderliche movingBoxes.json-Datei vorhanden ist
    guard unzippedFiles.contains(where: { $0.lastPathComponent == "movingBoxes.json" || $0.lastPathComponent == "boxes.json" }) else {
        print("Fehler: Die Datei movingBoxes.json wurde nicht gefunden.")
        // Temporäres Verzeichnis löschen
        do {
            try fileManager.removeItem(at: tempDirectory)
            print("Temporäres Verzeichnis gelöscht: \(tempDirectory.path)")
        } catch {
            print("Fehler beim Löschen des temporären Verzeichnisses: \(error.localizedDescription)")
        }
        throw NSError(domain: "ImportError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid File"])
    }
    print("MovingBoxes-Datei vorhanden.")

    // Bilder importieren (alle vorhandenen löschen und durch neue ersetzen)
    let imageFiles = unzippedFiles.filter { $0.pathExtension == "jpg" || $0.pathExtension == "png" }
    print("Gefundene Bilddateien: \(imageFiles)")
    
    // Vorhandene Bilder im Dokumentenverzeichnis löschen
    do {
        let existingImages = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jpg" || $0.pathExtension == "png" }
        print("Vorhandene Bilder im Dokumentenverzeichnis: \(existingImages)")
        
        for imageURL in existingImages {
            try fileManager.removeItem(at: imageURL)
            print("Bild gelöscht: \(imageURL.path)")
        }
    } catch {
        print("Fehler beim Löschen vorhandener Bilder: \(error.localizedDescription)")
        throw error
    }
    
    // Neue Bilder in das Dokumentenverzeichnis verschieben
    for imageURL in imageFiles {
        let destinationURL = documentsDirectory.appendingPathComponent(imageURL.lastPathComponent)
        do {
            try fileManager.moveItem(at: imageURL, to: destinationURL)
            print("Bild verschoben: \(imageURL.path) -> \(destinationURL.path)")
        } catch {
            print("Fehler beim Verschieben der Bilder: \(error.localizedDescription)")
            throw error
        }
    }
    
    // UserDefaults importieren
    if let userDefaultsFile = unzippedFiles.first(where: { $0.lastPathComponent == "userDefaults.json" }) {
        print("UserDefaults-Datei gefunden: \(userDefaultsFile.path)")
        do {
            let userDefaultsData = try Data(contentsOf: userDefaultsFile)
            let importedUserDefaults = try JSONSerialization.jsonObject(with: userDefaultsData, options: []) as? [String: Any] ?? [:]
            print("Importierte UserDefaults: \(importedUserDefaults)")
            
            // UserDefaults überschreiben
            let defaults = UserDefaults.standard
            for (key, value) in importedUserDefaults {
                defaults.set(value, forKey: key)
                print("UserDefault gesetzt: \(key) -> \(value)")
            }
            defaults.synchronize() // Speichern
        } catch {
            print("Fehler beim Importieren der UserDefaults: \(error.localizedDescription)")
            throw error
        }
    } else {
        print("Warnung: Keine UserDefaults-Datei gefunden.")
    }
    
    // MovingBoxes importieren
    if let movingBoxesFile = unzippedFiles.first(where: { $0.lastPathComponent == "movingBoxes.json" || $0.lastPathComponent == "boxes.json"}) {
        print("MovingBoxes-Datei gefunden: \(movingBoxesFile.path)")
        do {
            let movingBoxesData = try Data(contentsOf: movingBoxesFile)
            let importedBoxes = try JSONDecoder().decode([MovingBox].self, from: movingBoxesData)
            print("Importierte MovingBoxes: \(importedBoxes)")
            
            // MovingBoxes gnadenlos überschreiben
            saveBoxes(importedBoxes) // Annahme: Diese Funktion speichert die MovingBoxes
            print("MovingBoxes erfolgreich überschrieben.")
        } catch {
            print("Fehler beim Importieren der MovingBoxes: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Locations importieren
    if let locationsFile = unzippedFiles.first(where: { $0.lastPathComponent == "locations.json" || $0.lastPathComponent == "locations.json"}) {
        print("Locations-Datei gefunden: \(locationsFile.path)")
        do {
            let locationsData = try Data(contentsOf: locationsFile)
            let importedLocations = try JSONDecoder().decode([Locations].self, from: locationsData)
            print("Importierte Locations: \(importedLocations)")
            
            // MovingBoxes gnadenlos überschreiben
            saveLocations(importedLocations) // Annahme: Diese Funktion speichert die MovingBoxes
            print("Locations erfolgreich überschrieben.")
        } catch {
            print("Fehler beim Importieren der Locations: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Items importieren
    if let itemsFile = unzippedFiles.first(where: { $0.lastPathComponent == "items.json" || $0.lastPathComponent == "items.json"}) {
        print("Items-Datei gefunden: \(itemsFile.path)")
        do {
            let itemsData = try Data(contentsOf: itemsFile)
            let importedItems = try JSONDecoder().decode([Items].self, from: itemsData)
            print("Importierte Items: \(importedItems)")
            
            // MovingBoxes gnadenlos überschreiben
            saveItems(importedItems) // Annahme: Diese Funktion speichert die MovingBoxes
            print("Items erfolgreich überschrieben.")
        } catch {
            print("Fehler beim Importieren der Items: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Temporäres Verzeichnis löschen
    do {
        try fileManager.removeItem(at: tempDirectory)
        print("Temporäres Verzeichnis gelöscht: \(tempDirectory.path)")
    } catch {
        print("Fehler beim Löschen des temporären Verzeichnisses: \(error.localizedDescription)")
    }
    
    print("Daten und Bilder erfolgreich importiert und überschrieben.")
}
func mergeDataAndImages(from zipURL: URL) throws {
    // Dokumentenverzeichnis Pfad ermitteln
    let fileManager = FileManager.default
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("Fehler: Dokumentenverzeichnis nicht gefunden")
        throw NSError(domain: "MergeError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dokumentenverzeichnis nicht gefunden"])
    }
    print("Dokumentenverzeichnis gefunden: \(documentsDirectory.path)")
    
    // ZIP-Datei entpacken
    let tempDirectory: URL
    do {
        tempDirectory = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: documentsDirectory, create: true)
        print("Temporäres Verzeichnis erstellt: \(tempDirectory.path)")
    } catch {
        print("Fehler beim Erstellen des temporären Verzeichnisses: \(error.localizedDescription)")
        throw error
    }
    
    do {
        try Zip.unzipFile(zipURL, destination: tempDirectory, overwrite: true, password: nil, progress: { progress in
            print("Entpackungsfortschritt: \(progress)")
        })
        print("ZIP-Datei erfolgreich entpackt.")
    } catch {
        print("Fehler beim Entpacken der ZIP-Datei: \(error.localizedDescription)")
        throw error
    }
    
    // Alle Dateien im temporären Verzeichnis sammeln
    let unzippedFiles: [URL]
    do {
        unzippedFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        print("Entpackte Dateien: \(unzippedFiles)")
    } catch {
        print("Fehler beim Abrufen der entpackten Dateien: \(error.localizedDescription)")
        throw error
    }

    // Neue Bilder in das Dokumentenverzeichnis verschieben
    let imageFiles = unzippedFiles.filter { $0.pathExtension == "jpg" || $0.pathExtension == "png" }
    print("Gefundene Bilddateien: \(imageFiles)")
    
    for imageURL in imageFiles {
        let destinationURL = documentsDirectory.appendingPathComponent(imageURL.lastPathComponent)
        if !fileManager.fileExists(atPath: destinationURL.path) {
            // Nur Bilder verschieben, die noch nicht existieren
            do {
                try fileManager.moveItem(at: imageURL, to: destinationURL)
                print("Bild verschoben: \(imageURL.path) -> \(destinationURL.path)")
            } catch {
                print("Fehler beim Verschieben der Bilder: \(error.localizedDescription)")
                throw error
            }
        } else {
            print("Bild existiert bereits: \(imageURL.lastPathComponent)")
        }
    }
    
    // MovingBoxes importieren und Mergen
    if let movingBoxesFile = unzippedFiles.first(where: { $0.lastPathComponent == "movingBoxes.json" || $0.lastPathComponent == "boxes.json"}) {
        print("MovingBoxes-Datei gefunden: \(movingBoxesFile.path)")
        do {
            let movingBoxesData = try Data(contentsOf: movingBoxesFile)
            let importedBoxes = try JSONDecoder().decode([MovingBox].self, from: movingBoxesData)
            print("Importierte MovingBoxes: \(importedBoxes)")
            
            // Vorhandene MovingBoxes laden
            let existingBoxes = loadBoxes()

            // Zu Dictionary für schnellen Zugriff umwandeln
            var boxDict = Dictionary(uniqueKeysWithValues: existingBoxes.map { ($0.id, $0) })

            // Importierte Kisten integrieren
            for imported in importedBoxes {
                if let existing = boxDict[imported.id] {
                    // Wenn die importierte neuer ist, überschreiben
                    if imported.updatedAt > existing.updatedAt {
                        boxDict[imported.id] = imported
                    }
                } else {
                    // Neue Box – hinzufügen
                    boxDict[imported.id] = imported
                }
            }

            // Ergebnisliste
            let mergedBoxes = Array(boxDict.values)
            
            // Merged MovingBoxes speichern
            saveBoxes(mergedBoxes)
            print("MovingBoxes erfolgreich gemergt und gespeichert.")
        } catch {
            print("Fehler beim Importieren der MovingBoxes: \(error.localizedDescription)")
            throw error
        }
    } else {
        print("Warnung: Keine MovingBoxes-Datei gefunden.")
    }
    
    // Locations importieren
    if let locationsFile = unzippedFiles.first(where: { $0.lastPathComponent == "locations.json"}) {
        print("Locations-Datei gefunden: \(locationsFile.path)")
        do {
            let locationsData = try Data(contentsOf: locationsFile)
            let importedLocations = try JSONDecoder().decode([Locations].self, from: locationsData)
            print("Importierte Locations: \(importedLocations)")
            
            let existingLocations = loadLocations()

            // In Dictionary für schnellen Zugriff umwandeln
            var locationDict = Dictionary(uniqueKeysWithValues: existingLocations.map { ($0.id, $0) })

            // Importierte Locations integrieren
            for imported in importedLocations {
                if let existing = locationDict[imported.id] {
                    // Importierte Location ist aktueller → ersetzen
                    if imported.updatedAt > existing.updatedAt {
                        locationDict[imported.id] = imported
                    }
                    else {
                        locationDict[imported.id] = existing
                    }
                } else {
                    // Neue Location → hinzufügen
                    locationDict[imported.id] = imported
                }
            }

            // Ergebnisliste
            let mergedLocations = Array(locationDict.values)
            
            // Locations speichern
            saveLocations(mergedLocations)
            print("Locations erfolgreich zusammengefürt.")
        } catch {
            print("Fehler beim Zusammenführen der Locations: \(error.localizedDescription)")
            throw error
        }
    }
    else {
        print("Warnung: Keine locations-Datei gefunden.")
    }
    
    // Items importieren
    if let itemsFile = unzippedFiles.first(where: { $0.lastPathComponent == "items.json"}) {
        print("Items-Datei gefunden: \(itemsFile.path)")
        do {
            let itemsData = try Data(contentsOf: itemsFile)
            let importedItems = try JSONDecoder().decode([Items].self, from: itemsData)
            print("Importierte Items: \(importedItems)")
            
            let existingItems = loadItems()

            // Dictionary für schnellen Zugriff nach ID
            var itemDict = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })

            // Importierte Items integrieren
            for imported in importedItems {
                if let existing = itemDict[imported.id] {
                    // Importiertes Item ist aktueller → ersetzen
                    if imported.updatedAt > existing.updatedAt {
                        itemDict[imported.id] = imported
                    }
                } else {
                    // Neues Item → hinzufügen
                    itemDict[imported.id] = imported
                }
            }

            // Ergebnisliste
            let mergedItems = Array(itemDict.values)
            
            //Items speichern
            saveItems(mergedItems)
            print("Items erfolgreich zusammengefürt.")
        } catch {
            print("Fehler beim Zusammenführen der Items: \(error.localizedDescription)")
            throw error
        }
    }
    else {
        print("Warnung: Keine items-Datei gefunden.")
    }

    // Temporäres Verzeichnis löschen
    do {
        try fileManager.removeItem(at: tempDirectory)
        print("Temporäres Verzeichnis gelöscht: \(tempDirectory.path)")
    } catch {
        print("Fehler beim Löschen des temporären Verzeichnisses: \(error.localizedDescription)")
    }

    print("Daten und Bilder erfolgreich gemergt und gespeichert.")
}
/*
func importDataAndMerge(from zipURL: URL) throws {
    let fileManager = FileManager.default
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dokumentenverzeichnis nicht gefunden"])
    }
    
    // Temporäres Verzeichnis erstellen
    let tempDirectory = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: documentsDirectory, create: true)
    
    // ZIP-Datei entpacken
    do {
        try Zip.unzipFile(zipURL, destination: tempDirectory, overwrite: true, password: nil)
    } catch {
        print("Fehler beim Entpacken der ZIP-Datei: \(error.localizedDescription)")
        throw error
    }
    
    // `movingBoxes.json` in den entpackten Dateien finden
    let movingBoxesFile = tempDirectory.appendingPathComponent("movingBoxes.json")
    guard fileManager.fileExists(atPath: movingBoxesFile.path) else {
        throw NSError(domain: "ImportError", code: 2, userInfo: [NSLocalizedDescriptionKey: "invalid file"])
    }
    
    // Importierte Daten laden
    let importedData = try Data(contentsOf: movingBoxesFile)
    let importedBoxes = try JSONDecoder().decode([MovingBox].self, from: importedData)
    
    // Vorhandene Daten laden
    let existingBoxesData = try Data(contentsOf: documentsDirectory.appendingPathComponent("movingBoxes.json"))
    var existingBoxes = try JSONDecoder().decode([MovingBox].self, from: existingBoxesData)
    
    // Merging - Keine Duplikate, Neuere Datensätze bevorzugen
    var mergedBoxes = existingBoxes.reduce(into: [UUID: MovingBox]()) { dict, box in
        dict[box.id] = box
    }
    
    for newBox in importedBoxes {
        if let existingBox = mergedBoxes[newBox.id] {
            // Prüfen, ob der importierte Eintrag neuer ist
            if newBox.updatedAt > existingBox.updatedAt {
                mergedBoxes[newBox.id] = newBox
            }
        } else {
            // Neuer Eintrag, kein Duplikat
            mergedBoxes[newBox.id] = newBox
        }
    }
    
    // Array aus den gemergten Werten erstellen
    let finalBoxes = Array(mergedBoxes.values)
    
    // Bilddateien verarbeiten
    let imageFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "jpg" || $0.pathExtension == "png" }
    
    let existingImages = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "jpg" || $0.pathExtension == "png" }
    
    // Set bestehender Bildnamen, um Duplikate zu vermeiden
    let existingImageNames = Set(existingImages.map { $0.lastPathComponent })
    
    // Nur neue Bilder kopieren
    for imageURL in imageFiles {
        let imageName = imageURL.lastPathComponent
        if !existingImageNames.contains(imageName) {
            let destinationURL = documentsDirectory.appendingPathComponent(imageName)
            do {
                try fileManager.copyItem(at: imageURL, to: destinationURL)
                print("Bild kopiert: \(imageURL.path) -> \(destinationURL.path)")
            } catch {
                print("Fehler beim Kopieren der Bilder: \(error.localizedDescription)")
                throw error
            }
        } else {
            print("Bild bereits vorhanden, übersprungen: \(imageName)")
        }
    }
    
    // Aktualisierte Daten speichern
    saveBoxes(finalBoxes)
    
    // Temporäres Verzeichnis löschen
    try fileManager.removeItem(at: tempDirectory)
    
    print("Import und Merging erfolgreich abgeschlossen.")
}*/

func listZipFiles() -> [(name: String, date: String, size: String, path: String)]? {
    // FileManager für den Zugriff auf das Dateisystem
    let fileManager = FileManager.default
    
    // Pfad zum Documents-Verzeichnis
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
    }
    
    do {
        // Alle Dateien im Dokumentenverzeichnis auflisten
        let allFiles = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
        
        // Nur die Dateien mit der Endung ".zip" filtern
        let zipFiles = allFiles.filter { $0.pathExtension == "zip" }
        
        // Array zum Speichern der Dateiinformationen
        var zipFileList: [(name: String, date: String, size: String, path: String)] = []
        
        for zipFile in zipFiles {
            // Name der Datei
            let fileName = zipFile.lastPathComponent
            
            // Größe der Datei (in Bytes, konvertiert in MB oder KB)
            let fileSizeResourceValues = try zipFile.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = fileSizeResourceValues.fileSize {
                let fileSizeString: String
                if fileSize >= 1024 * 1024 {
                    fileSizeString = String(format: "%.2f MB", Double(fileSize) / (1024 * 1024))
                } else {
                    fileSizeString = String(format: "%.2f KB", Double(fileSize) / 1024)
                }
                
                //Datei Pfad
                let filePath = String(zipFile.path)
                // Datum der letzten Änderung der Datei
                let modificationDateResourceValues = try zipFile.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = modificationDateResourceValues.contentModificationDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "HH:mm:ss dd.MM.yyyy" // Deutsches Datumsformat
                    let formattedDate = dateFormatter.string(from: modificationDate)
                    
                    // Hinzufügen zur Liste
                    zipFileList.append((name: fileName, date: formattedDate, size: fileSizeString, path: filePath))
                }
            }
        }
        
        return zipFileList
    } catch {
        print("Fehler beim Auflisten der Zip-Dateien: \(error)")
        return nil
    }
}
func shouldRequestAppReview() -> Bool {
    let requestReviewKey = "requestAppReview"
    let lastRequestKey = "lastAppReviewRequestDate"
    let boxes = loadBoxes()
    
    // Mindestanzahl an Boxen erreicht und Bewertungsanforderung erlaubt
    if boxes.count >= 2 && (UserDefaults.standard.bool(forKey: requestReviewKey) == false) {
        // Bewertungsaufforderung nur, wenn seit der letzten Anfrage mindestens 30 Tage vergangen sind
        if let lastRequest = UserDefaults.standard.object(forKey: lastRequestKey) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
            if daysSinceLastRequest >= 30 {
                return true
            }
        } else {
            // Erster Aufruf, wenn noch kein Datum gespeichert ist
            return true
        }
    }
    return false
}
/*
 
 
 */
private func qrLocationTextColor(for backgroundColor: UIColor) -> UIColor {
    return isColorTooDark(color: Color(backgroundColor)) ? .white : .black
}

private func composeQRCodeImage(
    qrCodeImage: UIImage,
    text: String,
    standort: String,
    dynamicQRCode: Bool,
    showQRCodeLogo: Bool,
    showQRCodeLocation: Bool,
    showQRCodeName: Bool,
    locationPillColor: UIColor?,
    tinyQRCode: Bool,
    horizontalQRCodeLayout: Bool
) -> UIImage? {
    let qrScale: CGFloat = tinyQRCode ? 0.40 : 1.0
    let tinyDynamicTextScale: CGFloat = 0.78
    let tinyStaticTextScale: CGFloat = 0.90
    let logoScale: CGFloat = tinyQRCode ? 0.90 : 1.0
    let locationPillScale: CGFloat = tinyQRCode ? 0.55 : 1.0
    let locationPillHorizontalPadding: CGFloat = locationPillColor == nil ? 0 : (8 * locationPillScale)
    let locationPillVerticalPadding: CGFloat = locationPillColor == nil ? 0 : (3 * locationPillScale)
    let locationTextBottomInset: CGFloat = tinyQRCode ? 5 : 2
    let locationPillCornerRadius: CGFloat = tinyQRCode ? 4 : 8
    let verticalSpacing: CGFloat = 10
    let tinyHorizontalTextSafetyInset: CGFloat = (tinyQRCode && horizontalQRCodeLayout) ? 4 : 0

    let baseQRCodeSize = qrCodeImage.size
    let qrCodeSize = CGSize(width: baseQRCodeSize.width * qrScale, height: baseQRCodeSize.height * qrScale)

    func baseFontSize(for length: Int) -> CGFloat {
        switch length {
        case 0: return 0
        case 1...4: return 80
        case 5...7: return 44
        case 8...9: return 34
        case 10...12: return 24
        case 13...40: return 14
        default: return 6
        }
    }

    let tinyTextScale = tinyQRCode ? (dynamicQRCode ? tinyDynamicTextScale : tinyStaticTextScale) : 1.0
    let nameFontSize = (dynamicQRCode ? baseFontSize(for: text.count) : 24) * tinyTextScale
    let standortFontSize = (dynamicQRCode ? baseFontSize(for: standort.count) : 24) * tinyTextScale
    let logoFontSize: CGFloat = 24 * logoScale

    let textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.boldSystemFont(ofSize: nameFontSize),
        .foregroundColor: UIColor.black
    ]
    let standortForegroundColor = locationPillColor.map { qrLocationTextColor(for: $0) } ?? UIColor.black
    let standortFont = UIFont.boldSystemFont(ofSize: standortFontSize)
    let standortAttributes: [NSAttributedString.Key: Any] = [
        .font: standortFont,
        .foregroundColor: standortForegroundColor
    ]
    let logoAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: logoFontSize, weight: .light),
        .foregroundColor: UIColor.gray
    ]

    let logoText = "BoxHelper" as NSString
    let nameText = text as NSString
    let locationText = standort as NSString

    struct DrawElement {
        let size: CGSize
        let draw: (_ origin: CGPoint) -> Void
    }

    var details = [DrawElement]()

    if showQRCodeLogo {
        let size = logoText.size(withAttributes: logoAttributes)
        details.append(DrawElement(size: size) { origin in
            logoText.draw(at: origin, withAttributes: logoAttributes)
        })
    }

    if showQRCodeName {
        let size = nameText.size(withAttributes: textAttributes)
        details.append(DrawElement(size: size) { origin in
            nameText.draw(at: origin, withAttributes: textAttributes)
        })
    }

    if showQRCodeLocation {
        let bounding = locationText.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: standortAttributes,
            context: nil
        ).integral
        let textSize = CGSize(width: bounding.width, height: max(bounding.height, standortFont.lineHeight))
        let size = CGSize(
            width: textSize.width + (locationPillHorizontalPadding * 2) + (tinyHorizontalTextSafetyInset * 2),
            height: textSize.height + (locationPillVerticalPadding * 2) + locationTextBottomInset
        )
        details.append(DrawElement(size: size) { origin in
            if let locationPillColor {
                let paddedRect = CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
                locationPillColor.setFill()
                UIBezierPath(roundedRect: paddedRect, cornerRadius: locationPillCornerRadius).fill()
            }
            let textOrigin = CGPoint(
                x: origin.x + locationPillHorizontalPadding + tinyHorizontalTextSafetyInset,
                y: origin.y + locationPillVerticalPadding
            )
            locationText.draw(at: textOrigin, withAttributes: standortAttributes)
        })
    }

    if horizontalQRCodeLayout {
        let horizontalSpacing: CGFloat = 16
        let renderInset: CGFloat = tinyQRCode ? 5 : 2
        let detailsWidth = details.map { $0.size.width }.max() ?? 0
        let detailsHeight = details.reduce(CGFloat(0)) { $0 + $1.size.height } + max(0, CGFloat(details.count - 1)) * verticalSpacing
        let totalWidth = qrCodeSize.width + (details.isEmpty ? 0 : horizontalSpacing + detailsWidth)
        let totalHeight = max(qrCodeSize.height, detailsHeight)
        let canvasSize = CGSize(width: totalWidth + (renderInset * 2), height: totalHeight + (renderInset * 2))

        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0)
        defer { UIGraphicsEndImageContext() }

        let qrOriginY = (totalHeight - qrCodeSize.height) / 2
        qrCodeImage.draw(in: CGRect(origin: CGPoint(x: renderInset, y: renderInset + qrOriginY), size: qrCodeSize))

        if !details.isEmpty {
            let detailsOriginX = renderInset + qrCodeSize.width + horizontalSpacing
            var currentY = renderInset + (totalHeight - detailsHeight) / 2
            for element in details {
                let x = detailsOriginX + (detailsWidth - element.size.width) / 2
                element.draw(CGPoint(x: x, y: currentY))
                currentY += element.size.height + verticalSpacing
            }
        }
        guard let rendered = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        return rotate90CounterClockwise(rendered)
    } else {
        var elements = [DrawElement]()
        elements.append(DrawElement(size: qrCodeSize) { origin in
            qrCodeImage.draw(in: CGRect(origin: origin, size: qrCodeSize))
        })
        elements.append(contentsOf: details)

        let totalWidth = qrCodeSize.width
        let totalHeight = elements.reduce(CGFloat(0)) { $0 + $1.size.height } + max(0, CGFloat(elements.count - 1)) * verticalSpacing

        UIGraphicsBeginImageContextWithOptions(CGSize(width: totalWidth, height: totalHeight), false, 0)
        defer { UIGraphicsEndImageContext() }

        var currentY: CGFloat = 0
        for element in elements {
            let x = (totalWidth - element.size.width) / 2
            element.draw(CGPoint(x: x, y: currentY))
            currentY += element.size.height + verticalSpacing
        }
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

private func rotate90Clockwise(_ image: UIImage) -> UIImage {
    let newSize = CGSize(width: image.size.height, height: image.size.width)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
        guard let cgImage = image.cgImage else {
            image.draw(in: CGRect(origin: .zero, size: newSize))
            return
        }
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: newSize.width, y: 0)
        context?.rotate(by: .pi / 2)
        UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
            .draw(in: CGRect(origin: .zero, size: image.size))
    }
}

private func rotate90CounterClockwise(_ image: UIImage) -> UIImage {
    let newSize = CGSize(width: image.size.height, height: image.size.width)
    let renderer = UIGraphicsImageRenderer(size: newSize)

    return renderer.image { _ in
        guard let cgImage = image.cgImage else {
            image.draw(in: CGRect(origin: .zero, size: newSize))
            return
        }

        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0, y: newSize.height)
        context?.rotate(by: -.pi / 2)

        UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
            .draw(in: CGRect(origin: .zero, size: image.size))
    }
}

func generateQRCodeForBox(_ uuid: UUID, text: String, standort: String, standortColor: UIColor? = nil) -> UIImage? {
    let dynamicQRCode: Bool = UserDefaults.standard.object(forKey: "dynamicQRCode") == nil ? true : UserDefaults.standard.bool(forKey: "dynamicQRCode")
    let showQRCodeLogo: Bool = UserDefaults.standard.object(forKey: "showQRCodeLogo") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLogo")
    let showQRCodeLocation: Bool = UserDefaults.standard.object(forKey: "showQRCodeLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocation")
    let showQRCodeName: Bool = UserDefaults.standard.object(forKey: "showQRCodeName") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeName")
    let showQRCodeLocationColor: Bool = UserDefaults.standard.object(forKey: "showQRCodeLocationColor") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocationColor")
    let tinyQRCode: Bool = UserDefaults.standard.bool(forKey: "tinyQRCode")
    let horizontalQRCodeLayout: Bool = UserDefaults.standard.bool(forKey: "horizontalQRCodeLayout")
    let useShortQRCodeURL = UserDefaults.standard.object(forKey: "useShortQRCodeURL") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "useShortQRCodeURL")
    let locationPillColor = showQRCodeLocationColor ? standortColor : nil
    let qrCodeString = makeBoxQRCodeURLString(for: uuid, useShortURL: useShortQRCodeURL)

    guard let qrCodeImage = generateQRCodeImage(from: qrCodeString) else { return nil }

    return composeQRCodeImage(
        qrCodeImage: qrCodeImage,
        text: text,
        standort: standort,
        dynamicQRCode: dynamicQRCode,
        showQRCodeLogo: showQRCodeLogo,
        showQRCodeLocation: showQRCodeLocation,
        showQRCodeName: showQRCodeName,
        locationPillColor: locationPillColor,
        tinyQRCode: tinyQRCode,
        horizontalQRCodeLayout: horizontalQRCodeLayout
    )
}
func generateQRCodeForBoxPreview(
    _ uuid: UUID,
    text: String,
    standort: String,
    dynamicQRCode: Bool,
    showQRCodeLogo: Bool,
    showQRCodeLocation: Bool,
    showQRCodeName: Bool,
    showQRCodeLocationColor: Bool? = nil,
    showTinyQRCode: Bool? = nil,
    horizontalQRCodeLayout: Bool? = nil,
    useShortURL: Bool? = nil,
    standortColor: UIColor? = nil
) -> UIImage? {
    let shouldUseLocationColor = showQRCodeLocationColor
        ?? (UserDefaults.standard.object(forKey: "showQRCodeLocationColor") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "showQRCodeLocationColor"))
    let tinyQRCode = showTinyQRCode ?? UserDefaults.standard.bool(forKey: "tinyQRCode")
    let horizontalLayout = horizontalQRCodeLayout ?? UserDefaults.standard.bool(forKey: "horizontalQRCodeLayout")
    let shouldUseShortURL = useShortURL
        ?? (UserDefaults.standard.object(forKey: "useShortQRCodeURL") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "useShortQRCodeURL"))
    let locationPillColor = shouldUseLocationColor ? standortColor : nil
    let qrCodeString = makeBoxQRCodeURLString(for: uuid, useShortURL: shouldUseShortURL)

    guard let qrCodeImage = generateQRCodeImage(from: qrCodeString) else { return nil }

    return composeQRCodeImage(
        qrCodeImage: qrCodeImage,
        text: text,
        standort: standort,
        dynamicQRCode: dynamicQRCode,
        showQRCodeLogo: showQRCodeLogo,
        showQRCodeLocation: showQRCodeLocation,
        showQRCodeName: showQRCodeName,
        locationPillColor: locationPillColor,
        tinyQRCode: tinyQRCode,
        horizontalQRCodeLayout: horizontalLayout
    )
}
func layoutDescription(for value: Int) -> String {
    let columns = Int(ceil(sqrt(Double(value))))
    let rows = Int(ceil(Double(value) / Double(columns)))
    return "\(columns)x\(rows)"
}

// Erstellt den QR-Link entweder im alten Langformat oder im neuen ShortURL-Format.
func makeBoxQRCodeURLString(for uuid: UUID, useShortURL: Bool) -> String {
    if useShortURL {
        return "b0xh://\(shortBoxIdentifier(from: uuid))"
    }
    return "boxhelper://box/\(uuid.uuidString)"
}

// ShortURL-ID basiert auf den ersten 8 Zeichen der UUID.
func shortBoxIdentifier(from uuid: UUID) -> String {
    String(uuid.uuidString.uppercased().prefix(8))
}

// Hilfsfunktion zum Generieren des QR-Codes
func generateQRCodeImage(from string: String) -> UIImage? {
    let data = string.data(using: .ascii)
    
    if let filter = CIFilter(name: "CIQRCodeGenerator") {
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")
        
        if let outputImage = filter.outputImage {
            let scaleX = 300 / outputImage.extent.size.width
            let scaleY = 300 / outputImage.extent.size.height
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            return UIImage(ciImage: transformedImage)
        }
    }
    
    return nil
}

/*
func recognizeTextFromImages(_ images: [UIImage]) -> [String] {
    var recognizedTexts: [String] = []
    let blockedTags = UserDefaults.standard.stringArray(forKey: "showTags") ?? []
    let selectableValuesKey = UserDefaults.standard.double(forKey: "sliderValue4") //1 bis 6
    let selectableValues = [1, 5, 10, 25, 50, 100] //maximale Tags pro Bild wird mit selectableValuesKey
    for image in images {
        guard let cgImage = image.cgImage else {
            print("Fehler: UIImage konnte nicht in CGImage konvertiert werden.")
            continue
        }

        // Texterkennungs-Request erstellen
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("Fehler bei der Texterkennung: \(error.localizedDescription)")
                return
            }

            // Ergebnisse verarbeiten
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first {
                    recognizedTexts.append(topCandidate.string)
                }
            }
        }

        // Konfiguration des Requests
        //request.recognitionLanguages = ["cn"]
        request.recognitionLevel = .accurate

        // Texterkennung synchron durchführen
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Fehler bei der Bildanalyse: \(error.localizedDescription)")
        }
    }

    return recognizedTexts
}
 */
func recognizeTextFromImage(_ image: UIImage) -> [String] {
    var recognizedTexts: [String] = []

    guard let cgImage = image.cgImage else {
        print("Fehler: UIImage konnte nicht in CGImage konvertiert werden.")
        return recognizedTexts
    }

    // Texterkennungs-Request erstellen
    let request = VNRecognizeTextRequest { (request, error) in
        if let error = error {
            print("Fehler bei der Texterkennung: \(error.localizedDescription)")
            return
        }

        // Ergebnisse verarbeiten
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

        for observation in observations {
            if let topCandidate = observation.topCandidates(1).first {
                recognizedTexts.append(topCandidate.string)
            }
        }
    }

    // Konfiguration des Requests
    request.recognitionLevel = .accurate

    // Texterkennung synchron durchführen
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        print("Fehler bei der Bildanalyse: \(error.localizedDescription)")
    }

    return recognizedTexts
}

/*
func processImagesInBackground(images: [UIImage], completion: @escaping ([String]) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let group = DispatchGroup() // Synchronisationsgruppe für asynchrone Aufgaben
        var recognizedTexts: [String] = []

        // Gehe durch jedes Bild und verarbeite es im Hintergrund
        images.forEach { image in
            group.enter() // Eine Aufgabe wird gestartet

            // Texterkennung für jedes Bild im Hintergrund
            DispatchQueue.global(qos: .userInitiated).async {
                let texts = recognizeTextFromImage(image) // Texterkennung
                DispatchQueue.main.async {
                    recognizedTexts.append(contentsOf: texts) // Ergebnisse im Hauptthread sammeln
                    group.leave() // Aufgabe für dieses Bild abgeschlossen
                }
            }
        }

        // Sobald alle Aufgaben abgeschlossen sind
        group.notify(queue: .main) {
            // Alle Texte aus allen Bildern sind jetzt gesammelt
            let finalTexts = TagMagic(recognizedTexts) // Weiterverarbeitung der Texte
            completion(finalTexts) // Rückgabe der Ergebnisse über den Completion-Handler

            // Speichere die finalen Texte in der Instanz-Variable
            self.recognizedTextsArray = finalTexts
        }
    }
}
 */

func processImages(_ images: [UIImage], completion: @escaping @MainActor ([String]) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let recognizedTexts = automaticTags(from: images)

        // Ergebnisse sicher auf dem Hauptthread zurückgeben
        Task { @MainActor in
            completion(recognizedTexts)
        }
    }
}

func generateAutomaticTagsIfEnabled(from images: [UIImage], completion: @escaping @MainActor ([String]) -> Void) {
    let tagsEnabled = UserDefaults.standard.object(forKey: "showTags") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "showTags")

    guard tagsEnabled, !images.isEmpty else {
        Task { @MainActor in
            completion([])
        }
        return
    }

    processImages(images, completion: completion)
}

func generateAutomaticTagsIfEnabled(fromImagePaths imagePaths: [String], completion: @escaping @MainActor ([String]) -> Void) {
    let images = UserDefaultsManager().loadImages(from: imagePaths).compactMap { $0 }
    generateAutomaticTagsIfEnabled(from: images, completion: completion)
}

func automaticTags(from images: [UIImage]) -> [String] {
    var recognizedTexts: [String] = []

    let blockedTags = UserDefaults.standard.stringArray(forKey: "blockedTags") ?? []
    let maxTagsPerImage = UserDefaults.standard.integer(forKey: "sliderValue4") == 0 ? 100 : UserDefaults.standard.integer(forKey: "sliderValue4")

    for image in images {
        var cleanTexts: [String] = []
        let texts = TagMagic(recognizeTextFromImage(image))
        for text in texts where !blockedTags.contains(text) {
            cleanTexts.append(text)
        }

        for text in cleanTexts.prefix(maxTagsPerImage) where !recognizedTexts.contains(text) {
            recognizedTexts.append(text)
        }
    }

    return recognizedTexts
}

func automaticTags(fromImagePaths imagePaths: [String]) -> [String] {
    let images = UserDefaultsManager().loadImages(from: imagePaths).compactMap { $0 }
    return automaticTags(from: images)
}

func TagMagic(_ input: [String]) -> [String] {
    var result: Set<String> = [] // Set für einzigartige Werte
    
    // Zeichenmenge, die nur Buchstaben und Zahlen enthält
    let allowedCharacterSet = CharacterSet.alphanumerics
    
    for string in input {
        // Zeichenfolgen mit Leerzeichen oder Komma aufteilen
        let splitStrings = string.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        
        for substring in splitStrings {
            // Entfernen von Sonderzeichen (behalten nur alphanumerische Zeichen)
            let cleanString = substring.filter { allowedCharacterSet.contains($0.unicodeScalars.first!) }
            
            // Wenn die bereinigte Zeichenfolge eine Zahl enthält, überspringen
            if cleanString.rangeOfCharacter(from: .decimalDigits) != nil {
                continue // Ausschließen, wenn Zahlen enthalten sind
            }
            
            // Zeichenfolgen mit weniger als 4 Zeichen ausschließen
            if cleanString.count > 3 {
                // Alle Zeichen großschreiben
                let uppercasedString = cleanString.lowercased()
                result.insert(uppercasedString) // Nur einzigartige Werte hinzufügen
            }
        }
    }
    
    // Sortiere das Ergebnis alphabetisch, unter Ignorierung der Groß- und Kleinschreibung
    return Array(result).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

func saveBoxes(_ boxes: [MovingBox]) {
    if let encoded = try? JSONEncoder().encode(boxes) {
        UserDefaults.standard.set(encoded, forKey: "movingBoxes")
        scheduleSpotlightReindexIfEnabled()
    }
}

func loadBoxes() -> [MovingBox] {
    if let data = UserDefaults.standard.data(forKey: "movingBoxes"),
       let boxes = try? JSONDecoder().decode([MovingBox].self, from: data) {
        return boxes
    }
    return []
}

func saveItems(_ items: [Items]) {
    if let encoded = try? JSONEncoder().encode(items) {
        UserDefaults.standard.set(encoded, forKey: "itemsDatabase")
        scheduleSpotlightReindexIfEnabled()
    }
}

func loadItems() -> [Items] {
    if let data = UserDefaults.standard.data(forKey: "itemsDatabase"),
       let items = try? JSONDecoder().decode([Items].self, from: data) {
        return items
    }
    return []
}

func saveLocations(_ locations: [Locations]) {
    if let encoded = try? JSONEncoder().encode(locations) {
        UserDefaults.standard.set(encoded, forKey: "locationsDatabase")
        scheduleSpotlightReindexIfEnabled()
    }
}

private let spotlightIndexingEnabledKey = "spotlightIndexingEnabled"
private let spotlightDomainBoxes = "de.hockulus.boxhelper.spotlight.boxes"
private let spotlightDomainItems = "de.hockulus.boxhelper.spotlight.items"
private let spotlightDomainLocations = "de.hockulus.boxhelper.spotlight.locations"

func isSpotlightIndexingEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: spotlightIndexingEnabledKey)
}

func setSpotlightIndexingEnabled(_ isEnabled: Bool) {
    UserDefaults.standard.set(isEnabled, forKey: spotlightIndexingEnabledKey)

    if isEnabled {
        scheduleSpotlightReindexIfEnabled()
    } else {
        clearSpotlightIndex()
    }
}

func scheduleSpotlightReindexIfEnabled() {
    guard isSpotlightIndexingEnabled() else { return }
    DispatchQueue.main.async {
        rebuildSpotlightIndex()
    }
}

func clearSpotlightIndex() {
    CSSearchableIndex.default().deleteSearchableItems(
        withDomainIdentifiers: [spotlightDomainBoxes, spotlightDomainItems, spotlightDomainLocations]
    ) { error in
        if let error {
            print("Spotlight clear failed: \(error)")
        }
    }
}

func rebuildSpotlightIndex() {
    guard isSpotlightIndexingEnabled() else {
        clearSpotlightIndex()
        return
    }

    let boxes = loadBoxes()
    let items = loadItems()
    let locations = loadLocations()
    let locationsByID = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })
    let itemsByBoxID = Dictionary(grouping: items, by: { $0.box_uuid })

    var searchableItems: [CSSearchableItem] = []

    for box in boxes {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        let locationName = box.location_uuid.flatMap { locationsByID[$0]?.name } ?? ""
        let shortID = String(box.id.uuidString.prefix(8))
        let boxItemNames = (itemsByBoxID[box.id] ?? []).map(\.name)

        attributeSet.title = box.name.isEmpty ? "Box \(shortID)" : box.name
        attributeSet.displayName = attributeSet.title
        attributeSet.contentDescription = "Box \(shortID) \(locationName)"
        attributeSet.keywords = normalizedSpotlightKeywords(
            [box.name, locationName] + boxItemNames + (box.tags ?? [])
        )

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "box:\(box.id.uuidString)",
            domainIdentifier: spotlightDomainBoxes,
            attributeSet: attributeSet
        )
        searchableItems.append(searchableItem)
    }

    for item in items {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        let relatedBox = boxes.first(where: { $0.id == item.box_uuid })
        let relatedLocationName = relatedBox?.location_uuid.flatMap { locationsByID[$0]?.name } ?? ""

        attributeSet.title = item.name
        attributeSet.displayName = item.name
        attributeSet.contentDescription = relatedBox?.name ?? "Item"
        attributeSet.keywords = normalizedSpotlightKeywords(
            [item.name, relatedBox?.name ?? "", relatedLocationName]
        )

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "item:\(item.id.uuidString)",
            domainIdentifier: spotlightDomainItems,
            attributeSet: attributeSet
        )
        searchableItems.append(searchableItem)
    }

    for location in locations {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        attributeSet.title = location.name
        attributeSet.displayName = location.name
        attributeSet.contentDescription = "Location"
        attributeSet.keywords = [location.name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "location:\(location.id.uuidString)",
            domainIdentifier: spotlightDomainLocations,
            attributeSet: attributeSet
        )
        searchableItems.append(searchableItem)
    }

    CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
        if let error {
            print("Spotlight indexing failed: \(error)")
        }
    }
}

// Vereinheitlicht Keywords für Spotlight: trimmen, leere Werte entfernen und Duplikate vermeiden.
private func normalizedSpotlightKeywords(_ rawValues: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []

    for value in rawValues {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { continue }
        let key = normalized.lowercased()
        guard !seen.contains(key) else { continue }
        seen.insert(key)
        result.append(normalized)
    }

    return result
}

func loadLocations() -> [Locations] {
    if let data = UserDefaults.standard.data(forKey: "locationsDatabase"),
       let locations = try? JSONDecoder().decode([Locations].self, from: data) {
        return repairedLocationsIfNeeded(locations)
    }
    return repairedLocationsIfNeeded([])
}

func loadFirstLocations() -> [Locations] {
    if let data = UserDefaults.standard.data(forKey: "locationsDatabase"),
       let locations = try? JSONDecoder().decode([Locations].self, from: data) {
        return locations
    }
    return []
}

// Stellt sicher, dass jede in einer Kiste referenzierte `location_uuid` auf einen vorhandenen Standort zeigt.
// Falls ein Standort fehlt, wird ein Platzhalter mit derselben UUID angelegt und direkt gespeichert.
private func repairedLocationsIfNeeded(_ locations: [Locations]) -> [Locations] {
    let boxes = loadBoxes()
    let knownLocationIDs = Set(locations.map(\.id))
    let missingLocationIDs = Set(boxes.compactMap(\.location_uuid)).subtracting(knownLocationIDs)

    guard missingLocationIDs.isEmpty == false else {
        return locations
    }

    var repairedLocations = locations

    for missingID in missingLocationIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
        let placeholderColor = colorToString(randomColor())!

        let placeholderLocation = Locations(
            id: missingID,
            // Die UUID bleibt sichtbar, damit der Referenzursprung nachvollziehbar ist.
            name: String(missingID.uuidString.description.prefix(6)),
            color: placeholderColor,
            image: ""
        )

        repairedLocations.append(placeholderLocation)
    }

    saveLocations(repairedLocations)
    return repairedLocations
}

func isColorTooDark(color: Color) -> Bool {
    // Extrahiere die RGB-Werte aus der Farbe
    let uiColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    
    // Berechne die relative Helligkeit (Luminanz)
    // Formel: 0.299 * R + 0.587 * G + 0.114 * B
    let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
    // Schwellenwert für zu dunkle Farben
    return luminance < 0.5
}

/*
func recognizeObjectsInImages(_ images: [UIImage]) -> [[String]] {
    var recognizedObjects: [[String]] = []
    
    // Lade das vortrainierte Core ML-Modell
    guard let model = try? VNCoreMLModel(for: YOLOv3Tiny().model) else {
        print("Fehler beim Laden des Core ML-Modells.")
        return recognizedObjects
    }

    for image in images {
        guard let cgImage = image.cgImage else {
            print("Fehler: UIImage konnte nicht in CGImage konvertiert werden.")
            continue
        }

        // Objekterkennungs-Request erstellen
        let request = VNCoreMLRequest(model: model) { (request, error) in
            if let error = error {
                print("Fehler bei der Objekterkennung: \(error.localizedDescription)")
                return
            }

            var objectsInImage: [String] = []
            
            // Ergebnisse verarbeiten
            if let results = request.results as? [VNRecognizedObjectObservation] {
                for result in results {
                    if let label = result.labels.first?.identifier {
                        objectsInImage.append(label)
                    }
                }
            }
            
            recognizedObjects.append(objectsInImage)
        }

        // Bildanalyse durchführen
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Fehler bei der Bildanalyse: \(error.localizedDescription)")
        }
    }
    
    return recognizedObjects
}
*/

func listPicker(selection: Binding<String>) -> some View {
    let alwaysShowNavBar = UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
    let navBarPosition = UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
    let shouldRotateIcons = navBarPosition == "Left" || navBarPosition == "Right"
    
    if  #available(iOS 26, *) {
        return Picker("", selection: selection) {
            Image(systemName: "shippingbox.fill").tag("boxes")
                .rotationEffect(.degrees(shouldRotateIcons && alwaysShowNavBar ? -90 : 0))
            Image(systemName: "square.grid.2x2.fill").tag("items")
                .rotationEffect(.degrees(shouldRotateIcons && alwaysShowNavBar ? -90 : 0))
            Image(systemName: "location.fill").tag("locations")
                .rotationEffect(.degrees(shouldRotateIcons && alwaysShowNavBar ? -90 : 0))
            Image(systemName: "photo.stack.fill").tag("images")
                .rotationEffect(.degrees(shouldRotateIcons && alwaysShowNavBar ? -90 : 0))
        }
        .glassEffect()
        .pickerStyle(SegmentedPickerStyle())
        .background(
            RoundedRectangle(cornerRadius: 19)
                .fill(Color(.systemGray5).opacity(0))
                //iOS26 .glassEffect(isEnabled: alwaysShowNavBar)
                //.shadow(radius: !alwaysShowNavBar ? 0 : 0)
        )
        .shadow(radius: 0)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    } else {
        return Picker("", selection: selection) {
            Image(systemName: "shippingbox.fill").tag("boxes")
                .rotationEffect(.degrees(shouldRotateIcons && alwaysShowNavBar ? -90 : 0))
            Image(systemName: "square.grid.2x2.fill").tag("items")
                .rotationEffect(.degrees(shouldRotateIcons && alwaysShowNavBar ? -90 : 0))
            Image(systemName: "location.fill").tag("locations")
                .rotationEffect(.degrees(shouldRotateIcons && alwaysShowNavBar ? -90 : 0))
            Image(systemName: "photo.stack.fill").tag("images")
                .rotationEffect(.degrees(shouldRotateIcons && alwaysShowNavBar ? -90 : 0))
        }
        .pickerStyle(SegmentedPickerStyle())
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(.systemGray5))
        )
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }
}
func countAllImagesInAppStorage() -> Int {
    let fileManager = FileManager.default
    let allowedExtensions = ["jpg", "jpeg", "png"]
    
    do {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)

        let imageFiles = fileURLs.filter { url in
            allowedExtensions.contains(url.pathExtension.lowercased())
        }

        return imageFiles.count
    } catch {
        print("Fehler beim Durchsuchen des Verzeichnisses: \(error)")
        return 0
    }
}

func countAllZipFilesInAppStorage() -> Int {
    let fileManager = FileManager.default
    let zipExtension = "zip"
    
    do {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)

        let zipFiles = fileURLs.filter { url in
            url.pathExtension.lowercased() == zipExtension
        }

        return zipFiles.count
    } catch {
        print("Fehler beim Durchsuchen des Verzeichnisses: \(error)")
        return 0
    }
}
// Funktion zum Verarbeiten der eingehenden URL
func handleIncomingURL(_ url: URL) -> String {
    let resolution = resolveIncomingBoxURL(url, boxes: loadBoxes())
    return resolution.resolvedUUIDString ?? ""
}

struct IncomingBoxURLResolution {
    let resolvedUUIDString: String?
    let matchingBoxes: [MovingBox]
    let usedShortURL: Bool

    var hasMultipleMatches: Bool {
        matchingBoxes.count > 1
    }
}

private enum IncomingBoxIdentifier {
    case fullUUID(String)
    case shortPrefix(String)
}

// Unterstützt alte Links (boxhelper://box/<UUID>) und neue ShortURLs (b0xh://<PREFIX>).
func resolveIncomingBoxURL(_ url: URL, boxes: [MovingBox]) -> IncomingBoxURLResolution {
    guard let identifier = extractBoxIdentifier(from: url) else {
        return IncomingBoxURLResolution(resolvedUUIDString: nil, matchingBoxes: [], usedShortURL: false)
    }

    switch identifier {
    case .fullUUID(let uuidString):
        guard let uuid = UUID(uuidString: uuidString) else {
            return IncomingBoxURLResolution(resolvedUUIDString: nil, matchingBoxes: [], usedShortURL: false)
        }
        return IncomingBoxURLResolution(resolvedUUIDString: uuid.uuidString, matchingBoxes: [], usedShortURL: false)

    case .shortPrefix(let prefix):
        let normalizedPrefix = prefix.uppercased()
        let matches = boxes.filter { box in
            box.id.uuidString.uppercased().hasPrefix(normalizedPrefix)
        }

        if matches.count == 1, let singleMatch = matches.first {
            return IncomingBoxURLResolution(
                resolvedUUIDString: singleMatch.id.uuidString,
                matchingBoxes: matches,
                usedShortURL: true
            )
        }

        return IncomingBoxURLResolution(
            resolvedUUIDString: nil,
            matchingBoxes: matches,
            usedShortURL: true
        )
    }
}

// Funktion zum Extrahieren der Box-ID aus der URL
func extractBoxID(from url: URL) -> String? {
    guard let identifier = extractBoxIdentifier(from: url) else { return nil }
    switch identifier {
    case .fullUUID(let value), .shortPrefix(let value):
        return value
    }
}

private func extractBoxIdentifier(from url: URL) -> IncomingBoxIdentifier? {
    let scheme = url.scheme?.lowercased() ?? ""

    if scheme == "boxhelper" {
        if let fullUUID = extractLegacyUUID(from: url.absoluteString) {
            return .fullUUID(fullUUID)
        }
        return nil
    }

    if scheme == "b0xh" {
        let rawPrefix: String
        if let host = url.host, !host.isEmpty {
            rawPrefix = host
        } else {
            rawPrefix = String(url.path.drop(while: { $0 == "/" }))
        }

        let normalizedPrefix = rawPrefix
            .uppercased()
            .filter { "0123456789ABCDEF".contains($0) }

        guard normalizedPrefix.count == 8 else { return nil }
        return .shortPrefix(normalizedPrefix)
    }

    return nil
}

private func extractLegacyUUID(from urlString: String) -> String? {
    guard let lastSlashIndex = urlString.lastIndex(of: "/") else { return nil }
    let boxIDString = String(urlString[urlString.index(after: lastSlashIndex)...])
    return boxIDString
}
@MainActor func sendSupportEmail() {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    //let platform = UIDevice.current.model
    let hardwareInfo = UIDevice.current.localizedModel
    let osVersion = UIDevice.current.systemVersion
    //let screenResolution = "\(UIScreen.main.bounds.size.width) x \(UIScreen.main.bounds.size.height)"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let appLanguage = Locale.current.language.languageCode ?? "Unknown"
    let region = Locale.current.region?.identifier ?? "Unknown"
    let subject = "BoxHelper Feedback"
    let body = """
    
    
    
    <------
    - App-Version: \(appVersion)
    - Build-Nummer: \(buildNumber)
    - Gerät: \(hardwareInfo)
    - OS-Version: \(osVersion)
    - Sprache der App: \(appLanguage)-\(region)
    ------/
    """
        let mailTo = "appstore@hockulus.de"
        let emailString = "mailto:\(mailTo)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let emailURL = URL(string: emailString) {
            if UIApplication.shared.canOpenURL(emailURL) {
                UIApplication.shared.open(emailURL)
            } else {
                print("Mail app could not be opened.")
            }
        }
    }
func assignColorsToLocations(_ locations: [Locations]) -> [Locations] {
    let total = locations.count
    guard total > 0 else { return [] }
    
    return locations.enumerated().map { index, location in
        // Gleichmäßiger Winkel im Farbkreis (Hue: 0.0 - 1.0)
        let hue = Double(index) / Double(total)
        
        // Konvertieren in SwiftUI Color
        let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)
        
        var updatedLocation = location
        if let hexColor = colorToString(color) {
            updatedLocation.color = hexColor
        }
        return updatedLocation
    }
}

func assignColorsToLocations2(_ locations: [Locations]) -> [Locations] {
    let total = locations.count
    guard total > 0 else { return [] }

    return locations.enumerated().map { index, location in
        let fraction = Double(index) / Double(total) // Gleichmäßige Verteilung

        // Farbwinkel (Hue) gleichmäßig über 0...1 verteilt
        let hue = fraction

        // Dynamische Variation der Sättigung
        let saturation = 0.6 + 0.4 * sin(Double(index) * 0.5)
        let sat = min(max(saturation, 0.4), 1.0)

        // Helligkeit: Für gerade Indizes heller (+0.15), für ungerade wie vorher
        let baseBrightness = 0.7 + 0.2 * cos(Double(index) * 0.7)
        let brightness = (index % 2 == 0) ? min(baseBrightness + 0.25, 1.0) : baseBrightness
        let bri = min(max(brightness, 0.5), 1.0)

        let color = Color(hue: hue, saturation: sat, brightness: bri)

        var updatedLocation = location
        if let hex = colorToString(color) {
            updatedLocation.color = hex
        }
        return updatedLocation
    }
}

func assignColorsToLocations3(_ locations: [Locations]) -> [Locations] {
    let total = locations.count
    guard total > 0 else { return [] }

    // Goldener Schnitt (irrationale Zahl zur maximalen Verteilung im Kreis)
    let goldenRatio: Double = 0.61803398875
    var hue: Double = Double.random(in: 0..<1)

    return locations.enumerated().map { index, location in
        hue += goldenRatio
        hue.formTruncatingRemainder(dividingBy: 1.0)

        // Leichte Variation für visuelle Balance
        let saturation = 0.65 + 0.25 * sin(Double(index) * 1.3)
        let brightness = 0.75 + 0.2 * cos(Double(index) * 0.9)

        let sat = min(max(saturation, 0.4), 1.0)
        let bri = min(max(brightness, 0.5), 1.0)

        let color = Color(hue: hue, saturation: sat, brightness: bri)

        var updatedLocation = location
        if let hex = colorToString(color) {
            updatedLocation.color = hex
        }
        return updatedLocation
    }
}
func assignColorsToLocations4(_ locations: [Locations]) -> [Locations] {
    let total = locations.count
    guard total > 0 else { return [] }

    let startGray: CGFloat = 30.0 / 255.0   // dunkles Grau
    let endGray: CGFloat = 230.0 / 255.0    // sehr helles Grau
    let step = (endGray - startGray) / CGFloat(max(total - 1, 1))

    return locations.enumerated().map { index, location in
        let gray = startGray + step * CGFloat(index)
        
        var updatedLocation = location
        let color = Color(red: gray, green: gray, blue: gray)
        if let hex = colorToString(color) {
            updatedLocation.color = hex
        }
        return updatedLocation
    }
}
func assignColorsToLocations5(_ locations: [Locations]) -> [Locations] {
    let total = locations.count
    guard total > 0 else { return [] }
    
    let hueSteps = max(3, min(20, Int(sqrt(Double(total)) * 2)))
    
    //let saturationLevels: [Double] = [0.6, 0.8, 1.0]
    let brightnessLevels: [Double] = [0.7, 0.85, 1.0]
    
    // Alle möglichen Kombinationen bauen
    var colorVariants: [Color] = []
    for h in 0..<hueSteps {
        let hue = Double(h) / Double(hueSteps)
        //for sat in saturationLevels {
            for bright in brightnessLevels {
                colorVariants.append(Color(hue: hue, saturation: 1.0, brightness: bright))
            }
        //}
    }
    
    // Sicherstellen, dass wir mindestens so viele Farben haben wie Standorte
    while colorVariants.count < total {
        colorVariants += colorVariants
    }

    return locations.enumerated().map { index, location in
        let color = colorVariants[index % colorVariants.count]
        var updatedLocation = location
        if let hex = colorToString(color) {
            updatedLocation.color = hex
        }
        return updatedLocation
    }
}

func assignColorsToLocationsProtanopia(_ locations: [Locations]) -> [Locations] {
    let palette: [Color] = [
        Color(red: 0.05, green: 0.45, blue: 0.80),
        Color(red: 0.85, green: 0.60, blue: 0.15),
        Color(red: 0.40, green: 0.68, blue: 0.20),
        Color(red: 0.55, green: 0.38, blue: 0.75),
        Color(red: 0.15, green: 0.65, blue: 0.70),
        Color(red: 0.80, green: 0.75, blue: 0.20),
        Color(red: 0.30, green: 0.50, blue: 0.85),
        Color(red: 0.70, green: 0.45, blue: 0.25)
    ]
    return assignLocationColors(locations, using: palette)
}

func assignColorsToLocationsDeuteranopia(_ locations: [Locations]) -> [Locations] {
    let palette: [Color] = [
        Color(red: 0.07, green: 0.42, blue: 0.82),
        Color(red: 0.90, green: 0.62, blue: 0.12),
        Color(red: 0.52, green: 0.42, blue: 0.78),
        Color(red: 0.20, green: 0.60, blue: 0.76),
        Color(red: 0.76, green: 0.53, blue: 0.22),
        Color(red: 0.35, green: 0.56, blue: 0.88),
        Color(red: 0.87, green: 0.73, blue: 0.28),
        Color(red: 0.32, green: 0.69, blue: 0.62)
    ]
    return assignLocationColors(locations, using: palette)
}

func assignColorsToLocationsTritanopia(_ locations: [Locations]) -> [Locations] {
    let palette: [Color] = [
        Color(red: 0.82, green: 0.44, blue: 0.20),
        Color(red: 0.20, green: 0.65, blue: 0.30),
        Color(red: 0.75, green: 0.35, blue: 0.55),
        Color(red: 0.35, green: 0.55, blue: 0.25),
        Color(red: 0.62, green: 0.48, blue: 0.20),
        Color(red: 0.27, green: 0.70, blue: 0.52),
        Color(red: 0.88, green: 0.55, blue: 0.33),
        Color(red: 0.48, green: 0.62, blue: 0.33)
    ]
    return assignLocationColors(locations, using: palette)
}

func assignColorsToLocationsRandom(_ locations: [Locations]) -> [Locations] {
    locations.map { location in
        var updatedLocation = location
        let color = Color(
            hue: Double.random(in: 0...1),
            saturation: Double.random(in: 0.45...0.95),
            brightness: Double.random(in: 0.65...1.0)
        )
        if let hex = colorToString(color) {
            updatedLocation.color = hex
        }
        return updatedLocation
    }
}

private func assignLocationColors(_ locations: [Locations], using palette: [Color]) -> [Locations] {
    guard !palette.isEmpty else { return locations }
    return locations.enumerated().map { index, location in
        var updatedLocation = location
        let color = palette[index % palette.count]
        if let hex = colorToString(color) {
            updatedLocation.color = hex
        }
        return updatedLocation
    }
}
/*
@MainActor func setApplicationIconWithoutAlert(_ iconName: String?) {
    if UIApplication.shared.responds(to: #selector(getter: UIApplication.supportsAlternateIcons)) && UIApplication.shared.supportsAlternateIcons { // Mark 1
        
        typealias setAlternateIconNameClosure = @convention(c) (NSObject, Selector, NSString?, @escaping (NSError) -> ()) -> () // Mark 2.
        
        let selectorString = "_setAlternateIconName:completionHandler:" // Mark 3
        
        let selector = NSSelectorFromString(selectorString) // Mark 3
        let imp = UIApplication.shared.method(for: selector) // Mark 4
        let method = unsafeBitCast(imp, to: setAlternateIconNameClosure.self) // Mark 5
        method(UIApplication.shared, selector, iconName as NSString?, { _ in }) // Mark 6
    }
    else    {
        print(">>> setApplicationIconWithoutAlert: Unsupported")
    }
}
*/
func returnNavigationSymbol(_ selectedOption: String) -> String {
    switch selectedOption {
    case "boxes":
        return "shippingbox.fill"
    case "items":
        return "square.grid.2x2.fill"
    case "locations":
        return "location.fill"
    case "images":
        return "photo.stack.fill"
    default:
        return "table.fill"
    }
}
func returnNavigationLabel(_ selectedOption: String) -> String {
    switch selectedOption {
    case "boxes":
        return String(format: NSLocalizedString("TabView.Label.Boxes", comment: ""))
    case "items":
        return String(format: NSLocalizedString("Items", comment: ""))
    case "locations":
        return String(format: NSLocalizedString("Locations", comment: ""))
    case "images":
        return String(format: NSLocalizedString("Images", comment: ""))
    default:
        return "table.fill"
    }
}

func saveCreate<T: Codable>(_ value: T, forKey key: String) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: key)
    }
}

func loadCreate<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
    if let data = UserDefaults.standard.data(forKey: key),
       let object = try? JSONDecoder().decode(type, from: data) {
        return object
    }
    return nil
}

import Vision
import UIKit

func detectMotifAndCrop(image: UIImage, imageCropType: String) -> UIImage? {
    guard let cgImage = image.cgImage else {
        print("DEBUG: cgImage fehlt")
        return nil
    }
    if imageCropType == "auto" {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        do {
            try handler.perform([request])
            print("DEBUG: Vision Analyse erfolgreich")
        } catch {
            print("DEBUG: Vision Fehler \(error)")
            return nil
        }
        
        guard
            let observation = request.results?.first as? VNSaliencyImageObservation,
            let mainObject = observation.salientObjects?.first
        else {
            print("DEBUG: Kein Motiv erkannt")
            return nil
        }
        
        let b = mainObject.boundingBox
        print("DEBUG: BoundingBox normiert \(b)")
        
        let imgW = image.size.width
        let imgH = image.size.height
        
        let centerX = (b.origin.x + b.width / 2) * imgW
        let centerY = (1 - (b.origin.y + b.height / 2)) * imgH
        
        let rawW = b.width * imgW
        let rawH = b.height * imgH
        
        print("DEBUG: Raw Motivgröße \(rawW)x\(rawH)")
        
        let baseSize = max(rawW, rawH)
        
        let paddingFactor: CGFloat = 1.35
        var squareSize = baseSize * paddingFactor
        
        let minSize = min(imgW, imgH) * 0.35
        let maxSize = min(imgW, imgH) * 0.95
        
        squareSize = max(minSize, min(squareSize, maxSize))
        
        print("DEBUG: SquareSize nach Clamp \(squareSize)")
        
        var cropRect = CGRect(
            x: centerX - squareSize / 2,
            y: centerY - squareSize / 2,
            width: squareSize,
            height: squareSize
        )
        
        if cropRect.minX < 0 { cropRect.origin.x = 0 }
        if cropRect.minY < 0 { cropRect.origin.y = 0 }
        if cropRect.maxX > imgW { cropRect.origin.x = imgW - cropRect.width }
        if cropRect.maxY > imgH { cropRect.origin.y = imgH - cropRect.height }
        
        cropRect = cropRect.integral
        print("DEBUG: Final CropRect \(cropRect)")
        
        guard let croppedCG = cgImage.cropping(to: cropRect) else {
            print("DEBUG: Crop fehlgeschlagen")
            return nil
        }
        
        print("DEBUG: Crop abgeschlossen")
        return UIImage(
            cgImage: croppedCG,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }
    else {
        return image
    }
}
/*func detectMotifAndCropAsync(image: UIImage, completion: @escaping (UIImage?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        guard let cgImage = image.cgImage else {
            print("DEBUG: cgImage fehlt")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
            print("DEBUG: Vision Analyse erfolgreich")
        } catch {
            print("DEBUG: Vision Fehler \(error)")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        guard
            let observation = request.results?.first as? VNSaliencyImageObservation,
            let mainObject = observation.salientObjects?.first
        else {
            print("DEBUG: Kein Motiv erkannt")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let b = mainObject.boundingBox
        print("DEBUG: BoundingBox normiert \(b)")

        let imgW = image.size.width
        let imgH = image.size.height

        let centerX = (b.origin.x + b.width / 2) * imgW
        let centerY = (1 - (b.origin.y + b.height / 2)) * imgH

        let rawW = b.width * imgW
        let rawH = b.height * imgH
        let baseSize = max(rawW, rawH)

        let paddingFactor: CGFloat = 1.35
        var squareSize = baseSize * paddingFactor

        let minSize = min(imgW, imgH) * 0.35
        let maxSize = min(imgW, imgH) * 0.95
        squareSize = max(minSize, min(squareSize, maxSize))

        var cropRect = CGRect(
            x: centerX - squareSize / 2,
            y: centerY - squareSize / 2,
            width: squareSize,
            height: squareSize
        )

        if cropRect.minX < 0 { cropRect.origin.x = 0 }
        if cropRect.minY < 0 { cropRect.origin.y = 0 }
        if cropRect.maxX > imgW { cropRect.origin.x = imgW - cropRect.width }
        if cropRect.maxY > imgH { cropRect.origin.y = imgH - cropRect.height }

        cropRect = cropRect.integral
        print("DEBUG: Final CropRect \(cropRect)")

        guard let croppedCG = cgImage.cropping(to: cropRect) else {
            print("DEBUG: Crop fehlgeschlagen")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        print("DEBUG: Crop abgeschlossen")
        let croppedImage = UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
        
        DispatchQueue.main.async {
            completion(croppedImage)
        }
    }
}*/

func detectMotifAndCropAsync(image: UIImage, filename: String) async -> UIImage? {
    let thumbnailsFolder = FileManager.default.temporaryDirectory
    let thumbnailURL = thumbnailsFolder.appendingPathComponent(filename)
        .deletingPathExtension()
        .appendingPathExtension("thumbnail")
    
    if FileManager.default.fileExists(atPath: thumbnailURL.path),
       let data = try? Data(contentsOf: thumbnailURL),
       let cached = UIImage(data: data) {
        return cached
    }
    
    guard let cgImage = image.cgImage else { return nil }
    
    let request = VNGenerateAttentionBasedSaliencyImageRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage)
    do { try handler.perform([request]) } catch { return nil }
    
    guard
        let observation = request.results?.first as? VNSaliencyImageObservation,
        let mainObject = observation.salientObjects?.first
    else { return nil }
    
    let b = mainObject.boundingBox
    let imgW = image.size.width
    let imgH = image.size.height
    let centerX = (b.origin.x + b.width/2) * imgW
    let centerY = (1 - (b.origin.y + b.height/2)) * imgH
    let rawW = b.width * imgW
    let rawH = b.height * imgH
    let baseSize = max(rawW, rawH)
    
    let paddingFactor: CGFloat = 1.35
    let squareSize = max(min(imgW,imgH)*0.35, min(baseSize*paddingFactor, min(imgW,imgH)*0.95))
    
    var cropRect = CGRect(x: centerX-squareSize/2, y: centerY-squareSize/2, width: squareSize, height: squareSize)
    if cropRect.minX < 0 { cropRect.origin.x = 0 }
    if cropRect.minY < 0 { cropRect.origin.y = 0 }
    if cropRect.maxX > imgW { cropRect.origin.x = imgW - cropRect.width }
    if cropRect.maxY > imgH { cropRect.origin.y = imgH - cropRect.height }
    cropRect = cropRect.integral
    
    guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
    let croppedImage = UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
    
    if let jpegData = croppedImage.jpegData(compressionQuality: 0.9) {
        try? jpegData.write(to: thumbnailURL)
    }
    
    return croppedImage
}
