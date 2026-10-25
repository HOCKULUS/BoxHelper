import SwiftUI
import UIKit

/// UIKit unterstützt eine echte Auswahl ohne Segment. Damit bleiben
/// Gegenstände ohne Zuordnung möglich, ohne einen „–“-Eintrag zu erfinden.
struct CreateObjectSegments: UIViewRepresentable {
    let choices: [CreateChoice]
    @Binding var selection: UUID?

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl()
        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.names != choices.map(\.name) {
            control.removeAllSegments()
            for (index, choice) in choices.enumerated() { control.insertSegment(withTitle: choice.name, at: index, animated: false) }
            context.coordinator.names = choices.map(\.name)
        }
        control.selectedSegmentIndex = choices.firstIndex(where: { $0.id == selection }) ?? UISegmentedControl.noSegment
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    // UIKit-Ereignisse und die zugehörige SwiftUI-Auswahl gehören zum MainActor.
    @MainActor
    final class Coordinator: NSObject {
        var parent: CreateObjectSegments
        var names: [String] = []
        init(parent: CreateObjectSegments) { self.parent = parent }
        @objc func changed(_ control: UISegmentedControl) {
            guard parent.choices.indices.contains(control.selectedSegmentIndex) else { return }
            parent.selection = parent.choices[control.selectedSegmentIndex].id
        }
    }
}
