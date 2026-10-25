import SwiftUI

/// Die Suchliste beginnt immer links. Nur die einzelne bestätigte Karte und
/// ein neuer Standort ohne Treffer stehen während ihrer Rückmeldung mittig.
struct CreateDictatedLocationList: View {
    @ObservedObject var dictation: AutomaticLocationDictation
    let width: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private enum CardID: Hashable {
        case location(UUID)
        case newLocation
    }

    private struct ScrollRevision: Equatable {
        let locations: [UUID]
        let showsNewLocation: Bool
        let width: CGFloat
        let isCentered: Bool
    }

    private var selectionColor: Color { colorScheme == .dark ? .white : .black }
    private var showsNewLocation: Bool { dictation.showsNewLocation }
    private var isCentered: Bool {
        dictation.selectedChoice != nil || (showsNewLocation && dictation.results.isEmpty)
    }

    var body: some View {
        let results = dictation.results
        let revision = ScrollRevision(locations: results.map(\.id), showsNewLocation: showsNewLocation,
                                      width: width, isCentered: isCentered)
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: CreateDictationFeedbackLayout.locationSpacing) {
                    ForEach(results) { location in
                        locationButton(location)
                            .id(CardID.location(location.id))
                    }
                    if showsNewLocation, let name = dictation.newLocationName {
                        newLocationButton(name: name)
                            .id(CardID.newLocation)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minWidth: width, alignment: isCentered ? .center : .leading)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.leading)
            .onChange(of: revision, initial: true) { _, _ in
                // Neue Suchergebnisse beginnen beim ersten Treffer. Weitere Wörter
                // verändern weder den Listenanfang noch eine manuelle Scrollposition.
                if let first = results.first {
                    proxy.scrollTo(CardID.location(first.id), anchor: .leading)
                } else if showsNewLocation {
                    proxy.scrollTo(CardID.newLocation, anchor: .center)
                }
            }
        }
    }

    private func locationButton(_ location: LocationDictationChoice) -> some View {
        let color = stringToColor(location.color) ?? Color.gray
        let isSelected = dictation.highlightedID == location.id
        return Button { dictation.choose(location.id) } label: {
            locationCard(color: color, isSelected: isSelected) {
                Text(location.name)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(location.name))
        .accessibilityHint(Text("CreateCamera.SelectDictatedLocation"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func newLocationButton(name: String) -> some View {
        let color = stringToColor(dictation.newLocationColor) ?? Color.gray
        return Button(action: dictation.chooseNewLocation) {
            locationCard(color: color, isSelected: true) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                    Text(name)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("CreateCamera.ConfirmNewDictatedLocation"))
        .accessibilityValue(Text(name))
        .accessibilityAddTraits(.isSelected)
    }

    /// Neue und vorhandene Standorte teilen Breite, Textkontrast und Auswahlrahmen.
    private func locationCard<Content: View>(color: Color, isSelected: Bool,
                                            @ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 14)
            .frame(height: CreateDictationFeedbackLayout.locationHeight)
            .frame(maxWidth: max(48, width - 32))
            // Einzelne Karten behalten ihre Namensbreite, auch bei der Bestätigung.
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isColorTooDark(color: color) ? Color.white : Color.black)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
            .overlay { selectionBorder(isSelected: isSelected) }
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private func selectionBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(isSelected ? selectionColor : .clear, lineWidth: 3)
    }
}
