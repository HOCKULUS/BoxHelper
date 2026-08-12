//
//  FirstTabListLimit.swift
//  BoxHelper
//

import UIKit

enum FirstTabListLimit {
    static let alwaysLoadAllKey = "firstTabAlwaysLoadAll"
    static let customLimitKey = "firstTabCustomListLimit"

    static var deviceDefaultLimit: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 50 : 25
    }

    static func limit(customLimit: Int) -> Int {
        // 0 bedeutet, dass noch keine eigene Begrenzung gespeichert wurde.
        customLimit > 0 ? customLimit : deviceDefaultLimit
    }
}
