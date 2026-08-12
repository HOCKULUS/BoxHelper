//
//  SettingsAppdataView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 30.01.25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsStorageView: View {
    var iconBackgroundColor: Color = .newLime
    private enum FileImportMode {
        case zipBackup
        case csv
    }

    @EnvironmentObject var accentColorManager: AccentColorManager
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var userDefaultsSize: String = "0 KB" // Größe von UserDefaults
    @State private var documentsSize: String = "0 KB" // Größe des App-Dokumentenverzeichnisses
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var backupProgress: Double = 0
    @State private var backupProgressText = "Backup wird vorbereitet..."
    @State private var importProgressText = "Import wird vorbereitet..."
    @State private var isFileImporterPresented = false
    @State private var activeFileImportMode: FileImportMode = .zipBackup
    @State private var selectedFileURL: URL?
    @State private var count_boxes : Int = loadBoxes().count
    @State private var count_items : Int = loadItems().count
    @State private var count_locations : Int = loadLocations().count
    @State private var backupMetadataByName: [String: BackupMetadataEntry] = [:]
    @State var selectedZipFile: (name: String, date: String, size: String, path: String)? = ("NULL1.zip", "00.00.0000", "0 KB", "/")
    // Beispielhafte Daten für die Zip-Dateien (muss durch echte Daten ersetzt werden)
    @State var zipFiles: [(name: String, date: String, size: String, path: String)] = [
       ("NULL1.zip", "00.00.0000", "0 KB", "/"),
       ("NULL2.zip", "00.00.0000", "0 KB", "/")
   ]
    enum ActiveAlert {
        case applyData
        case mergeData
        case deleteFile
    }
    @State private var activeAlert: ActiveAlert? = nil
    @State private var showAlert: Bool = false
    @State var showAlert2 = false
    @State var alertMessage = ""
    @State private var showUserDefaultsAlert = false
    @State private var showResetSettingsAlert = false
    @State private var showDocumentsAlert = false
    @State private var isCSVExporterPresented = false
    @State private var csvDocument = CSVTextDocument(text: "")
    @State private var csvExportFileName = "export.csv"
    @State private var showCSVImportSheet = false
    @State private var csvImportText = ""
    @State private var csvImportFileName = ""
    @State private var csvImportHeaders: [String] = []
    @State private var csvImportRows: [[String]] = []
    @State private var csvImportModel: CSVImportModel = .boxes
    @State private var csvColumnMapping: [String: String] = [:]
    let addBackup = Backup()

    private var allowedImportContentTypes: [UTType] {
        switch activeFileImportMode {
        case .zipBackup:
            return [.zip]
        case .csv:
            return [.commaSeparatedText, .plainText]
        }
    }

    // Backup ist nur möglich, wenn mindestens eine der drei Tabellen Daten enthält.
    private var canCreateBackup: Bool {
        !loadBoxes().isEmpty || !loadItems().isEmpty || !loadLocations().isEmpty
    }

    var body: some View {
        ZStack {
            Form{
                Section {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 15, style: .continuous) // Abgerundete Ecken statt Kreis
                                    .fill(iconBackgroundColor)
                                    .frame(width: 70, height: 70) // Beibehaltung der Box-Größe
                                
                                Image(systemName: "externaldrive.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50) // Größeres Icon für bessere Sichtbarkeit
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 10)
                            Spacer()
                        }
                        .listSectionSeparator(.hidden)
                        HStack {
                            Spacer()
                            Text("Storage & Backup")
                                .foregroundColor(.primary)
                                .font(.system(size: 25, weight: .bold))
                            Spacer()
                        }
                        .listSectionSeparator(.hidden)
                        HStack {
                            Text("Export your data to share with others, restore a previous backup, or delete database and media.")
                                .font(.subheadline) // Einheitliche Schriftgröße
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.bottom, 10)
                    }
                }
                Section(header: Text("Settings.backupandimport")) {
                    if !zipFiles.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(zipFiles, id: \.name) { zipFile in
                                    backupCard(for: zipFile)
                                }
                            }
                        }
                        .listRowSeparator(Visibility.hidden)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    HStack {
                        VStack {
                            Button(action: {
                                activeFileImportMode = .zipBackup
                                isFileImporterPresented = true
                            }) {
                                HStack{
                                    Spacer()
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Settings.importbackup")
                                        .foregroundColor(selectedColor)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(isExporting)
                            if selectedFileURL != nil {
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .alignmentGuide(.listRowSeparatorLeading) { d in
                        d[.leading]
                    }
                    HStack {
                        // Button zum Exportieren aktueller Daten
                        Button(action: {
                            startBackupProcess()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "plus.square")
                                Text("Settings.createbackup")
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isExporting || !canCreateBackup)
                    }
                    .frame(maxWidth: .infinity)
                    .alignmentGuide(.listRowSeparatorLeading) { d in
                        d[.leading]
                    }
                }
                Section(header: Text("CSV")) {
                    Button {
                        exportBoxesCSV()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                            Text("Kisten exportieren")
                            Spacer()
                        }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { d in
                        d[.leading]
                    }
                    Button {
                        exportItemsCSV()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                            Text("Gegenstände exportieren")
                            Spacer()
                        }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { d in
                        d[.leading]
                    }
                    Button {
                        exportLocationsCSV()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                            Text("Standorte exportieren")
                            Spacer()
                        }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { d in
                        d[.leading]
                    }
                    Button {
                        activeFileImportMode = .csv
                        isFileImporterPresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.down")
                            Text("Importieren")
                            Spacer()
                        }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { d in
                        d[.leading]
                    }
                }
                
                Section(header: Text("STATISTICS")) {
                    HStack {
                        Text("Boxes: ")
                            .foregroundColor(Color.secondary)
                        Spacer()
                        Text(count_boxes.formatted())
                            .foregroundColor(Color.secondary)
                    }
                    HStack {
                        Text("Items: ")
                            .foregroundColor(Color.secondary)
                        Spacer()
                        Text(count_items.formatted())
                            .foregroundColor(Color.secondary)
                    }
                    HStack {
                        Text("Locations: ")
                            .foregroundColor(Color.secondary)
                        Spacer()
                        Text(count_locations.formatted())
                            .foregroundColor(Color.secondary)
                    }
                    HStack {
                        Text("Images: ")
                            .foregroundColor(Color.secondary)
                        Spacer()
                        Text("\(countAllImagesInAppStorage())")
                            .foregroundColor(Color.secondary)
                    }
                    HStack {
                        Text("Zip-Files: ")
                            .foregroundColor(Color.secondary)
                        Spacer()
                        Text("\(countAllZipFilesInAppStorage())")
                            .foregroundColor(Color.secondary)
                    }
                }

                Section(header: Text("Settings.database")) {
                    // Anzeige der NSUserDefaults-Größe
                    HStack {
                        Text("Settings.size")
                            .foregroundColor(Color.secondary)
                        Spacer()
                        Text(userDefaultsSize)
                            .foregroundColor(Color.secondary)
                    }
                    
                    // Button zum Leeren der Datenbanktabellen (Boxes, Items, Locations).
                    Button(action: {
                        showUserDefaultsAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Settings.deleteData")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .alert(isPresented: $showUserDefaultsAlert) {
                        Alert(
                            title: Text("Settings.deleteData2"),
                            message: Text("Settings.deleteData3"),
                            primaryButton: .destructive(Text("Settings.delete")) {
                                UserDefaultsManager.shared.clearDatabaseTables()
                                count_boxes = loadBoxes().count
                                count_items = loadItems().count
                                count_locations = loadLocations().count
                                updateUserDefaultsSize()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                
                Section(header: Text("Settings.Media")) {
                    // Anzeige der Größe des Dokumentenverzeichnisses
                    HStack {
                        Text("Settings.size")
                            .foregroundColor(Color.secondary)
                        Spacer()
                        Text(documentsSize)
                            .foregroundColor(Color.secondary)
                    }
                    
                    // Button zum Löschen der Dateien im Dokumentenverzeichnis
                    Button(action: {
                        showDocumentsAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Settings.deleteMedia")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .alert(isPresented: $showDocumentsAlert) {
                        Alert(
                            title: Text("Settings.deleteMedia2"),
                            message: Text("Settings.deleteMedia3"),
                            primaryButton: .destructive(Text("Settings.delete")) {
                                UserDefaultsManager.shared.clearDocumentsDirectory()
                                updateDocumentsSize() // Größe nach dem Löschen aktualisieren
                                refreshZipFilesAndMetadata()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                Section{
                    Spacer()
                }
                .listRowBackground(Color.clear)
                Section {
                    // Zusätzlicher Punkt zum Zurücksetzen aller Einstellungen.
                    Button(action: {
                        showResetSettingsAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Text("Einstellungen zurücksetzen")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .alert(isPresented: $showResetSettingsAlert) {
                        Alert(
                            title: Text("Einstellungen zurücksetzen"),
                            message: Text("Alle Einstellungen werden auf Standardwerte gesetzt."),
                            primaryButton: .destructive(Text("Zurücksetzen")) {
                                UserDefaultsManager.shared.resetSettingsKeepingDatabase()
                                accentColorManager.updateAccentColor(to: UserDefaultsManager.loadAccentColor())
                                updateUserDefaultsSize()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .onAppear {
                updateUserDefaultsSize()
                updateDocumentsSize()
                refreshZipFilesAndMetadata()
            }
            .alert(isPresented: $showAlert2) {
                Alert(
                    title: Text("Info"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Schließen"))
                )
            }
            .fileExporter(
                isPresented: $isCSVExporterPresented,
                document: csvDocument,
                contentType: .plainText,
                defaultFilename: csvExportFileName
            ) { result in
                if case .failure(let error) = result {
                    alertMessage = "CSV Export fehlgeschlagen: \(error.localizedDescription)"
                    showAlert2 = true
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: allowedImportContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showCSVImportSheet) {
                CSVImportMappingSheet(
                    selectedModel: $csvImportModel,
                    fileName: csvImportFileName,
                    headers: csvImportHeaders,
                    rows: csvImportRows,
                    mapping: $csvColumnMapping
                ) {
                    applyCSVImport()
                }
            }
            .listSectionSpacing(8)
            .disabled(isExporting || isImporting)

            if isExporting {
                backupProgressOverlay
            }
            if isImporting {
                importProgressOverlay
            }
        }
    }

    private var backupProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Backup wird erstellt")
                    .font(.headline)

                // Deterministischer Fortschritt auf Basis des ZIP- und Vorbereitungsstands.
                ProgressView(value: backupProgress, total: 1.0)
                    .progressViewStyle(.linear)

                Text("\(Int((backupProgress * 100).rounded())) %")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(backupProgressText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 12)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    private var importProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Import läuft")
                    .font(.headline)

                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.1)

                Text(importProgressText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 12)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    // Karte für ein einzelnes Backup in der horizontalen Liste.
    private func backupCard(for zipFile: (name: String, date: String, size: String, path: String)) -> some View {
        let metadata = backupMetadataByName[zipFile.name]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(zipFile.name.replacingOccurrences(of: ".zip", with: ""))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                backupMenu(for: zipFile)
            }
            HStack(spacing: 8) {
                backupMetric(icon: "shippingbox.fill", value: metadata?.snapshot.boxCount ?? 0)
                backupMetric(icon: "square.grid.2x2.fill", value: metadata?.snapshot.itemCount ?? 0)
                backupMetric(icon: "location.fill", value: metadata?.snapshot.locationCount ?? 0)
                backupMetric(icon: "photo.fill", value: metadata?.snapshot.imageCount ?? 0)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Image(systemName: "clock.fill")
                Text("\(metadata.map { backupLastChangeLabel(for: $0) } ?? "Unbekannt")")
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(formattedBackupCardDate(from: zipFile.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())

                Text("\(zipFile.size)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // Kompaktes Icon + Wert Element für die Backup-Metadaten.
    private func backupMetric(icon: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(value.formatted())
        }
    }

    // Menü-Button oben rechts auf jeder Backup-Karte.
    private func backupMenu(for zipFile: (name: String, date: String, size: String, path: String)) -> some View {
        Menu {
            Button(action: {
                shareFile(fileURL: URL(fileURLWithPath: zipFile.path))
            }) {
                Label("Settings.share", systemImage: "square.and.arrow.up")
            }

            Button(action: {
                selectedZipFile = zipFile
                activeAlert = .applyData
                showAlert = true
            }) {
                Label("Settings.apply", systemImage: "square.and.arrow.down")
            }

            Button(action: {
                selectedZipFile = zipFile
                activeAlert = .mergeData
                showAlert = true
            }) {
                Label("Settings.merge", systemImage: "plus.square.on.square")
            }

            Button(role: .destructive, action: {
                selectedZipFile = zipFile
                activeAlert = .deleteFile
                showAlert = true
            }) {
                Label("Settings.delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(selectedColor)
                .scaleEffect(1.2)
        }
        .disabled(isExporting || isImporting)
        .alert(isPresented: $showAlert) {
            backupActionAlert()
        }
    }

    private func backupActionAlert() -> Alert {
        guard let selectedZipFile = selectedZipFile else {
            return Alert(title: Text("Settings.error"))
        }

        switch activeAlert {
        case .applyData:
            return Alert(
                title: Text(String(format: NSLocalizedString("Settings.applyBackup", comment: ""), (selectedZipFile.name.replacingOccurrences(of: ".zip", with: "")))),
                message: Text("Settings.deleteallFiles"),
                primaryButton: .destructive(Text("Settings.apply")) {
                    let zipURL = URL(fileURLWithPath: selectedZipFile.path)
                    UserDefaultsManager.shared.clearUserDefaults()
                    runImportTask(
                        statusText: "Backup wird angewendet..."
                    ) {
                        try importDataAndImages(from: zipURL)
                    } onSuccess: {
                        accentColorManager.updateAccentColor(to: UserDefaultsManager.loadAccentColor())
                        alertMessage = "\(selectedZipFile.name.replacingOccurrences(of: ".zip", with: "")) \(NSLocalizedString("successfully applied", comment: ""))"
                        showAlert2 = true
                    }
                },
                secondaryButton: .cancel()
            )

        case .mergeData:
            return Alert(
                title: Text(String(format: NSLocalizedString("Settings.mergeBackup", comment: ""), (selectedZipFile.name.replacingOccurrences(of: ".zip", with: "")))),
                message: Text("Settings.mergeBackupMessage"),
                primaryButton: .destructive(Text("Settings.merge")) {
                    let zipURL = URL(fileURLWithPath: selectedZipFile.path)
                    runImportTask(
                        statusText: "Backup wird zusammengeführt..."
                    ) {
                        try mergeDataAndImages(from: zipURL)
                    } onSuccess: {
                        alertMessage = "\(selectedZipFile.name.replacingOccurrences(of: ".zip", with: "")) \(NSLocalizedString("successfully merged", comment: ""))"
                        showAlert2 = true
                    }
                },
                secondaryButton: .cancel()
            )

        case .deleteFile:
            return Alert(
                title: Text(String(format: NSLocalizedString("Settings.deleteBackup", comment: ""), (selectedZipFile.name.replacingOccurrences(of: ".zip", with: "")))),
                message: Text("Settings.deleteallBackups"),
                primaryButton: .destructive(Text("Settings.delete2")) {
                    deleteFile(at: URL(fileURLWithPath: selectedZipFile.path))
                    refreshZipFilesAndMetadata()
                },
                secondaryButton: .cancel()
            )

        case .none:
            return Alert(title: Text("Settings.error"))
        }
    }

    // Führt lange Importvorgänge im Hintergrund aus und bündelt alle UI-Updates wieder auf dem MainActor.
    @MainActor
    private func runImportTask(
        statusText: String,
        operation: @escaping @Sendable () throws -> Void,
        onSuccess: @escaping @MainActor () -> Void
    ) {
        isImporting = true
        importProgressText = statusText

        Task.detached(priority: .userInitiated) {
            var backgroundError: Error?
            do {
                try operation()
            } catch {
                backgroundError = error
            }

            await MainActor.run {
                isImporting = false
                if let backgroundError {
                    alertMessage = "Import fehlgeschlagen: \(backgroundError.localizedDescription)"
                    showAlert2 = true
                } else {
                    onSuccess()
                }
                refreshZipFilesAndMetadata()
                updateDocumentsSize()
                count_boxes = loadBoxes().count
                count_items = loadItems().count
                count_locations = loadLocations().count
                updateUserDefaultsSize()
            }
        }
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
    // deleteFile Methode (Löschen)
    func deleteFile(at fileURL: URL) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: fileURL)
            removeBackupMetadata(fileName: fileURL.lastPathComponent)
            print("Datei erfolgreich gelöscht: \(fileURL.lastPathComponent)")
        } catch {
            print("Fehler beim Löschen der Datei: \(error.localizedDescription)")
        }
    }
    func sortFilesByDate() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss dd.MM.yyyy"
        
        zipFiles.sort {
            guard let date1 = dateFormatter.date(from: $0.date),
                  let date2 = dateFormatter.date(from: $1.date) else {
                return false
            }
            return date1 > date2
        }
    }
    // Backup-Prozess-Funktion
    func startBackupProcess() {
        // ZIP-Backups nur bei vorhandenen Daten erlauben.
        guard canCreateBackup else {
            return
        }

        addBackup.invalidate(reason: .actionPerformed)
        isExporting = true
        backupProgress = 0
        backupProgressText = "Backup wird vorbereitet..."
        DispatchQueue.global(qos: .background).async {
            var zipFilePath: URL? // Declare as optional since the function may fail
            do {
                zipFilePath = try exportDataAndImages { progress in
                    DispatchQueue.main.async {
                        // Anzeige-Progress wird absichtlich gedämpft, damit die ersten Schritte nicht zu schnell wirken.
                        backupProgress = mappedBackupDisplayProgress(from: progress)
                        backupProgressText = progress < 0.70 ? "Daten werden gesammelt..." : "ZIP wird erstellt..."
                    }
                }
                if let path = zipFilePath {
                    let snapshot = currentBackupSnapshot()
                    upsertBackupMetadata(for: path, snapshot: snapshot)
                    print("Backup erfolgreich erstellt: \(path)")
                    // Hier könntest du den Pfad weiterverarbeiten, z.B. teilen oder anzeigen
                }
            } catch {
                print("Fehler beim Exportieren: \(error)")
            }
            DispatchQueue.main.async {
                backupProgress = 1.0
                backupProgressText = "Backup abgeschlossen"
                isExporting = false // Deaktiviert das Overlay nach dem Backup
                refreshZipFilesAndMetadata()
                updateDocumentsSize()
            }
        }
    }

    // Gleicht die Wahrnehmung aus: Vorbereitungsphase kleiner gewichten, ZIP-Phase größer.
    private func mappedBackupDisplayProgress(from rawProgress: Double) -> Double {
        let clamped = min(max(rawProgress, 0.0), 1.0)
        if clamped < 0.70 {
            // Erste 70% nur auf 35% Anzeige verteilen.
            return (clamped / 0.70) * 0.35
        }
        // Letzte 30% auf 65% Anzeige verteilen (fühlt sich kontinuierlicher an).
        return 0.35 + ((clamped - 0.70) / 0.30) * 0.65
    }
    func importZipFile(selectedFileURL: URL?) {
        let fileManager = FileManager.default
            
            // Überprüfen, ob die Datei-URL vorhanden ist
            guard let zipFileURL = selectedFileURL else {
                print("Fehler: Keine Datei-URL übergeben.")
                return
            }
            
            // Bestimme das Dokumentenverzeichnis der App (Hauptverzeichnis in der App-Sandbox)
            guard let appDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Dokumentenverzeichnis konnte nicht gefunden werden.")
                return
            }
            
            // Zielpfad im Dokumentenverzeichnis (gleicher Dateiname wie die ursprüngliche Datei)
            let destinationURL = appDirectory.appendingPathComponent(zipFileURL.lastPathComponent)
            
            // Überprüfen, ob bereits eine Datei mit dem gleichen Namen existiert
            if fileManager.fileExists(atPath: destinationURL.path) {
                // Optional: Falls eine Datei mit demselben Namen existiert, kann ein eindeutiger Name generiert werden
                var uniqueDestinationURL = destinationURL
                var fileIndex = 1
                while fileManager.fileExists(atPath: uniqueDestinationURL.path) {
                    let newFileName = "\(zipFileURL.deletingPathExtension().lastPathComponent) (\(fileIndex)).\(zipFileURL.pathExtension)"
                    uniqueDestinationURL = appDirectory.appendingPathComponent(newFileName)
                    fileIndex += 1
                }
                
                print("Datei existiert bereits. Neuer Pfad: \(uniqueDestinationURL.path)")
                // Aktualisiere das Ziel mit dem eindeutigen Dateinamen
                // Zugriffsrechte für die Sicherheitsbereich-Ressource anfordern
                if zipFileURL.startAccessingSecurityScopedResource() {
                    defer {
                        // Sicherheitsbereich nach der Nutzung freigeben
                        zipFileURL.stopAccessingSecurityScopedResource()
                    }
                    try? fileManager.copyItem(at: zipFileURL, to: uniqueDestinationURL)
                }
                else {
                    alertMessage = "Error i3864751: Accessing Security Scoped Resource Failed"
                    showAlert2 = true
                }
                print("Datei erfolgreich ins App-Dokumentenverzeichnis verschoben: \(uniqueDestinationURL.path)")
                persistMetadataForImportedBackup(at: uniqueDestinationURL)
                refreshZipFilesAndMetadata()
            } else {
                // Wenn keine Datei mit demselben Namen existiert, einfach verschieben
                do {
                    if zipFileURL.startAccessingSecurityScopedResource() {
                        defer {
                            // Sicherheitsbereich nach der Nutzung freigeben
                            zipFileURL.stopAccessingSecurityScopedResource()
                        }
                    try fileManager.copyItem(at: zipFileURL, to: destinationURL)
                    }
                    else {
                        alertMessage = "Error i847563: Accessing Security Scoped Resource Failed"
                        showAlert2 = true
                    }
                    print("Datei erfolgreich ins App-Dokumentenverzeichnis verschoben: \(destinationURL.path)")
                    persistMetadataForImportedBackup(at: destinationURL)
                    refreshZipFilesAndMetadata()
                    
                } catch {
                    print("Fehler beim Verschieben der Datei: \(error.localizedDescription)")
                    alertMessage = "Error i3256: \(error.localizedDescription)"
                    showAlert2 = true
                }
            }
    }
    // Funktion zur Aktualisierung der NSUserDefaults-Größe
    func updateUserDefaultsSize() {
        userDefaultsSize = UserDefaultsManager.shared.getUserDefaultsSize()
    }
    
    // Funktion zur Aktualisierung der Dokumentenverzeichnis-Größe
    func updateDocumentsSize() {
        documentsSize = UserDefaultsManager.shared.getDocumentsSize()
    }

    private func refreshZipFilesAndMetadata() {
        if let listedZipFiles = listZipFiles() {
            zipFiles = listedZipFiles
            sortFilesByDate()
            let zipNames = Set(listedZipFiles.map(\.name))
            var metadataIndex = pruneBackupMetadataToExistingZIPs(existingZIPNames: zipNames)

            // Metadaten für bestehende Alt-Backups nachziehen, falls noch kein Eintrag vorhanden ist.
            for zipFile in listedZipFiles where metadataIndex[zipFile.name] == nil {
                let zipURL = URL(fileURLWithPath: zipFile.path)
                persistMetadataForImportedBackup(at: zipURL)
                metadataIndex = loadBackupMetadataIndex()
            }

            backupMetadataByName = metadataIndex
        } else {
            zipFiles = []
            backupMetadataByName = pruneBackupMetadataToExistingZIPs(existingZIPNames: [])
        }
    }

    private func persistMetadataForImportedBackup(at backupURL: URL) {
        do {
            let snapshot = try snapshotFromBackupZIP(at: backupURL)
            upsertBackupMetadata(for: backupURL, snapshot: snapshot)
        } catch {
            // Fallback, wenn ZIP-Datei keine verwertbaren JSON-Daten enthält.
            let fallback = BackupSnapshot(boxCount: 0, itemCount: 0, locationCount: 0, imageCount: 0, lastUpdatedAt: nil)
            upsertBackupMetadata(for: backupURL, snapshot: fallback)
            print("Fehler beim Einlesen der Backup-Metadaten: \(error)")
        }
    }

    private func backupLastChangeLabel(for metadata: BackupMetadataEntry) -> String {
        guard let lastChange = metadata.snapshot.lastUpdatedAt else {
            return "Unbekannt"
        }
        return formattedBackupCardDate(from: lastChange)
    }

    // Einheitliches Format in den Backup-Karten: kein Sekundenanteil, zweistelliges Jahr.
    private func formattedBackupCardDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.dateFormat = "HH:mm dd.MM.yy"
        return formatter.string(from: date)
    }

    // Konvertiert die gespeicherte ZIP-Zeichenkette (mit Sekunden, 4-stelligem Jahr) in das Kartenformat.
    private func formattedBackupCardDate(from rawDateString: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "de_DE_POSIX")
        parser.dateFormat = "HH:mm:ss dd.MM.yyyy"

        guard let parsedDate = parser.date(from: rawDateString) else {
            return rawDateString
        }
        return formattedBackupCardDate(from: parsedDate)
    }
    
    private func exportBoxesCSV() {
        let headers = ["id", "name", "location_uuid", "notes", "tags", "createdAt", "updatedAt"]
        let locationsByID = Dictionary(uniqueKeysWithValues: loadLocations().map { ($0.id, $0.name) })
        let rows = loadBoxes().map { box in
            [
                box.id.uuidString,
                box.name,
                box.category,
                box.location_uuid?.uuidString ?? "",
                box.location_uuid.flatMap { locationsByID[$0] } ?? "",
                box.color,
                box.notes ?? "",
                (box.tags ?? []).joined(separator: "|"),
                iso8601(box.createdAt),
                iso8601(box.updatedAt)
            ]
        }
        presentCSVExport(headers: headers, rows: rows, fileName: "boxes_export.csv")
    }
    
    private func exportItemsCSV() {
        let headers = ["id", "name", "box_uuid", "isFragile", "isHeavy", "createdAt", "updatedAt"]
        let boxesByID = Dictionary(uniqueKeysWithValues: loadBoxes().map { ($0.id, $0.name) })
        let rows = loadItems().map { item in
            [
                item.id.uuidString,
                item.name,
                item.box_uuid.uuidString,
                boxesByID[item.box_uuid] ?? "",
                item.description ?? "",
                item.category,
                item.isFragile ? "true" : "false",
                item.isHeavy ? "true" : "false",
                (item.tags ?? []).joined(separator: "|"),
                iso8601(item.createdAt),
                iso8601(item.updatedAt)
            ]
        }
        presentCSVExport(headers: headers, rows: rows, fileName: "items_export.csv")
    }
    
    private func exportLocationsCSV() {
        let headers = ["id", "name", "color", "createdAt", "updatedAt"]
        let rows = loadLocations().map { location in
            [
                location.id.uuidString,
                location.name,
                location.color,
                location.image,
                iso8601(location.createdAt),
                iso8601(location.updatedAt)
            ]
        }
        presentCSVExport(headers: headers, rows: rows, fileName: "locations_export.csv")
    }
    
    private func presentCSVExport(headers: [String], rows: [[String]], fileName: String) {
        var csv = csvLine(headers)
        for row in rows {
            csv += "\n" + csvLine(row)
        }
        csvDocument = CSVTextDocument(text: csv)
        csvExportFileName = fileName
        isCSVExporterPresented = true
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch activeFileImportMode {
        case .zipBackup:
            switch result {
            case .success(let urls):
                selectedFileURL = urls.first
                importZipFile(selectedFileURL: urls.first)
            case .failure(let error):
                print("Fehler beim Öffnen der Datei: \(error.localizedDescription)")
                alertMessage = "Error i34745: \(error.localizedDescription)"
                showAlert2 = true
            }
        case .csv:
            handleCSVImport(result)
        }
    }
    
    private func handleCSVImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let text = try readImportedCSV(url: url)
                let parsed = parseCSV(text)
                guard !parsed.headers.isEmpty else {
                    alertMessage = "CSV enthält keine Header."
                    showAlert2 = true
                    return
                }
                csvImportText = text
                csvImportFileName = url.lastPathComponent
                csvImportHeaders = parsed.headers
                csvImportRows = parsed.rows
                csvColumnMapping = defaultMapping(for: csvImportModel, headers: parsed.headers)
                showCSVImportSheet = true
            } catch {
                alertMessage = "CSV Import fehlgeschlagen: \(error.localizedDescription)"
                showAlert2 = true
            }
        case .failure(let error):
            alertMessage = "CSV Import fehlgeschlagen: \(error.localizedDescription)"
            showAlert2 = true
        }
    }
    
    private func readImportedCSV(url: URL) throws -> String {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            return try String(contentsOf: url, encoding: .utf8)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    private func parseCSV(_ text: String) -> (headers: [String], rows: [[String]]) {
        let delimiter = detectDelimiter(in: text)
        let rows = splitCSVRows(text, delimiter: delimiter)
        guard let first = rows.first else { return ([], []) }
        let headers = first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let body = rows.dropFirst().filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        return (headers, Array(body))
    }
    
    private func detectDelimiter(in text: String) -> Character {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let candidates: [Character] = [",", ";", "\t"]
        var bestDelimiter: Character = ","
        var maxCount = -1
        for delimiter in candidates {
            let count = firstLine.filter { $0 == delimiter }.count
            if count > maxCount {
                maxCount = count
                bestDelimiter = delimiter
            }
        }
        return bestDelimiter
    }
    
    private func splitCSVRows(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        let chars = Array(text)
        var index = 0
        
        while index < chars.count {
            let ch = chars[index]
            if inQuotes {
                if ch == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" {
                        currentField.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == delimiter {
                    currentRow.append(currentField)
                    currentField = ""
                } else if ch == "\n" || ch == "\r" {
                    if ch == "\r", index + 1 < chars.count, chars[index + 1] == "\n" {
                        index += 1
                    }
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                } else {
                    currentField.append(ch)
                }
            }
            index += 1
        }
        
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        return rows
    }
    
    private func defaultMapping(for model: CSVImportModel, headers: [String]) -> [String: String] {
        let allowed = Set(model.attributes)
        var mapping: [String: String] = [:]
        for header in headers {
            let normalized = normalize(header)
            let match = allowed.first(where: { normalize($0) == normalized }) ?? ""
            if mapping[header] == nil {
                mapping[header] = match
            }
        }
        return mapping
    }
    
    private func applyCSVImport() {
        guard !csvImportHeaders.isEmpty else { return }
        switch csvImportModel {
        case .boxes:
            importBoxesFromCSV()
        case .items:
            importItemsFromCSV()
        case .locations:
            importLocationsFromCSV()
        }
        updateCountsAfterImport()
        showCSVImportSheet = false
    }
    
    private func importBoxesFromCSV() {
        var boxes = loadBoxes()
        var locationsByName: [String: UUID] = [:]
        for location in loadLocations() {
            let key = normalize(location.name)
            if locationsByName[key] == nil {
                locationsByName[key] = location.id
            }
        }
        
        for row in csvImportRows {
            let values = rowDictionary(row: row)
            let name = value(for: "name", in: values).trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { continue }
            
            let category = value(for: "category", in: values)
            let color = value(for: "color", in: values)
            let notesValue = value(for: "notes", in: values)
            let tags = parseTags(value(for: "tags", in: values))
            let locationUUIDString = value(for: "location_uuid", in: values)
            let locationName = value(for: "location_name", in: values)
            
            var locationUUID: UUID?
            if let parsedUUID = UUID(uuidString: locationUUIDString) {
                locationUUID = parsedUUID
            } else if !locationName.isEmpty {
                locationUUID = locationsByName[normalize(locationName)]
            }
            
            let box = MovingBox(
                id: UUID(),
                name: name,
                items: [],
                images: [],
                category: category,
                location_uuid: locationUUID,
                color: color.isEmpty ? (colorToString(randomColor()) ?? "0,0,0") : color,
                tags: tags,
                notes: notesValue.isEmpty ? nil : notesValue
            )
            boxes.append(box)
        }
        saveBoxes(boxes)
    }
    
    private func importItemsFromCSV() {
        var items = loadItems()
        var boxes = loadBoxes()
        var boxByName: [String: UUID] = [:]
        for box in boxes {
            let key = normalize(box.name)
            if boxByName[key] == nil {
                boxByName[key] = box.id
            }
        }
        var boxByID: [String: UUID] = [:]
        for box in boxes {
            boxByID[box.id.uuidString.lowercased()] = box.id
        }
        
        func ensureFallbackBox() -> UUID {
            if let first = boxes.first?.id { return first }
            let fallback = MovingBox(name: "Imported", items: [], images: [], category: "Import")
            boxes.append(fallback)
            boxByName[normalize(fallback.name)] = fallback.id
            boxByID[fallback.id.uuidString.lowercased()] = fallback.id
            return fallback.id
        }
        
        for row in csvImportRows {
            let values = rowDictionary(row: row)
            let name = value(for: "name", in: values).trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { continue }
            
            let description = value(for: "description", in: values)
            let category = value(for: "category", in: values)
            let fragile = parseBool(value(for: "isFragile", in: values))
            let heavy = parseBool(value(for: "isHeavy", in: values))
            let tags = parseTags(value(for: "tags", in: values))
            let boxUUIDString = value(for: "box_uuid", in: values).lowercased()
            let boxName = value(for: "box_name", in: values)
            
            let resolvedBoxID: UUID = {
                if let byID = boxByID[boxUUIDString] { return byID }
                if let byName = boxByName[normalize(boxName)] { return byName }
                if !boxName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let created = MovingBox(name: boxName, items: [], images: [], category: "Import")
                    boxes.append(created)
                    boxByName[normalize(created.name)] = created.id
                    boxByID[created.id.uuidString.lowercased()] = created.id
                    return created.id
                }
                return ensureFallbackBox()
            }()
            
            let item = Items(
                id: UUID(),
                name: name,
                box_uuid: resolvedBoxID,
                description: description.isEmpty ? nil : description,
                images: [],
                category: category,
                isFragile: fragile,
                isHeavy: heavy,
                tags: tags
            )
            items.append(item)
        }
        
        saveBoxes(boxes)
        saveItems(items)
    }
    
    private func importLocationsFromCSV() {
        var locations = loadLocations()
        for row in csvImportRows {
            let values = rowDictionary(row: row)
            let name = value(for: "name", in: values).trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { continue }
            let color = value(for: "color", in: values)
            let image = value(for: "image", in: values)
            let location = Locations(
                id: UUID(),
                name: name,
                color: color.isEmpty ? (colorToString(randomColor()) ?? "0,0,0") : color,
                image: image
            )
            locations.append(location)
        }
        saveLocations(locations)
    }
    
    private func rowDictionary(row: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for (index, header) in csvImportHeaders.enumerated() {
            guard index < row.count else { continue }
            result[header] = row[index]
        }
        return result
    }
    
    private func value(for attribute: String, in row: [String: String]) -> String {
        guard let sourceHeader = csvColumnMapping.first(where: { $0.value == attribute })?.key else { return "" }
        return row[sourceHeader]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private func parseTags(_ raw: String) -> [String] {
        guard !raw.isEmpty else { return [] }
        return raw
            .split(whereSeparator: { $0 == "|" || $0 == "," || $0 == ";" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func parseBool(_ value: String) -> Bool {
        let normalized = normalize(value)
        return ["true", "1", "yes", "ja"].contains(normalized)
    }
    
    private func csvLine(_ fields: [String]) -> String {
        fields.map(csvEscape).joined(separator: ",")
    }
    
    private func csvEscape(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
    
    private func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
    
    private func updateCountsAfterImport() {
        count_boxes = loadBoxes().count
        count_items = loadItems().count
        count_locations = loadLocations().count
    }
}

private enum CSVImportModel: String, CaseIterable, Identifiable {
    case boxes
    case items
    case locations
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .boxes: return String(localized: "Kisten")
        case .items: return String(localized: "Gegenstände")
        case .locations: return String(localized: "Standorte")
        }
    }
    
    var attributes: [String] {
        switch self {
        case .boxes:
            return ["name", "location_uuid", "notes", "tags"]
        case .items:
            return ["name", "box_uuid", "isFragile", "isHeavy"]
        case .locations:
            return ["name", "color"]
        }
    }
}

private struct CSVTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}

private struct CSVImportMappingSheet: View {
    @Binding var selectedModel: CSVImportModel
    let fileName: String
    let headers: [String]
    let rows: [[String]]
    @Binding var mapping: [String: String]
    var onImport: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var previewRows: [[String]] {
        Array(rows.prefix(5))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datei")) {
                    Text(fileName.isEmpty ? "-" : fileName)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section(header: Text("Datenmodell")) {
                    Picker("Typ", selection: $selectedModel) {
                        ForEach(CSVImportModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedModel, initial: false) { oldValue, newValue in
                        let allowed = Set(newValue.attributes)
                        mapping = mapping.mapValues { allowed.contains($0) ? $0 : "" }
                    }
                }
                
                Section(header: Text("Spaltenzuordnung")) {
                    HStack(spacing: 8) {
                        Text("Source")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Image(systemName: "arrow.right")
                            .frame(width: 24)
                        Text("Target")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { d in
                        d[.leading]
                    }
                    .frame(maxWidth: .infinity)
                    ForEach(selectedModel.attributes, id: \.self) { attribute in
                        HStack {
                            Picker(selection: sourceBinding(for: attribute)) {
                                Text("NULL").tag("")
                                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                                    Text(header).tag(header)
                                }
                            } label: {
                                Text("")
                            }
                            .frame(maxWidth: .infinity)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Spacer()
                            Text(attribute)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                Section(header: Text("Vorschau")) {
                    if previewRows.isEmpty {
                        Text("Keine Daten gefunden")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(headers.joined(separator: ";"))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                ForEach(Array(previewRows.enumerated()), id: \.offset) { index, row in
                                    Text("\(row.joined(separator: ";"))")
                                        .font(.caption)
                                }
                            }
                            .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Importieren") {
                        onImport()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sourceBinding(for attribute: String) -> Binding<String> {
        Binding(
            get: { mapping.first(where: { $0.value == attribute })?.key ?? "" },
            set: { newValue in
                mapping = mapping.mapValues { $0 == attribute ? "" : $0 }
                if !newValue.isEmpty {
                    mapping[newValue] = attribute
                }
            }
        )
    }
}
