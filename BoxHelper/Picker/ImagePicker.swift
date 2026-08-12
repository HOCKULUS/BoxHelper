//
//  ImagePicker.swift
//  ios-app-test
//
//  Created by HOCKULUS on 12.10.24.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImagePicker: UIViewControllerRepresentable {
    
    @Binding var selectedImages: [UIImage] // Zum Speichern der ausgewählten Bilder
    var selectionLimit: Int = 0
    @AppStorage("sliderValue2") private var sliderValue2: Double = 500
    @AppStorage("sliderValue3") private var sliderValue3: Double = 0.5
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images // Nur Bilder zulassen
        configuration.selectionLimit = selectionLimit // 0 = keine Begrenzung
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    // Verwalten des PHPickerViewController mit dem Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self, maxSize: sliderValue2, compressionQuality: sliderValue3)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private struct SendableImageData: @unchecked Sendable {
            let value: Data
        }

        var parent: ImagePicker
        private let maxSize: Double
        private let compressionQuality: CGFloat
        
        init(_ parent: ImagePicker, maxSize: Double, compressionQuality: Double) {
            self.parent = parent
            self.maxSize = maxSize
            self.compressionQuality = CGFloat(max(0.0, min(1.0, compressionQuality)))
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                picker.dismiss(animated: true)
                return
            }

            let processedImages = LockedImageBuffer(count: results.count)
            let dispatchGroup = DispatchGroup()

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { continue }

                dispatchGroup.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
                    guard let self = self else {
                        dispatchGroup.leave()
                        return
                    }
                    if let error = error {
                        print("Error loading image data: \(error)")
                        dispatchGroup.leave()
                        return
                    }
                    guard let data else {
                        dispatchGroup.leave()
                        return
                    }

                    let sendableImageData = SendableImageData(value: data)
                    let maxSize = self.maxSize
                    let compressionQuality = self.compressionQuality
                    DispatchQueue.global(qos: .userInitiated).async {
                        autoreleasepool {
                            guard let originalImage = UIImage(data: sendableImageData.value) else {
                                dispatchGroup.leave()
                                return
                            }
                            let targetSize = CGSize(width: maxSize, height: maxSize)
                            let resizedImage = originalImage.resizeImage(targetSize: targetSize) ?? originalImage
                            let finalImage = resizedImage.jpegData(compressionQuality: compressionQuality)
                                .flatMap(UIImage.init(data:))
                                ?? originalImage
                            processedImages.store(finalImage, at: index)
                            dispatchGroup.leave()
                        }
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                // Alle Bilder gesammelt übernehmen, damit keine späten Callbacks verloren gehen.
                self.parent.selectedImages.append(contentsOf: processedImages.compactImages())
                picker.dismiss(animated: true)
            }
        }
    }
}

private final class LockedImageBuffer: @unchecked Sendable {
    private var images: [UIImage?]
    private let lock = NSLock()

    init(count: Int) {
        self.images = Array(repeating: nil, count: count)
    }

    func store(_ image: UIImage, at index: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard images.indices.contains(index) else { return }
        images[index] = image
    }

    func compactImages() -> [UIImage] {
        lock.lock()
        defer { lock.unlock() }
        return images.compactMap { $0 }
    }
}
