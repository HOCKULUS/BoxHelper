import WidgetKit

/// Alle Größen verwenden dieselben Kacheln; nur die Anzahl der Zeilen und Spalten wächst.
struct RecentBoxesWidgetLayout {
    let columns: Int
    let rows: Int

    var boxCount: Int { columns * rows }

    init(family: WidgetFamily) {
        switch family {
        case .systemMedium:
            columns = 4
            rows = 2
        case .systemLarge:
            columns = 4
            rows = 4
        case .systemExtraLarge:
            columns = 8
            rows = 4
        default:
            columns = 2
            rows = 2
        }
    }
}
