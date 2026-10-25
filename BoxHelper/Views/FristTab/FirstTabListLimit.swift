//
//  FirstTabListLimit.swift
//  BoxHelper
//

import UIKit

// Die Geräteklasse stammt aus UIKit; auch ihre Aufrufer müssen auf Main laufen.
@MainActor
enum FirstTabListLimit {
    static let alwaysLoadAllKey = "firstTabAlwaysLoadAll"
    static let customLimitKey = "firstTabCustomListLimit"
    // Ohne Nachladebutton werden sofort alle Einträge angezeigt; die gespeicherte Begrenzung bleibt erhalten.
    static let showLoadAllButtonKey = "firstTabShowLoadAllButton"

    static var deviceDefaultLimit: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 50 : 25
    }

    static func limit(customLimit: Int) -> Int {
        // 0 bedeutet, dass noch keine eigene Begrenzung gespeichert wurde.
        customLimit > 0 ? customLimit : deviceDefaultLimit
    }
}
