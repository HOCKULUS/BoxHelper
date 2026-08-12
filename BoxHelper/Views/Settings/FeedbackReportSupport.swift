import Foundation
import ImageIO
import MessageUI
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum FeedbackReportCategory: String, CaseIterable, Codable, Identifiable {
    case help
    case bug
    case idea

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .help:
            NSLocalizedString("Help", comment: "Feedback category help")
        case .bug:
            NSLocalizedString("Bug", comment: "Feedback category bug")
        case .idea:
            NSLocalizedString("Idea", comment: "Feedback category idea")
        }
    }
}

struct FeedbackReportAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let createdAt: Date

    init(id: UUID = UUID(), fileName: String, createdAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
    }
}

private struct FeedbackReportDraftData: Codable {
    var category: FeedbackReportCategory
    var message: String
    var attachments: [FeedbackReportAttachment]
}

struct FeedbackMailAttachment {
    let data: Data
    let mimeType: String
    let fileName: String
}

struct FeedbackMailPayload: Identifiable {
    let id = UUID()
    let subject: String
    let body: String
    let plainTextBody: String
    let recipients: [String]
    let attachments: [FeedbackMailAttachment]
}

private struct PreparedFeedbackAttachment {
    let attachment: FeedbackReportAttachment
    let data: Data
}

struct FeedbackReportStats {
    let appVersion: String
    let buildNumber: String
    let deviceName: String
    let deviceModel: String
    let systemVersion: String
    let appLanguage: String
    let backupCount: Int
    let totalImageCount: Int
    let boxCount: Int
    let itemCount: Int
    let locationCount: Int
    let maxBoxImageCount: Int
    let maxItemImageCount: Int
    let earliestCreatedSummary: String
    let latestUpdatedSummary: String
    let reviewPromptedBefore: Bool
    let lastReviewRequestSummary: String
    let feedbackSentBefore: Bool
}

@MainActor
final class FeedbackReportStore: ObservableObject {
    @Published var category: FeedbackReportCategory {
        didSet { persistDraft() }
    }
    @Published var message: String {
        didSet { persistDraft() }
    }
    @Published var attachments: [FeedbackReportAttachment] {
        didSet { persistDraft() }
    }

    init() {
        if let storedDraft = Self.loadDraft() {
            category = storedDraft.category
            message = storedDraft.message
            attachments = storedDraft.attachments.filter {
                FileManager.default.fileExists(atPath: Self.attachmentURL(for: $0).path)
            }
        } else {
            category = .idea
            message = ""
            attachments = []
        }

        // Entfernt Dateireferenzen, die nicht mehr existieren, aus dem Draft.
        attachments = attachments.filter { FileManager.default.fileExists(atPath: Self.attachmentURL(for: $0).path) }
        persistDraft()
    }

    var isEmpty: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty
    }

    func addPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let preparedAttachment = await Task.detached(priority: .utility) {
                Self.prepareAttachment(from: data)
            }.value
            guard let preparedAttachment else { continue }

            let fileURL = Self.attachmentURL(for: preparedAttachment.attachment)

            do {
                try Self.ensureStorageDirectoryExists()
                try preparedAttachment.data.write(to: fileURL, options: .atomic)
                attachments.append(preparedAttachment.attachment)
            } catch {
                print("Feedback attachment could not be saved: \(error.localizedDescription)")
            }
        }
    }

    func removeAttachment(_ attachment: FeedbackReportAttachment) {
        let fileURL = Self.attachmentURL(for: attachment)
        try? FileManager.default.removeItem(at: fileURL)
        attachments.removeAll { $0.id == attachment.id }
    }

    func clearDraft() {
        for attachment in attachments {
            try? FileManager.default.removeItem(at: Self.attachmentURL(for: attachment))
        }

        category = .idea
        message = ""
        attachments = []
        persistDraft()
    }

    func attachmentImage(for attachment: FeedbackReportAttachment) -> UIImage? {
        UIImage(contentsOfFile: Self.attachmentURL(for: attachment).path)
    }

    func mailPayload() -> FeedbackMailPayload {
        let stats = Self.collectStats()
        let subject = "BoxHelper \(category.localizedTitle)"
        let body = Self.buildHTMLBody(
            category: category,
            message: message,
            stats: stats
        )
        let plainTextBody = Self.buildPlainTextBody(
            category: category,
            message: message,
            stats: stats
        )

        return FeedbackMailPayload(
            subject: subject,
            body: body,
            plainTextBody: plainTextBody,
            recipients: ["appstore@hockulus.de"],
            attachments: attachments.compactMap(Self.mailAttachment(for:))
        )
    }

    func markFeedbackAsSent() {
        UserDefaults.standard.set(true, forKey: Self.feedbackSentKey)
    }

    static let feedbackSentKey = "feedbackReportWasSent"
    private static let draftFileName = "feedback-report-draft.json"
    private static let attachmentsDirectoryName = "FeedbackReportAttachments"

    private static var draftFileURL: URL {
        storageDirectory.appendingPathComponent(draftFileName)
    }

    private static var storageDirectory: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent("FeedbackReport", isDirectory: true)
    }

    private static var attachmentsDirectoryURL: URL {
        storageDirectory.appendingPathComponent(attachmentsDirectoryName, isDirectory: true)
    }

    private static func attachmentURL(for attachment: FeedbackReportAttachment) -> URL {
        attachmentsDirectoryURL.appendingPathComponent(attachment.fileName)
    }

    private func persistDraft() {
        let draft = FeedbackReportDraftData(
            category: category,
            message: message,
            attachments: attachments
        )

        do {
            try Self.ensureStorageDirectoryExists()
            let data = try JSONEncoder().encode(draft)
            try data.write(to: Self.draftFileURL, options: .atomic)
        } catch {
            print("Feedback draft could not be saved: \(error.localizedDescription)")
        }
    }

    private static func loadDraft() -> FeedbackReportDraftData? {
        guard let data = try? Data(contentsOf: draftFileURL) else { return nil }
        return try? JSONDecoder().decode(FeedbackReportDraftData.self, from: data)
    }

    private static func ensureStorageDirectoryExists() throws {
        try FileManager.default.createDirectory(at: attachmentsDirectoryURL, withIntermediateDirectories: true)
    }

    private static func mailAttachment(for attachment: FeedbackReportAttachment) -> FeedbackMailAttachment? {
        let fileURL = attachmentURL(for: attachment)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let fileExtension = fileURL.pathExtension
        let mimeType = UTType(filenameExtension: fileExtension)?.preferredMIMEType ?? "application/octet-stream"

        return FeedbackMailAttachment(
            data: data,
            mimeType: mimeType,
            fileName: attachment.fileName
        )
    }

    nonisolated private static func prepareAttachment(from data: Data) -> PreparedFeedbackAttachment? {
        if let heicData = makeHEICData(from: data, compressionQuality: 0.5) {
            let attachment = FeedbackReportAttachment(fileName: "\(UUID().uuidString).heic")
            return PreparedFeedbackAttachment(attachment: attachment, data: heicData)
        }

        let fallbackExtension = inferredFileExtension(from: data)
        let attachment = FeedbackReportAttachment(fileName: "\(UUID().uuidString).\(fallbackExtension)")
        return PreparedFeedbackAttachment(attachment: attachment, data: data)
    }

    nonisolated private static func makeHEICData(from data: Data, compressionQuality: CGFloat) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
              let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                  mutableData,
                  UTType.heic.identifier as CFString,
                  1,
                  nil
              ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }

    nonisolated private static func inferredFileExtension(from data: Data) -> String {
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let type = CGImageSourceGetType(source),
           let contentType = UTType(type as String),
           let fileExtension = contentType.preferredFilenameExtension {
            return fileExtension
        }

        return "jpg"
    }

    private static func collectStats() -> FeedbackReportStats {
        let boxes = loadBoxes()
        let items = loadItems()
        let locations = loadLocations()

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let device = UIDevice.current
        let locale = Locale.current
        let locationImageCount = locations.filter { !$0.image.isEmpty }.count
        let totalImageCount = boxes.reduce(0) { $0 + $1.images.count } + items.reduce(0) { $0 + $1.images.count } + locationImageCount

        let maxBox = boxes.max { $0.images.count < $1.images.count }
        let maxItem = items.max { $0.images.count < $1.images.count }

        let createdCandidates = boxes.map(\.createdAt) + items.map(\.createdAt) + locations.map(\.createdAt)
        let updatedCandidates = boxes.map(\.updatedAt) + items.map(\.updatedAt) + locations.map(\.updatedAt)

        let requestReviewKey = "requestAppReview"
        let lastRequestKey = "lastAppReviewRequestDate"
        let reviewPromptedBefore = UserDefaults.standard.bool(forKey: requestReviewKey)
        let lastRequestDate = UserDefaults.standard.object(forKey: lastRequestKey) as? Date
        let feedbackSentBefore = UserDefaults.standard.bool(forKey: feedbackSentKey)

        return FeedbackReportStats(
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceName: device.name,
            deviceModel: hardwareIdentifier(),
            systemVersion: "\(device.systemName) \(device.systemVersion)",
            appLanguage: "\(locale.language.languageCode?.identifier ?? "Unknown")-\(locale.region?.identifier ?? "Unknown")",
            backupCount: countAllZipFilesInAppStorage(),
            totalImageCount: totalImageCount,
            boxCount: boxes.count,
            itemCount: items.count,
            locationCount: locations.count,
            maxBoxImageCount: maxBox?.images.count ?? 0,
            maxItemImageCount: maxItem?.images.count ?? 0,
            earliestCreatedSummary: createdCandidates.min().map(Self.isoDateTimeString) ?? "None",
            latestUpdatedSummary: updatedCandidates.max().map(Self.isoDateTimeString) ?? "None",
            reviewPromptedBefore: reviewPromptedBefore,
            lastReviewRequestSummary: lastRequestDate.map(Self.isoDateTimeString) ?? "None",
            feedbackSentBefore: feedbackSentBefore
        )
    }

    private static func buildPlainTextBody(
        category: FeedbackReportCategory,
        message: String,
        stats: FeedbackReportStats
    ) -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = trimmedMessage.isEmpty ? "No message provided." : trimmedMessage
        let reviewRequestedText = stats.reviewPromptedBefore ? "Yes" : "No"
        let feedbackSentText = stats.feedbackSentBefore ? "Yes" : "No"

        return """
        \(userMessage)


        Feedback details
        Category: \(category.localizedTitle)

        App
        Ver: \(stats.appVersion)
        Build: \(stats.buildNumber)
        Lang: \(stats.appLanguage)

        Device
        Name: \(stats.deviceName)
        HW ID: \(stats.deviceModel)
        System: \(stats.systemVersion)

        App content
        Backups: \(stats.backupCount)
        Images: \(stats.totalImageCount)
        Boxes: \(stats.boxCount)
        Items: \(stats.itemCount)
        Locations: \(stats.locationCount)
        Max box images: \(stats.maxBoxImageCount)
        Max item images: \(stats.maxItemImageCount)
        First change: \(stats.earliestCreatedSummary)
        Last change: \(stats.latestUpdatedSummary)

        Status
        FB req: \(reviewRequestedText)
        Last req: \(stats.lastReviewRequestSummary)
        FB sent: \(feedbackSentText)
        """
    }

    private static func buildHTMLBody(
        category: FeedbackReportCategory,
        message: String,
        stats: FeedbackReportStats
    ) -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = trimmedMessage.isEmpty ? "No message provided." : trimmedMessage
        let normalizedMessage = htmlEscaped(userMessage).replacingOccurrences(of: "\r\n", with: "<br>")
            .replacingOccurrences(of: "\n", with: "<br>")
        let reviewRequestedText = stats.reviewPromptedBefore ? "Yes" : "No"
        let feedbackSentText = stats.feedbackSentBefore ? "Yes" : "No"

        // The report intentionally uses only aggregated app content metrics.
        // Box, item and location names are excluded from the generated draft.
        return """
        <html>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif; font-size: 16px; line-height: 1.45; color: #111111; margin: 0; padding: 0;">
          <div style="padding: 28px 24px 36px 24px;">
            <div style="min-height: 160px; white-space: normal;">\(normalizedMessage)</div>
            <div style="height: 32px;"></div>
            <div style="border-top: 1px solid #DCDCDC; padding-top: 20px;">
              <div style="font-size: 13px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; color: #666666; margin-bottom: 16px;">Feedback details</div>
              \(htmlSection(title: "Category", rows: [("Type", category.localizedTitle)]))
              \(htmlSection(title: "App", rows: [("Ver", stats.appVersion), ("Build", stats.buildNumber), ("Lang", stats.appLanguage)]))
              \(htmlSection(title: "Device", rows: [("Name", stats.deviceName), ("HW ID", stats.deviceModel), ("System", stats.systemVersion)]))
              \(htmlSection(title: "App content", rows: [("Backups", String(stats.backupCount)), ("Images", String(stats.totalImageCount)), ("Boxes", String(stats.boxCount)), ("Items", String(stats.itemCount)), ("Locations", String(stats.locationCount)), ("Max box images", String(stats.maxBoxImageCount)), ("Max item images", String(stats.maxItemImageCount)), ("First change", stats.earliestCreatedSummary), ("Last change", stats.latestUpdatedSummary)]))
              \(htmlSection(title: "Status", rows: [("FB req", reviewRequestedText), ("Last req", stats.lastReviewRequestSummary), ("FB sent", feedbackSentText)]))
            </div>
          </div>
        </body>
        </html>
        """
    }

    private static func isoDateTimeString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func htmlSection(title: String, rows: [(String, String)]) -> String {
        let rowMarkup = rows.map { label, value in
            """
            <tr>
              <td style="padding: 6px 14px 6px 0; vertical-align: top; color: #666666; white-space: nowrap;">\(htmlEscaped(label))</td>
              <td style="padding: 6px 0; vertical-align: top; color: #111111;">\(htmlEscaped(value))</td>
            </tr>
            """
        }.joined()

        return """
        <div style="margin-bottom: 22px;">
          <div style="font-size: 17px; font-weight: 600; margin-bottom: 8px; color: #111111;">\(htmlEscaped(title))</div>
          <table style="border-collapse: collapse; width: 100%;">
            \(rowMarkup)
          </table>
        </div>
        """
    }

    private static func htmlEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func hardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let identifier = withUnsafeBytes(of: &systemInfo.machine) { rawBuffer in
            rawBuffer.prefix { $0 != 0 }.map { String(UnicodeScalar($0)) }.joined()
        }

        return identifier.isEmpty ? UIDevice.current.localizedModel : identifier
    }
}

struct FeedbackMailComposer: UIViewControllerRepresentable {
    let payload: FeedbackMailPayload
    let onResult: (MFMailComposeResult) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, onResult: onResult)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(payload.recipients)
        controller.setSubject(payload.subject)
        controller.setMessageBody(payload.body, isHTML: true)

        for attachment in payload.attachments {
            controller.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
        }

        return controller
    }

    func updateUIViewController(_: MFMailComposeViewController, context _: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction
        private let onResult: (MFMailComposeResult) -> Void

        init(dismiss: DismissAction, onResult: @escaping (MFMailComposeResult) -> Void) {
            self.dismiss = dismiss
            self.onResult = onResult
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error _: Error?
        ) {
            onResult(result)
            dismiss()
        }
    }
}
