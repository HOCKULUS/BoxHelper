import Foundation

/// Bilder werden durch ihre Zuordnung verschoben. Die Bilddatei selbst bleibt unverändert.
enum ImageMoveTarget: Hashable {
    case box(UUID)
    case item(UUID)
    case unassigned
}

struct ImageMoveSelection: Hashable {
    let source: ImageMoveTarget
    let storageIndex: Int
    let filename: String
}

enum ImageMoveError: LocalizedError {
    case changedSelection

    var errorDescription: String? {
        String(localized: "ImageMove.SelectionChanged")
    }
}

enum ImageMove {
    static func imageNames(for owner: ImageMoveTarget, boxes: [MovingBox], items: [Items], unassigned: [String] = []) -> [String]? {
        switch owner {
        case .box(let id): return boxes.first { $0.id == id }?.images
        case .item(let id): return items.first { $0.id == id }?.images
        case .unassigned: return unassigned
        }
    }

    static func apply(_ selection: [ImageMoveSelection], to target: ImageMoveTarget,
                      boxes: inout [MovingBox], items: inout [Items], unassigned: [String] = []) throws {
        guard target != .unassigned, !selection.isEmpty, imageNames(for: target, boxes: boxes, items: items) != nil else {
            throw ImageMoveError.changedSelection
        }
        // Erst alle Zuordnungen prüfen: veraltete Indizes dürfen niemals ein anderes Bild verschieben.
        for image in selection {
            guard let names = imageNames(for: image.source, boxes: boxes, items: items, unassigned: unassigned),
                  names.indices.contains(image.storageIndex), names[image.storageIndex] == image.filename else {
                throw ImageMoveError.changedSelection
            }
        }
        let moving = selection.filter { $0.source != target }
        guard !moving.isEmpty else { return }
        let grouped = Dictionary(grouping: moving, by: \.source)
        for (owner, images) in grouped {
            let indices = Set(images.map(\.storageIndex)).sorted(by: >)
            switch owner {
            case .unassigned: break // Keine Objektzuordnung zu entfernen.
            case .box(let id):
                if let index = boxes.firstIndex(where: { $0.id == id }) {
                    for imageIndex in indices { boxes[index].images.remove(at: imageIndex) }
                }
            case .item(let id):
                if let index = items.firstIndex(where: { $0.id == id }) {
                    for imageIndex in indices { items[index].images.remove(at: imageIndex) }
                }
            }
        }
        // Gemeinsam verwendete Dateien werden am Ziel nur einmal angehängt; andere Zuordnungen bleiben erhalten.
        var names = imageNames(for: target, boxes: boxes, items: items)!
        var attached = Set(names)
        for image in moving where attached.insert(image.filename).inserted { names.append(image.filename) }
        switch target {
        case .unassigned: throw ImageMoveError.changedSelection
        case .box(let id):
            if let index = boxes.firstIndex(where: { $0.id == id }) { boxes[index].images = names }
        case .item(let id):
            if let index = items.firstIndex(where: { $0.id == id }) { items[index].images = names }
        }
    }
}
