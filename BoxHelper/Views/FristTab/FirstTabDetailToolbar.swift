import SwiftUI

/// Alle Bestandsdetails teilen Menü, Abschlussbutton und Inhaltsauswahl.
/// Die Auswahlleiste verwendet dieselbe native Anordnung wie die Bestandslisten.
struct FirstTabDetailToolbar: ToolbarContent {
    let isSelecting: Bool
    let isEditing: Bool
    let count: Int
    let total: Int
    let selectedColor: Color
    let select: () -> Void
    let edit: () -> Void
    let selectAll: () -> Void
    let move: () -> Void
    let delete: () -> Void
    let finish: () -> Void
    // Zusatzaktionen bleiben optional: Standortdetails drucken und teilen Kisten,
    // während die anderen Detailansichten ihre bisherigen Aktionen beibehalten.
    var canMove = true
    var printSelection: (() -> Void)? = nil
    var share: (() -> Void)? = nil
    var isSharing = false

    var body: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button(
                    allSelected ? "Alles abwählen" : "Alle auswählen",
                    systemImage: allSelected ? "checklist.unchecked" : "checklist.checked",
                    action: selectAll
                )
                .labelStyle(.iconOnly)
                .tint(selectedColor)
                .disabled(total == 0)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if isSelecting || isEditing {
                Button("Done", systemImage: "checkmark", action: finish)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .tint(selectedColor)
            } else {
                Menu {
                    Button("Auswählen", systemImage: "checkmark.circle", action: select)
                    Button("Bearbeiten", systemImage: "pencil", action: edit)
                } label: {
                    Label("Aktionen", systemImage: "ellipsis")
                }
                .menuOrder(.fixed)
            }
        }

        if isSelecting {
            if #available(iOS 26.0, *) {
                ToolbarItemGroup(placement: .bottomBar) { actions }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    // Der Zähler erhält wie in FirstTabToolbar eine eigene Glasfläche.
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

    private var allSelected: Bool { total > 0 && count == total }

    @ViewBuilder private var actions: some View {
        moveButton
        if let printSelection {
            Button("Drucken", systemImage: "printer", action: printSelection)
                .tint(selectedColor)
                .disabled(count == 0)
        }
        if let share {
            Button("Teilen", systemImage: "square.and.arrow.up", action: share)
                .tint(selectedColor)
                .disabled(count == 0 || isSharing)
        }
    }

    private var moveButton: some View {
        Button("Verschieben", systemImage: "arrow.left.arrow.right", action: move)
            .tint(selectedColor)
            .disabled(count == 0 || !canMove)
    }

    private var deleteButton: some View {
        Button("Löschen", systemImage: "trash", role: .destructive, action: delete)
            .tint(.red)
            .disabled(count == 0)
    }

    private var selectionCount: some View {
        Text("\(count) / \(total)")
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("\(count) / \(total) ausgewählt"))
    }
}
