import AppIntents
import UniformTypeIdentifiers
import Zip

@available(iOS 18.0, *)
struct ImportZIPBackupIntent: AppIntent {
    static let title = LocalizedStringResource("Import ZIP backup")
    static let description = IntentDescription("Import boxes, items, locations, and photos from a BoxHelper ZIP backup. By default, merge by ID and keep newer objects. Optionally replace the current inventory.")
    @Parameter(title: "ZIP backup", supportedContentTypes: [.zip], inputConnectionBehavior: .connectToPreviousIntentResult)
    var backup: IntentFile
    @Parameter(title: "Replace current inventory", default: false) var replaceExisting: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Import ZIP backup \(\.$backup)") { \.$replaceExisting }
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        let data = try await backup.data(contentType: .zip)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = directory.appendingPathComponent("backup.zip")
        try data.write(to: archive, options: .atomic)
        let contents = directory.appendingPathComponent("contents", isDirectory: true)
        // Extraction is isolated and off main. The inventory is untouched until validation finishes.
        try await Task.detached {
            try Zip.unzipFile(archive, destination: contents, overwrite: false, password: nil)
        }.value
        try IntentBackupImport.commit(from: contents, replaceExisting: replaceExisting)
        return .result(value: true)
    }
}
