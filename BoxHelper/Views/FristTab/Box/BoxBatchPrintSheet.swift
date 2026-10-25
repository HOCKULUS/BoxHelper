import SwiftUI
import PDFKit

/// Separater Druckauftrag: Vorschau und Druck teilen dieselbe PDF-Datei.
struct BoxBatchPrintSheet: View {
    let boxes: [MovingBox]
    let locations: [Locations]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings = BoxBatchPrintSettings()
    @State private var document: PDFDocument?
    @State private var pdfData: Data?
    @State private var renderedSettings: BoxBatchPrintSettings?
    @State private var showHint = false
    @State private var errorMessage: String?
    @State private var printingError = false
    @State private var shareURL: URL?
    // Ein eigener Ordner verhindert Kollisionen zwischen mehreren Druckdialogen.
    @State private var shareDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("BoxHelper-QR-\(UUID().uuidString)", isDirectory: true)

    var body: some View {
        NavigationStack {
            Form {
                if showHint {
                    Section {
                        Label("QRBatchPrint.EcoHint", systemImage: "leaf.fill")
                            .foregroundStyle(.secondary).font(.subheadline)
                    }
                }
                Section {
                    if let document {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 12) {
                                ForEach(0..<document.pageCount, id: \.self) { index in
                                    if let page = document.page(at: index) {
                                        QRPrintPageThumbnail(page: page)
                                            .frame(width: 140, height: 198)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .overlay {
                                                if colorScheme == .light {
                                                    // Der Rahmen liegt vollständig innerhalb der Seitenkante.
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                                                        .allowsHitTesting(false)
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .frame(height: 198)
                        // Die Maske umfasst den sichtbaren Scrollbereich ohne vertikalen
                        // Innenabstand. So werden auch mitten in einer Seite die oberen
                        // und unteren Ecken an der linken und rechten Kante abgeschnitten.
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    else { ProgressView() }
                }
                Section {
                    Picker("Print Layout", selection: $settings.perPage) {
                        ForEach([1, 2, 4, 8, 9, 16], id: \.self) { value in
                            Text(value == 8 ? "2×4" : value == 2 ? "1×2" : "\(Int(sqrt(Double(value))))×\(Int(sqrt(Double(value))))").tag(value)
                        }
                    }
                    Stepper("QRBatchPrint.Copies \(settings.copies)", value: $settings.copies, in: 1...99)
                    Toggle("Dynamic scaling", isOn: $settings.dynamic)
                    Toggle("BoxHelper", isOn: $settings.logo)
                    Toggle("CreateView.BoxTitle", isOn: $settings.name)
                    Toggle("CreateView.Location", isOn: $settings.location)
                    Toggle("Print location color", isOn: $settings.locationColor).disabled(!settings.location)
                    Toggle("ShortURL", isOn: $settings.shortURL)
                    Toggle("Tiny QR Code", isOn: $settings.tiny)
                    Toggle("Horizontal layout", isOn: $settings.horizontal)
                } footer: { Text("QRBatchPrint.TemporarySettings") }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(QRPrintScrollEdgeBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if let shareURL, renderedSettings == settings {
                        ShareLink(item: shareURL) {
                            Label("Teilen", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                printButton
                    .disabled(pdfData == nil || renderedSettings != settings)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .task {
                let count = UserDefaults.standard.integer(forKey: "qrBatchPrintEcoHintDisplays")
                guard count < 3 else { return }
                UserDefaults.standard.set(count + 1, forKey: "qrBatchPrintEcoHintDisplays")
                showHint = true
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                withAnimation { showHint = false }
            }
            .task(id: settings) {
                pdfData = nil
                shareURL = nil
                // Schnelle Schalterfolgen zusammenfassen, statt jede Zwischenstufe zu rendern.
                do {
                    try await Task.sleep(for: .milliseconds(180))
                    try Task.checkCancellation()
                    let data = try BoxBatchPrintDocument.render(boxes: boxes, locations: locations, settings: settings)
                    document = PDFDocument(data: data)
                    pdfData = data
                    renderedSettings = settings
                    errorMessage = nil
                    // Teilen verwendet exakt das PDF aus Vorschau und Druckauftrag.
                    try FileManager.default.createDirectory(at: shareDirectory, withIntermediateDirectories: true)
                    let url = shareDirectory.appendingPathComponent("BoxHelper QR Codes.pdf")
                    try data.write(to: url, options: .atomic)
                    shareURL = url
                } catch is CancellationError { }
                catch { document = nil; errorMessage = String(localized: "QRBatchPrint.RenderError") }
            }
            .alert("QRBatchPrint.PrintError", isPresented: $printingError) { Button("OK", role: .cancel) {} }
        }
    }

    @ViewBuilder private var printButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: printDocument) {
                Label("Drucken", systemImage: "printer.fill")
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
        } else {
            Button(action: printDocument) {
                Label("Drucken", systemImage: "printer.fill")
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func printDocument() {
        guard let pdfData, renderedSettings == settings else { return }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = "BoxHelper QR Codes"
        info.outputType = .general
        controller.printInfo = info
        controller.printingItem = pdfData
        let completion: UIPrintInteractionController.CompletionHandler = { _, _, error in
            if error != nil { Task { @MainActor in printingError = true } }
        }
        // iPad benötigt einen Anker in der aktuell dargestellten Druckansicht.
        // Das iPhone verwendet das normale systemweite Druckblatt.
        if UIDevice.current.userInterfaceIdiom == .pad {
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = scene.windows.first(where: \.isKeyWindow),
                  var presenter = window.rootViewController else { printingError = true; return }
            while let presented = presenter.presentedViewController { presenter = presented }
            let view = presenter.view!
            let anchor = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 70, width: 1, height: 1)
            if !controller.present(from: anchor, in: view, animated: true, completionHandler: completion) { printingError = true }
        } else if !controller.present(animated: true, completionHandler: completion) { printingError = true }
    }
}

/// Der Rand-Blur der Form ist unabhängig vom Navigationsleisten-Hintergrund.
private struct QRPrintScrollEdgeBackground: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: [.top, .bottom])
        } else {
            content
        }
    }
}

/// Nur sichtbare Seiten werden als kleine Rastervorschau gehalten.
private struct QRPrintPageThumbnail: View {
    let page: PDFPage
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { ProgressView() }
        }
        .task(id: ObjectIdentifier(page)) { image = page.thumbnail(of: CGSize(width: 280, height: 396), for: .mediaBox) }
        .onDisappear { image = nil }
    }
}
