//
//  extensions.swift
//  BoxHelper
//
//  Created by HOCKULUS on 20.01.25.
//

import UIKit
import SwiftUI
import CloudKit

// Helper Funktion um die Tastatur auszublenden
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// `.if` als Erweiterung
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Swipe nach rechts erkennen
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        
        // Swipe nach links erkennen
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
    }

    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .right {
            print("Swipe nach rechts erkannt")
            // Hier kannst du deine Logik für den Swipe nach rechts implementieren
        } else if gesture.direction == .left {
            print("Swipe nach links erkannt")
            // Hier kannst du deine Logik für den Swipe nach links implementieren
        }
    }
}
extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}
extension UIImage {
    func resizeImage(targetSize: CGSize) -> UIImage? {
        let size = self.size

        let widthRatio  = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        // Bestimmen des Skalierungsfaktors (um das Bild innerhalb der Begrenzung zu halten)
        let scaleFactor = min(widthRatio, heightRatio)

        let newSize = CGSize(
            width: (size.width * scaleFactor).rounded(.down),
            height: (size.height * scaleFactor).rounded(.down)
        )
        
        // Verwenden von UIGraphicsImageRenderer
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func compressImage() -> Data? {
        @AppStorage("sliderValue3") var sliderValue3: Double = 0.5
        // Komprimieren des Bildes auf eine Qualitätsstufe von 0.5
        return self.jpegData(compressionQuality: sliderValue3)
    }
}

extension Color {
    static let customTurquoise = Color(red: 0.25, green: 0.88, blue: 0.82)
    static let customCoral = Color(red: 1.0, green: 0.45, blue: 0.36)
    static let customLavender = Color(red: 0.73, green: 0.53, blue: 0.96)
    static let customSunYellow = Color(red: 1.0, green: 0.87, blue: 0.2)
    static let customPastelPink = Color(red: 1.0, green: 0.75, blue: 0.8)
    static let customRed = Color(red: 0.7, green: 0.2, blue: 0.18)
    static let customMidnightBlue = Color(red: 0.2, green: 0.2, blue: 0.54)
    static let customVibrantOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let customMint = Color(red: 0.52, green: 0.80, blue: 0.72)
    static let customIceBlue = Color(red: 0.5, green: 0.7, blue: 0.8)
    static let customCarmine = Color(red: 0.8, green: 0.0, blue: 0.2)
    static let customDarkGreen = Color(red: 0.0, green: 0.54, blue: 0.4)
    static let customNeonPink = Color(red: 1.0, green: 0.1, blue: 0.6)
    static let customGray = Color(red: 0.35, green: 0.35, blue: 0.35)
    static let customBlueGreen = Color(red: 0, green: 0.45, blue: 0.45)
    static let customGreen = Color(red: 0.32, green: 0.49, blue: 0.05)

    static func settingsRainbowColor(position: Int, total: Int, colorScheme: ColorScheme) -> Color {
        let safeTotal = max(total, 1)
        let safePosition = ((position % safeTotal) + safeTotal) % safeTotal
        let hue = Double(safePosition) / Double(safeTotal)
        let saturation = colorScheme == .dark ? 0.92 : 0.92
        let brightness = colorScheme == .dark ? 0.64 : 0.86
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

// Benutzerdefinierte Erweiterung zur Umwandlung von Color zu Hex und zurück
extension Color {
    // Umwandeln einer Color in einen Hex-String
    func toHex() -> String {
        if let uiColor = UIColor(self).cgColor.components {
            let red = uiColor[0]
            let green = uiColor[1]
            let blue = uiColor[2]
            let hex = String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
            return hex
        }
        return "000000" // Fallback, falls keine gültige Umwandlung möglich
    }

    // Umwandeln eines Hex-Strings zurück in eine Color
    static func fromHex(hex: String) -> Color {
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        if scanner.scanHexInt64(&hexNumber) {
            let red = Double((hexNumber & 0xFF0000) >> 16) / 255.0
            let green = Double((hexNumber & 0x00FF00) >> 8) / 255.0
            let blue = Double(hexNumber & 0x0000FF) / 255.0
            return Color(red: red, green: green, blue: blue)
        }
        return .black // Standardfarbe, falls ein Fehler auftritt
    }
}

extension NumberFormatter {
    static var integerOnly: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }
}

/*
extension UIApplication {
    /// Funktion zum Beenden der Bearbeitung und Ausblenden der Tastatur
    func endEditing(_ force: Bool) {
        if let windowScene = self.connectedScenes.first as? UIWindowScene {
            windowScene.windows
                .filter { $0.isKeyWindow }
                .first?
                .endEditing(force)
        }
    }
}
*/
