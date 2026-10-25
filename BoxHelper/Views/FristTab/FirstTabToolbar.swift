import SwiftUI

struct FirstTabSelectionActiveKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// Gemeinsames Menü und native Auswahlleiste für alle vier Bestandslisten.
struct FirstTabToolbar<Options: View>: ToolbarContent {
    @Binding var isEditing: Bool
    @ObservedObject var transfer: InventoryTransferController
    let count: Int
    let total: Int
    let selectedColor: Color
    /// Der Bilder-Tab exportiert Einzeldateien, bietet aber keinen Import an.
    var allowImport = true
    var canMove = true
    var move: (() -> Void)? = nil
    var printSelection: (() -> Void)? = nil
    let share: () -> Void
    let delete: () -> Void
    let selectAll: () -> Void
    let finish: () -> Void
    @ViewBuilder var options: () -> Options

    var body: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button(
                    count == total && total > 0 ? "Alles abwählen" : "Alle auswählen",
                    systemImage: count == total && total > 0 ? "checklist.unchecked" : "checklist.checked",
                    action: selectAll
                )
                .labelStyle(.iconOnly)
                .tint(selectedColor)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isEditing {
                Button("Done", systemImage: "checkmark") {
                    finish()
                    setEditing(false)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .tint(selectedColor)
            } else {
                Menu {
                    Button("Auswählen", systemImage: "checkmark.circle") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        setEditing(true)
                    }
                    if allowImport {
                        Divider()
                        Button("Importieren", systemImage: "square.and.arrow.down") { transfer.showFilePicker = true }
                    }
                    Divider()
                    options()
                } label: {
                    Label("Aktionen", systemImage: "ellipsis")
                }
                // Die deklarierte Reihenfolge bleibt auf iOS 18 und iOS 26 gleich.
                .menuOrder(.fixed)
            }
        }
        if isEditing {
            // iOS 26 trennt die gemeinsame Aktionsgruppe und das destruktive Einzelziel nativ.
            if #available(iOS 26.0, *) {
                ToolbarItemGroup(placement: .bottomBar) { actions }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    // Der Zähler erhält eine eigene ovale Glasfläche, unabhängig
                    // vom gemeinsamen Hintergrund der benachbarten Aktionen.
                    selectionCount
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: Capsule())
                }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) { deleteButton }
            } else {
                ToolbarItemGroup(placement: .bottomBar) {
                    actions
                    Spacer()
                    selectionCount
                    Spacer()
                    deleteButton
                }
            }
        }
    }

    @ViewBuilder private var actions: some View {
        if let move {
            Button("Verschieben", systemImage: "arrow.left.arrow.right", action: move)
                .disabled(count == 0 || !canMove)
        }
        if let printSelection {
            Button("Drucken", systemImage: "printer", action: printSelection).disabled(count == 0)
        }
        Button("Teilen", systemImage: "square.and.arrow.up", action: share).disabled(count == 0 || transfer.isBusy)
    }

    private var selectionCount: some View {
        Text("\(count) / \(total)")
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        .accessibilityLabel(Text("\(count) / \(total) ausgewählt"))
    }

    private var deleteButton: some View {
        Button("Löschen", systemImage: "trash", role: .destructive, action: delete)
            .tint(.red).disabled(count == 0)
    }

    /// Ändert die gemeinsame Auswahlbindung. FirstTabSelectionMode leitet daraus
    /// den nativen Modus ab, ebenso bei Änderungen außerhalb dieser Toolbar.
    private func setEditing(_ active: Bool) {
        withAnimation(.snappy) {
            isEditing = active
        }
    }
}

/// Ab iOS 26 schweben die einzelnen Aktionsgruppen über dem Listeninhalt.
/// Toolbar-Unterlage und Scroll-Rand-Blur werden ausgeblendet; die Glasflächen bleiben.
struct FirstTabSelectionBarBackground: ViewModifier {
    let isEditing: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .toolbarBackground(isEditing ? .hidden : .automatic, for: .bottomBar)
                // iOS 26 zeichnet diesen Blur unabhängig vom Toolbar-Hintergrund.
                // Nur den unteren Rand im Auswahlmodus abschalten, die Suche bleibt unberührt.
                .scrollEdgeEffectHidden(isEditing, for: .bottom)
        } else {
            content
        }
    }
}

protocol FirstTabSortCriterion: Hashable, CaseIterable {
    var localized: String { get }
    var iconName: String { get }
}

/// Sortierkriterien bleiben bei der jeweiligen Liste; Aufbau und Reihenfolge sind überall gleich.
struct FirstTabSortOptions<Criterion: FirstTabSortCriterion>: View {
    @Binding var criterion: Criterion
    @Binding var ascending: Bool
    @Binding var list: String

    var body: some View {
        Section {
            // Einzelne native Menüoptionen vermeiden die zusätzliche Gruppe
            // eines Inline-Pickers und damit den Trenner unter der Überschrift.
            Text("Sortierung")
            ForEach(Array(Criterion.allCases), id: \.self) { value in
                FirstTabMenuChoice(title: LocalizedStringKey(value.localized), icon: value.iconName,
                                   value: value, selection: $criterion)
            }
        }
        Section {
            Text("Reihenfolge")
            FirstTabMenuChoice(title: "Aufsteigend", icon: "arrowshape.up.circle.fill",
                               value: true, selection: $ascending)
            FirstTabMenuChoice(title: "Absteigend", icon: "arrowshape.down.circle.fill",
                               value: false, selection: $ascending)
        }
        Section {
            Text("Liste")
            FirstTabMenuChoice(title: "Boxes", icon: "shippingbox.fill", value: "boxes", selection: $list)
            FirstTabMenuChoice(title: "Items", icon: "square.grid.2x2.fill", value: "items", selection: $list)
            FirstTabMenuChoice(title: "Locations", icon: "location.fill", value: "locations", selection: $list)
            FirstTabMenuChoice(title: "Images", icon: "photo.stack.fill", value: "images", selection: $list)
        }
    }
}

/// Native Menühäkchen für eine exklusive Auswahl ohne zusätzliche Picker-Trenner.
private struct FirstTabMenuChoice<Value: Equatable>: View {
    let title: LocalizedStringKey
    let icon: String
    let value: Value
    @Binding var selection: Value

    var body: some View {
        Toggle(isOn: Binding(
            get: { selection == value },
            // Die aktive Option kann nicht abgewählt werden: Eine Wahl bleibt bestehen.
            set: { if $0 { selection = value } }
        )) {
            Label(title, systemImage: icon)
        }
    }
}
