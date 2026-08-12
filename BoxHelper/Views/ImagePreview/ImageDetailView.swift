//
//  ImageDetailView.swift
//  BoxHelper
//
//  Created by admin on 13.02.26.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ImageDetailView: View {
    @Binding var imagePaths: [String]
    @Binding var selectedImagePath: String?
    @Binding var showDetailView: Bool
    var selectedColor: Color
    var onDelete: (String) -> Void

    @AppStorage("imageSortingOption") private var imageSortingOption: String = "new"
    @State private var currentImage: UIImage?
    @State private var currentZoomScale: CGFloat = 1.0
    @State private var isEditing: Bool = false
    @State private var draggedPath: String?
    @State private var displayedPaths: [String] = []
    @State private var navigationDirection: ImageNavigationDirection = .forward

    private var currentPath: String? {
        if let selectedImagePath, displayedPaths.contains(selectedImagePath) {
            return selectedImagePath
        }
        return displayedPaths.first
    }

    private var imageTransition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if let image = currentImage {
                        ZoomableScrollView(zoomScale: $currentZoomScale ) {
                            GeometryReader { proxy in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .blur(radius: 100)
                            }
                        }
                        .id(currentPath ?? UUID().uuidString)
                        .transition(imageTransition)
                       .padding(.all, -100)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(UIColor.systemFill))
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .padding(.horizontal, 0)
                .frame(maxHeight: .infinity)
                VStack(spacing: 12) {
                    ZStack{
                        Group {
                            if let image = currentImage {
                                ZoomableScrollView(zoomScale: $currentZoomScale) {
                                    GeometryReader { proxy in
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: proxy.size.width, height: proxy.size.height)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                    }
                                }
                                .id(currentPath ?? UUID().uuidString)
                                .transition(imageTransition)
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 24)
                                        .onEnded { value in
                                            handleImageSwipe(value)
                                        }
                                )
                            } else {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(UIColor.systemFill))
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        }
                        .padding(.horizontal, 0)
                        .padding(.bottom, 24)
                        .frame(maxHeight: .infinity)
                        VStack {
                            Spacer()
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(displayedPaths, id: \.self) { path in
                                        ZStack(alignment: .topLeading) {
                                            Button {
                                                switchToImage(path)
                                            } label: {
                                                ImageDetailThumbnailView(
                                                    path: path,
                                                    isSelected: path == currentPath,
                                                    selectedColor: selectedColor
                                                )
                                            }
                                            .if(isEditing) { view in
                                                view
                                                    .onDrag {
                                                        draggedPath = path
                                                        return NSItemProvider(object: path as NSString)
                                                    }
                                                    .onDrop(
                                                        of: [UTType.text],
                                                        delegate: ThumbnailReorderDropDelegate(
                                                            imagePaths: $displayedPaths,
                                                            draggedPath: $draggedPath,
                                                            targetPath: path
                                                        )
                                                    )
                                            }

                                            if isEditing {
                                                Button {
                                                    delete(path: path)
                                                } label: {
                                                    Image(systemName: "trash.circle.fill")
                                                        .resizable()
                                                        .frame(width: 40, height: 40)
                                                        .foregroundStyle(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.55)))
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                            .frame(height: 92)
                            //.background(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(1), radius: 7, x: 0, y: -2)
                            if let currentPath, let image = currentImage {
                                HStack(spacing: 12) {
                                    Text(resolutionText(for: image))
                                        .padding(.leading, 8)
                                        .opacity(0.5)
                                        .padding(.vertical, 4)
                                    Text(fileSizeText(for: currentPath))
                                        .opacity(0.5)
                                        .padding(.vertical, 4)
                                    Text(modifiedDateText(for: currentPath))
                                        .padding(.trailing, 8)
                                        .padding(.vertical, 4)
                                        .opacity(0.5)
                                }
                                //.shadow(radius: 5)
                                .font(.footnote)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                
                            }
                        }
                        .padding(.vertical, 200)
                    }
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showDetailView = false
                            } label: {
                                Image(systemName: "chevron.backward")
                                    .foregroundStyle(selectedColor)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditing.toggle()
                                }
                            } label: {
                                Image(systemName: isEditing ? "xmark" : "pencil")
                                    .foregroundStyle(selectedColor)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, -200)
            .background {
                ArrowKeyCaptureView(
                    onLeft: { navigateBackward() },
                    onRight: { navigateForward() }
                )
                .frame(width: 0, height: 0)
            }
        }
        .onAppear(perform: syncSelectionAndPreload)
        .onChange(of: imagePaths) { _, _ in
            syncDisplayedPathsFromSource()
            syncSelectionAndPreload()
        }
        .onChange(of: imageSortingOption) { _, _ in
            syncDisplayedPathsFromSource()
            syncSelectionAndPreload()
        }
        .onChange(of: displayedPaths) { _, newValue in
            applyDisplayedOrderToSource(newValue)
        }
        .onChange(of: selectedImagePath) { _, newValue in
            if let newValue {
                loadCurrentImage(for: newValue)
            } else {
                currentImage = nil
            }
        }
        .animation(.easeInOut(duration: 0.23), value: currentPath)
    }

    private func syncSelectionAndPreload() {
        if imagePaths.isEmpty {
            displayedPaths = []
            selectedImagePath = nil
            currentImage = nil
            showDetailView = false
            return
        }
        if displayedPaths.isEmpty {
            syncDisplayedPathsFromSource()
        }
        if selectedImagePath == nil || !imagePaths.contains(selectedImagePath!) {
            selectedImagePath = displayedPaths.first
        }
        currentZoomScale = 1.0
        if let selectedImagePath {
            loadCurrentImage(for: selectedImagePath)
        }
    }

    private func syncDisplayedPathsFromSource() {
        displayedPaths = imageSortingOption == "new" ? Array(imagePaths.reversed()) : imagePaths
    }

    private func applyDisplayedOrderToSource(_ orderedPaths: [String]) {
        let reordered = imageSortingOption == "new" ? Array(orderedPaths.reversed()) : orderedPaths
        if reordered != imagePaths {
            imagePaths = reordered
        }
    }

    private func loadCurrentImage(for path: String) {
        Task {
            let image = await ImageDetailFullImageLoader.shared.loadImage(path: path)
            guard path == currentPath else { return }
            currentImage = image
            preloadAdjacentImages(around: path)
        }
    }

    private func preloadAdjacentImages(around path: String) {
        guard let index = displayedPaths.firstIndex(of: path) else { return }
        let neighborIndices = [index - 1, index + 1].filter { displayedPaths.indices.contains($0) }

        for neighborIndex in neighborIndices {
            let neighborPath = displayedPaths[neighborIndex]
            Task {
                _ = await ImageDetailFullImageLoader.shared.loadImage(path: neighborPath)
            }
        }
    }

    private func delete(path: String) {
        onDelete(path)
        ImageDetailFullImageLoader.shared.removeCachedImage(for: path)
        ImageDetailThumbnailLoader.shared.removeCachedThumbnail(for: path)
        displayedPaths.removeAll { $0 == path }
        imagePaths.removeAll { $0 == path }

        if displayedPaths.isEmpty {
            selectedImagePath = nil
            showDetailView = false
            return
        }
        if selectedImagePath == path || selectedImagePath == nil {
            selectedImagePath = displayedPaths.first
        }
        applyDisplayedOrderToSource(displayedPaths)
        currentZoomScale = 1.0
        if let selectedImagePath {
            loadCurrentImage(for: selectedImagePath)
        } else {
            currentImage = nil
        }
    }

    private func resolutionText(for image: UIImage) -> String {
        let width = Int((image.size.width * image.scale).rounded())
        let height = Int((image.size.height * image.scale).rounded())
        return "\(width)x\(height)"
    }

    private func fileSizeText(for path: String) -> String {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(path)
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let sizeInBytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        return ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    private func modifiedDateText(for path: String) -> String {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(path)
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let modified = attributes?[.modificationDate] as? Date else {
            return "—"
        }
        return Self.modifiedDateFormatter.string(from: modified)
    }

    private func handleImageSwipe(_ value: DragGesture.Value) {
        guard currentZoomScale <= 1.01 else { return }
        guard abs(value.translation.width) > 40 else { return }
        guard abs(value.translation.width) > abs(value.translation.height) else { return }
        guard let currentPath, let currentIndex = displayedPaths.firstIndex(of: currentPath) else { return }

        if value.translation.width < 0 {
            // Swipe left -> next image
            let nextIndex = currentIndex + 1
            guard nextIndex < displayedPaths.count else { return }
            navigationDirection = .forward
            withAnimation(.easeInOut(duration: 0.23)) {
                selectedImagePath = displayedPaths[nextIndex]
            }
            currentZoomScale = 1.0
        } else {
            // Swipe right -> previous image
            let previousIndex = currentIndex - 1
            guard previousIndex >= 0 else { return }
            navigationDirection = .backward
            withAnimation(.easeInOut(duration: 0.23)) {
                selectedImagePath = displayedPaths[previousIndex]
            }
            currentZoomScale = 1.0
        }
    }

    private func switchToImage(_ path: String) {
        guard path != selectedImagePath else { return }
        if let currentPath,
           let from = displayedPaths.firstIndex(of: currentPath),
           let to = displayedPaths.firstIndex(of: path) {
            navigationDirection = to >= from ? .forward : .backward
        } else {
            navigationDirection = .forward
        }
        withAnimation(.easeInOut(duration: 0.23)) {
            selectedImagePath = path
        }
        loadCurrentImage(for: path)
    }

    private func navigateForward() {
        guard let currentPath,
              let currentIndex = displayedPaths.firstIndex(of: currentPath) else { return }
        let nextIndex = currentIndex + 1
        guard nextIndex < displayedPaths.count else { return }
        navigationDirection = .forward
        withAnimation(.easeInOut(duration: 0.23)) {
            selectedImagePath = displayedPaths[nextIndex]
        }
        currentZoomScale = 1.0
        loadCurrentImage(for: displayedPaths[nextIndex])
    }

    private func navigateBackward() {
        guard let currentPath,
              let currentIndex = displayedPaths.firstIndex(of: currentPath) else { return }
        let previousIndex = currentIndex - 1
        guard previousIndex >= 0 else { return }
        navigationDirection = .backward
        withAnimation(.easeInOut(duration: 0.23)) {
            selectedImagePath = displayedPaths[previousIndex]
        }
        currentZoomScale = 1.0
        loadCurrentImage(for: displayedPaths[previousIndex])
    }
}

private extension ImageDetailView {
    static let modifiedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter
    }()
}

private struct ImageDetailThumbnailView: View {
    let path: String
    let isSelected: Bool
    let selectedColor: Color
    private let side: CGFloat = 72
    private let cacheKey: String

    @State private var image: UIImage?

    init(path: String, isSelected: Bool, selectedColor: Color) {
        self.path = path
        self.isSelected = isSelected
        self.selectedColor = selectedColor
        let pixelSide = Int((side * UIScreen.main.scale).rounded(.up))
        cacheKey = "\(path)#image-detail-thumb#\(pixelSide)"
        _image = State(initialValue: ImageDetailMemoryCache.shared.image(for: cacheKey))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.systemFill))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? selectedColor : Color.clear, lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)
        .task(id: cacheKey) {
            if image == nil {
                image = ImageDetailMemoryCache.shared.image(for: cacheKey)
            }
            guard image == nil else { return }
            image = await ImageDetailThumbnailLoader.shared.loadThumbnail(path: path, cacheKey: cacheKey, maxPixelSize: side * UIScreen.main.scale)
        }
    }
}

@MainActor
private final class ImageDetailFullImageLoader {
    static let shared = ImageDetailFullImageLoader()

    private var runningTasks: [String: Task<UIImage?, Never>] = [:]

    func loadImage(path: String) async -> UIImage? {
        let cacheKey = "\(path)#image-detail-full"
        if let cachedImage = ImageDetailMemoryCache.shared.image(for: cacheKey) {
            return cachedImage
        }

        if let runningTask = runningTasks[cacheKey] {
            return await runningTask.value
        }

        let task = Task<UIImage?, Never>(priority: .userInitiated) {
            guard let image = UserDefaultsManager.shared.loadImage(from: path) else { return nil }
            if #available(iOS 15.0, *) {
                return await image.byPreparingForDisplay() ?? image
            }
            return image
        }

        runningTasks[cacheKey] = task
        let image = await task.value
        runningTasks[cacheKey] = nil

        if let image {
            ImageDetailMemoryCache.shared.insert(image, for: cacheKey)
        }

        return image
    }

    func removeCachedImage(for path: String) {
        let prefix = "\(path)#image-detail-full"
        for key in runningTasks.keys.filter({ $0.hasPrefix(prefix) }) {
            runningTasks[key]?.cancel()
            runningTasks[key] = nil
        }
        ImageDetailMemoryCache.shared.removeCachedEntries(withPrefix: prefix)
    }
}

@MainActor
private final class ImageDetailThumbnailLoader {
    static let shared = ImageDetailThumbnailLoader()

    private var runningTasks: [String: Task<UIImage?, Never>] = [:]

    func loadThumbnail(path: String, cacheKey: String, maxPixelSize: CGFloat) async -> UIImage? {
        if let cachedImage = ImageDetailMemoryCache.shared.image(for: cacheKey) {
            return cachedImage
        }

        if let runningTask = runningTasks[cacheKey] {
            return await runningTask.value
        }

        let task = Task<UIImage?, Never>(priority: .utility) {
            UserDefaultsManager().loadThumbnail(from: path, maxPixelSize: maxPixelSize)
        }

        runningTasks[cacheKey] = task
        let image = await task.value
        runningTasks[cacheKey] = nil

        if let image {
            ImageDetailMemoryCache.shared.insert(image, for: cacheKey)
        }

        return image
    }

    func removeCachedThumbnail(for path: String) {
        let prefix = "\(path)#image-detail-thumb#"
        for key in runningTasks.keys.filter({ $0.hasPrefix(prefix) }) {
            runningTasks[key]?.cancel()
            runningTasks[key] = nil
        }
        ImageDetailMemoryCache.shared.removeCachedEntries(withPrefix: prefix)
    }
}

private final class ImageDetailMemoryCache: @unchecked Sendable {
    static let shared = ImageDetailMemoryCache()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var cachedKeys: Set<String> = []

    private init() {
        cache.countLimit = 300
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        lock.lock()
        cachedKeys.insert(key)
        lock.unlock()
        cache.setObject(image, forKey: key as NSString)
    }

    func removeCachedEntries(withPrefix prefix: String) {
        lock.lock()
        let matchingKeys = cachedKeys.filter { $0.hasPrefix(prefix) }
        matchingKeys.forEach { cachedKeys.remove($0) }
        lock.unlock()

        for key in matchingKeys {
            cache.removeObject(forKey: key as NSString)
        }
    }
}

enum ImageNavigationDirection {
    case forward
    case backward
}

private struct ArrowKeyCaptureView: UIViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void

    func makeUIView(context: Context) -> ArrowKeyCaptureUIView {
        let view = ArrowKeyCaptureUIView()
        view.onLeft = onLeft
        view.onRight = onRight
        return view
    }

    func updateUIView(_ uiView: ArrowKeyCaptureUIView, context: Context) {
        uiView.onLeft = onLeft
        uiView.onRight = onRight
        DispatchQueue.main.async {
            _ = uiView.becomeFirstResponder()
        }
    }
}

private final class ArrowKeyCaptureUIView: UIView {
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleLeft)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleRight))
        ]
    }

    @objc private func handleLeft() {
        onLeft?()
    }

    @objc private func handleRight() {
        onRight?()
    }
}

struct ThumbnailReorderDropDelegate: DropDelegate {
    @Binding var imagePaths: [String]
    @Binding var draggedPath: String?
    let targetPath: String

    func dropEntered(info: DropInfo) {
        guard let draggedPath,
              draggedPath != targetPath,
              let fromIndex = imagePaths.firstIndex(of: draggedPath),
              let toIndex = imagePaths.firstIndex(of: targetPath) else { return }

        withAnimation {
            imagePaths.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPath = nil
        return true
    }
}

struct SortedImageReorderDropDelegate: DropDelegate {
    @Binding var imagePaths: [String]
    @Binding var draggedPath: String?
    let targetPath: String
    let sortOption: String
    var onReorderCompleted: (() -> Void)? = nil

    func dropEntered(info: DropInfo) {
        guard let draggedPath,
              draggedPath != targetPath else { return }

        var displayedPaths = sortOption == "new" ? Array(imagePaths.reversed()) : imagePaths

        guard let fromIndex = displayedPaths.firstIndex(of: draggedPath),
              let toIndex = displayedPaths.firstIndex(of: targetPath) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            displayedPaths.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
            imagePaths = sortOption == "new" ? Array(displayedPaths.reversed()) : displayedPaths
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPath = nil
        onReorderCompleted?()
        return true
    }
}
