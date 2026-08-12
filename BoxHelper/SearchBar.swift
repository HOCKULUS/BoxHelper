//
//  SearchBar.swift
//  ios-app-test
//

import SwiftUI

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    
    class Coordinator: NSObject, UISearchBarDelegate {
        var control: SearchBar
        
        init(control: SearchBar) {
            self.control = control
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            control.text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder() // Schließt die Tastatur
            //if searchBar.
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(control: self)
    }
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        
        // Hintergrund entfernen
        searchBar.backgroundImage = UIImage()
        searchBar.backgroundColor = .clear
        if #available(iOS 26.0, *) {
            if let backgroundView = searchBar.subviews.first?.subviews.first {
                backgroundView.backgroundColor = .clear
                let blur = UIBlurEffect(style: .systemUltraThinMaterial)
                let blurView = UIVisualEffectView(effect: blur)
                blurView.frame = backgroundView.bounds
                blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                backgroundView.insertSubview(blurView, at: 0)
            }
            if let textField = searchBar.value(forKey: "searchField") as? UITextField {
                // Hintergrundfarbe + abgerundete Ecken
                textField.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.2)
                textField.layer.cornerRadius = 20
                textField.clipsToBounds = true
            }
        }
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            // Hintergrundfarbe + abgerundete Ecken
            textField.backgroundColor = UIColor(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white) // Hintergrundfarbe
            textField.layer.cornerRadius = 20
            textField.clipsToBounds = true
            /*
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.autocapitalizationType = .none
            textField.smartDashesType = .no
            textField.smartQuotesType = .no
             */
        }
        
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
}
