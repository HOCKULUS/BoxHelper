//
//  PhotoPicker.swift
//  ios-app-test
//
//  Created by HOCKULUS on 12.10.24.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @AppStorage("sliderValue2") private var sliderValue2: Double = 500
    @AppStorage("sliderValue3") private var sliderValue3: Double = 0.5
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, maxSize: sliderValue2, compressionQuality: sliderValue3)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private struct SendableImage: @unchecked Sendable {
            let value: UIImage
        }

        var parent: CameraPicker
        private let maxSize: Double
        private let compressionQuality: CGFloat
        
        init(_ parent: CameraPicker, maxSize: Double, compressionQuality: Double) {
            self.parent = parent
            self.maxSize = maxSize
            self.compressionQuality = CGFloat(max(0.0, min(1.0, compressionQuality)))
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)

            if let image = info[.originalImage] as? UIImage {
                let sendableImage = SendableImage(value: image)
                let maxSize = self.maxSize
                let compressionQuality = self.compressionQuality
                DispatchQueue.global(qos: .userInitiated).async {
                    var processedImage: UIImage?
                    autoreleasepool {
                        let originalImage = sendableImage.value
                        let targetSize = CGSize(width: maxSize, height: maxSize)
                        let resizedImage = originalImage.resizeImage(targetSize: targetSize) ?? originalImage
                        if let compressedData = resizedImage.jpegData(compressionQuality: compressionQuality),
                           let finalImage = UIImage(data: compressedData) {
                            processedImage = finalImage
                        } else {
                            processedImage = originalImage
                        }
                    }
                    DispatchQueue.main.async {
                        if let processedImage {
                            self.parent.images.append(processedImage)
                        }
                    }
                }
            }
        }
    }
}
