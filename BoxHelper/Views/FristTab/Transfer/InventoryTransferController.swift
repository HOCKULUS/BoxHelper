import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let inventoryTransferCompleted = Notification.Name("inventoryTransferCompleted")
}

@MainActor
final class InventoryTransferController: ObservableObject {
    @Published var showFilePicker = false
    @Published var prepared: PreparedInventoryImport?
    @Published var share: TransferShareFile?
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var showBackupImported = false
    @Published var sharedDirectory: URL?
    @Published var importedKind: InventoryTransfer.Kind?
    private var importDirectory: URL?

    func export(_ payload: InventoryTransfer) {
        guard !isBusy, payload.count > 0 else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                if payload.kind == .images {
                    let urls = try await Task.detached(priority: .userInitiated) {
                        try InventoryTransferArchive.exportImages(payload)
                    }.value
                    share = TransferShareFile(urls: urls)
                } else {
                    let url = try await Task.detached(priority: .userInitiated) {
                        try InventoryTransferArchive.export(payload)
                    }.value
                    share = TransferShareFile(urls: [url])
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func open(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): errorMessage = error.localizedDescription
        case .success(let urls):
            guard let firstURL = urls.first, !isBusy else { return }
            isBusy = true
            Task {
                defer { isBusy = false }
                do {
                    let value = try await Task.detached(priority: .userInitiated) {
                        if urls.allSatisfy({ $0.pathExtension.lowercased() != "zip" }) {
                            return try InventoryTransferArchive.prepareImageFiles(urls)
                        }
                        return try InventoryTransferArchive.prepare(firstURL)
                    }.value
                    importDirectory = value.directory
                    if value.isBackup {
                        try InventoryTransferArchive.storeBackup(value)
                        cleanImport()
                        showBackupImported = true
                    } else {
                        prepared = value
                    }
                } catch { cleanImport(); errorMessage = error.localizedDescription }
            }
        }
    }

    func cleanImport() {
        if let importDirectory { try? FileManager.default.removeItem(at: importDirectory) }
        importDirectory = nil
    }
}

struct TransferShareFile: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// Präsentationen hängen an jeder Liste, sodass Import auch im Auswahlmodus erreichbar bleibt.
struct InventoryTransferPresentation: ViewModifier {
    @ObservedObject var controller: InventoryTransferController
    @Binding var selectedOption: String

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $controller.showFilePicker, allowedContentTypes: [.zip, .image], allowsMultipleSelection: true,
                          onCompletion: controller.open)
            .sheet(item: $controller.prepared, onDismiss: {
                controller.cleanImport()
                if let kind = controller.importedKind {
                    // Erst nach Schließen des Sheets die tragende Liste wechseln.
                    NotificationCenter.default.post(name: .inventoryTransferCompleted, object: nil)
                    selectedOption = kind.rawValue
                    controller.importedKind = nil
                }
            }) { prepared in
                if let payload = prepared.payload {
                    InventoryImportPreview(payload: payload, directory: prepared.directory) { kind in
                        controller.importedKind = kind
                    }
                }
            }
            .sheet(item: $controller.share, onDismiss: {
                if let sharedDirectory = controller.sharedDirectory {
                    try? FileManager.default.removeItem(at: sharedDirectory)
                }
                controller.sharedDirectory = nil
            }) { file in
                    InventoryShareSheet(urls: file.urls)
                    .onAppear { controller.sharedDirectory = file.urls.first?.deletingLastPathComponent() }
            }
            .alert("Import / Export", isPresented: Binding(get: { controller.errorMessage != nil }, set: { if !$0 { controller.errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(controller.errorMessage ?? "") }
            .alert("Backup wurde importiert", isPresented: $controller.showBackupImported) {
                Button("OK", role: .cancel) { }
                    .keyboardShortcut(.defaultAction)
                Button("Anzeigen") {
                    NotificationCenter.default.post(name: .openSettingsFromCreate, object: nil)
                }
            }
            .overlay {
                if controller.isBusy {
                    ProgressView().padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .disabled(controller.isBusy)
    }
}

private struct InventoryShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
