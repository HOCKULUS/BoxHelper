//
//  DocumentPicker.swift
//  ios-app-test
//
//  Created by HOCKULUS on 13.10.24.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileURL: URL?          // Bindung für die ausgewählte Datei-URL
    @Binding var isPresented: Bool              // Bindung zum Anzeigen/Verstecken des Pickers
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.zip])
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false // Nur eine Datei auswählen
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Keine Aktualisierung erforderlich
    }

    // Koordinator für die Delegaten-Methoden
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedFileURL = urls.first else { return }
            
            // Hauptthread für UI-Aktualisierung
            DispatchQueue.main.async {
                self.parent.selectedFileURL = selectedFileURL
                self.parent.isPresented = false // Picker schließen
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Hauptthread für UI-Aktualisierung
            DispatchQueue.main.async {
                self.parent.isPresented = false // Picker schließen
            }
        }
    }
}
