//
//  Tip.swift
//  BoxHelper
//
//  Created by HOCKULUS on 25.05.25.
//
import TipKit

struct helpNeeded : Tip {
    static let saveBoxEvent = Event(id: "noHelpRequired")
    var title: Text {
        Text("Need Help?")
            .foregroundStyle(AccentColorManager().accentColor)
    }
    var message: Text? {Text("Feel free to write me an email to appstore@hockulus.de")}
    var rules: [Rule] {
        #Rule(Self.saveBoxEvent) { event in
            event.donations.count > 2
        }
    }
    //var image: Image? {Image(systemName: "shippingbox")}
}

struct changeImageOrder: Tip {
    var title: Text {
        Text("Change Image Order")
            .foregroundStyle(AccentColorManager().accentColor)
    }
    var message: Text? {Text("Hold and drag images to reorder it. Change the default order in the box settings.")}
    //var image: Image? {Image(systemName: "hand.tap")}
}

struct introduceBoxNaming : Tip {
    static let saveBoxEvent = Event(id: "saveBox")
    var title: Text {
        Text("Box Names")
            .foregroundStyle(AccentColorManager().accentColor)
    }
    var message: Text? {Text("Set a custom naming pattern in the box settings.")}
    var rules: [Rule] {
        #Rule(Self.saveBoxEvent) { event in
            event.donations.count > 2
        }
    }
    //var image: Image? {Image(systemName: "shippingbox")}
}

struct oldIOSVersion : Tip {
    var title: Text {
        Text("Old iOS Version")
            .foregroundStyle(AccentColorManager().accentColor)
    }
    var message: Text? {Text("This app works best with iOS 18 or newer. Some features might not function correctly on your version.")}
    //var image: Image? {Image(systemName: "exclamationmark.triangle")}
}

struct Backup : Tip {
    var title: Text {
        Text("Backup")
            .foregroundStyle(AccentColorManager().accentColor)
    }
    var message: Text? {Text("Consider backing up your data. Go to storage & backup settings to create and export a backup.")}
    //var image: Image? {Image(systemName: "doc.zipper"}
}

struct changeLocationColors: Tip {
    var title: Text {
        Text("Location Colors")
            .foregroundStyle(AccentColorManager().accentColor)
    }

    var message: Text? {
        Text("Use the menu to apply a color palette to all locations.")
    }

    var image: Image? {
        Image(systemName: "paintpalette.fill")
    }
}

struct customizableQRCodeTip: Tip {
    var title: Text {
        Text("QR Code")
            .foregroundStyle(AccentColorManager().accentColor)
    }

    var message: Text? {
        Text("Passe den QR Code an.")
    }

    var image: Image? {
        Image(systemName: "qrcode")
    }
}
