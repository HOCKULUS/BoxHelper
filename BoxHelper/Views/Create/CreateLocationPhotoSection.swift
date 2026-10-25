import SwiftUI
import UIKit

/// A location has exactly one optional photo; choosing another replaces its draft preview.
struct CreateLocationPhotoSection: View {
    @Binding var image: UIImage?
    @State private var source: PhotoSource?
    @State private var showCameraUnavailable = false

    private enum PhotoSource: String, Identifiable {
        case gallery, camera
        var id: String { rawValue }
    }

    var body: some View {
        Section {
            CreatePhotoStrip(images: image.map { [$0] } ?? [],
                             openGallery: { source = .gallery },
                             openCamera: {
                                 if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                     source = .camera
                                 } else {
                                     showCameraUnavailable = true
                                 }
                             }, emptySlotCount: 1,
                             removeImage: { _ in image = nil })
        }
        .sheet(item: $source) { selectedSource in
            switch selectedSource {
            case .gallery:
                ImagePicker(selectedImages: replacementImage, selectionLimit: 1)
            case .camera:
                CameraPicker(images: replacementImage)
            }
        }
        .alert("Keine Kamera verfügbar", isPresented: $showCameraUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Wähle stattdessen ein Foto aus der Galerie.")
        }
    }

    private var replacementImage: Binding<[UIImage]> {
        // Pickers receive an empty selection so a new photo replaces, rather than appends to, the old one.
        Binding(get: { [] }, set: { selectedImages in
            if let selectedImage = selectedImages.last { image = selectedImage }
        })
    }
}
