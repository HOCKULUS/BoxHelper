import MessageUI
import PhotosUI
import SwiftUI
import UIKit

struct FeedbackReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var store = FeedbackReportStore()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var composerPayload: FeedbackMailPayload?
    @State private var showDeleteConfirmation = false
    @State private var showMailUnavailableAlert = false
    @State private var textEditorHeight: CGFloat = 500

    private var clampedEditorHeight: CGFloat {
        min(max(textEditorHeight, 100), 500)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Feedback category", selection: $store.category) {
                        ForEach(FeedbackReportCategory.allCases) { category in
                            Text(category.localizedTitle).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Describe your request as precisely as possible.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        GrowingFeedbackTextView(
                            text: $store.message,
                            measuredHeight: $textEditorHeight,
                            placeholder: ""
                        )
                        .frame(height: clampedEditorHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Images")
                                .font(.headline)
                            Spacer()
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 10,
                                matching: .images
                            ) {
                                Label("Add images", systemImage: "photo.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        if store.attachments.isEmpty {
                            Text("Add screenshots or photos that help explain the issue.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(store.attachments) { attachment in
                                        FeedbackAttachmentTile(
                                            image: store.attachmentImage(for: attachment)
                                        ) {
                                            store.removeAttachment(attachment)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 110)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottomTrailing) {
                floatingSendButton
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(store.isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this draft?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete draft", role: .destructive) {
                    store.clearDraft()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All text and selected images will be removed from the saved draft.")
            }
            .alert("Mail is unavailable", isPresented: $showMailUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No mail account is configured on this device. Please set up Mail first.")
            }
            .sheet(item: $composerPayload) { payload in
                FeedbackMailComposer(payload: payload) { result in
                    if result == .sent {
                        store.markFeedbackAsSent()
                    }
                }
            }
            .onChange(of: selectedPhotoItems, initial: false) { _, newValue in
                guard !newValue.isEmpty else { return }
                let items = newValue
                selectedPhotoItems = []
                Task {
                    await store.addPhotos(items)
                }
            }
        }
    }

    private var floatingSendButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)

            Button {
                handleSendTap()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                    Text("Send")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
        }
        .modifier(FeedbackGlassCardModifier())
        .fixedSize()
        .padding(.trailing, 20)
        .padding(.bottom, 18)
    }

    private func handleSendTap() {
        openMailComposerIfPossible()
    }

    private func openMailComposerIfPossible() {
        let payload = store.mailPayload()

        if MFMailComposeViewController.canSendMail() {
            composerPayload = payload
            return
        }

        guard let mailtoURL = buildMailToURL(from: payload) else {
            showMailUnavailableAlert = true
            return
        }

        openURL(mailtoURL) { accepted in
            if !accepted {
                showMailUnavailableAlert = true
            }
        }
    }

    private func buildMailToURL(from payload: FeedbackMailPayload) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = payload.recipients.joined(separator: ",")
        components.queryItems = [
            URLQueryItem(name: "subject", value: payload.subject),
            URLQueryItem(name: "body", value: payload.plainTextBody)
        ]
        return components.url
    }
}

private struct FeedbackGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(in: .rect(cornerRadius: 26))
        } else {
            content
        }
    }
}

private struct FeedbackAttachmentTile: View {
    let image: UIImage?
    let removeAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(UIColor.secondarySystemFill))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 130, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button(role: .destructive, action: removeAction) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .padding(6)
            }
        }
    }
}

private struct GrowingFeedbackTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 18, left: 14, bottom: 18, right: 14)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.text = text.isEmpty ? placeholder : text
        textView.textColor = text.isEmpty ? .placeholderText : .label
        context.coordinator.isShowingPlaceholder = text.isEmpty
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text, !context.coordinator.isShowingPlaceholder {
            textView.text = text
        }

        if text.isEmpty, !textView.isFirstResponder {
            context.coordinator.showPlaceholder(in: textView)
        } else if context.coordinator.isShowingPlaceholder {
            context.coordinator.hidePlaceholder(in: textView)
        }

        DispatchQueue.main.async {
            measuredHeight = context.coordinator.measuredHeight(for: textView)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingFeedbackTextView
        var isShowingPlaceholder = false

        init(parent: GrowingFeedbackTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if isShowingPlaceholder {
                hidePlaceholder(in: textView)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.measuredHeight = measuredHeight(for: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showPlaceholder(in: textView)
                parent.text = ""
            }
        }

        func showPlaceholder(in textView: UITextView) {
            isShowingPlaceholder = true
            textView.text = parent.placeholder
            textView.textColor = .placeholderText
        }

        func hidePlaceholder(in textView: UITextView) {
            isShowingPlaceholder = false
            textView.text = parent.text
            textView.textColor = .label
        }

        func measuredHeight(for textView: UITextView) -> CGFloat {
            let targetSize = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
            return textView.sizeThatFits(targetSize).height
        }
    }
}
