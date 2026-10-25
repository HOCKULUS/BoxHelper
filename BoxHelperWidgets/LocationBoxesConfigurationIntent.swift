import AppIntents

struct LocationBoxesConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Boxes by location"
    static let description = IntentDescription("Choose a location to see its recently changed boxes.")
    static let isDiscoverable = false

    @Parameter(title: "Location")
    var location: WidgetLocationEntity?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$location
        }
    }
}
