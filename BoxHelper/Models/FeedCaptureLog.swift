import Foundation

/// Ein begrenztes Sitzungsprotokoll ohne Bilder oder erkannte Texte. Alle
/// Mutationen erfolgen auf der Kamera-Queue; der Export enthält eine eigene Legende.
struct FeedCaptureLog: Sendable {
    struct Entry: Codable, Sendable {
        let sequence: Int
        let sessionID: UUID
        let timestamp: Date
        let secondsSinceSessionStart: Double
        let event: String
        let reason: String
        let configuration: FeedMonitoringConfiguration?
        let referenceAdjustmentAllowed: Bool?
        let cameraAvailable: Bool?
        let countdownSeconds: Double?
        let cooldownRemainingSeconds: Double?
        let returnedToBackgroundBeforeComparison: Bool?
        let waitingForStabilityBeforeComparison: Bool?
        let comparisons: FeedDiagnosticsSnapshot?
    }

    struct Export: Encodable {
        let formatVersion = 10
        let exportedAt: Date
        let appVersion: String
        let explanation: [String: String]
        let omittedOldEntries: Int
        let entries: [Entry]
    }

    private(set) var entries: [Entry] = []
    private(set) var omittedOldEntries = 0
    private var sequence = 0
    private var sessionID: UUID?
    private var startedAt = 0.0
    let capacity: Int

    init(capacity: Int = 5_000) { self.capacity = max(1, capacity) }

    mutating func begin(sessionID: UUID, at now: Double, configuration: FeedMonitoringConfiguration,
                        referenceAdjustmentAllowed: Bool, automaticallyAdjustThresholds: Bool = false) {
        self.sessionID = sessionID
        startedAt = now
        record(event: "sessionStarted", reason: automaticallyAdjustThresholds
               ? "Automatische Erfassung gestartet; dynamische Schwellwertstufe"
               : "Automatische Erfassung gestartet; manuelle Schwellwertstufe", at: now,
               configuration: configuration, referenceAdjustmentAllowed: referenceAdjustmentAllowed)
    }

    mutating func record(event: String, reason: String, at now: Double,
                         configuration: FeedMonitoringConfiguration? = nil,
                         referenceAdjustmentAllowed: Bool? = nil, cameraAvailable: Bool? = nil,
                         countdownSeconds: Double? = nil, cooldownRemainingSeconds: Double? = nil,
                         returnedToBackground: Bool? = nil, waitingForStability: Bool? = nil,
                         comparisons: FeedDiagnosticsSnapshot? = nil) {
        guard let sessionID else { return }
        sequence += 1
        entries.append(Entry(sequence: sequence, sessionID: sessionID, timestamp: Date(),
                             secondsSinceSessionStart: max(0, now - startedAt), event: event, reason: reason,
                             configuration: configuration, referenceAdjustmentAllowed: referenceAdjustmentAllowed,
                             cameraAvailable: cameraAvailable, countdownSeconds: countdownSeconds,
                             cooldownRemainingSeconds: cooldownRemainingSeconds,
                             returnedToBackgroundBeforeComparison: returnedToBackground,
                             waitingForStabilityBeforeComparison: waitingForStability,
                             comparisons: comparisons))
        // Blockweise kürzen statt bei jedem Frame das gesamte Array zu verschieben.
        if entries.count > capacity {
            let count = max(1, capacity / 10)
            entries.removeFirst(count)
            omittedOldEntries += count
        }
    }

    func encoded(at date: Date = Date()) throws -> Data {
        let export = Export(exportedAt: date,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            explanation: [
                "purpose": "Chronologisches Automatikprotokoll. Jede comparison enthält den tatsächlichen Entscheidungsgrund, gültige Einstellungen und Vergleichswerte. Aufnahmeauslösung, geliefertes Foto und Speicherergebnis sind getrennte Ereignisse.",
                "time": "timestamp ist UTC (ISO 8601); secondsSinceSessionStart ist monotone Zeit in Sekunden. sessionID trennt Sitzungen, sequence ist die globale Reihenfolge dieses App-Laufs.",
                "difference": "Algorithmus 2: 64 × 64 Messpunkte werden zu 16 × 16 Zellen geglättet. Globale Helligkeit wird per Median ausgeglichen; Zellhelligkeit und lokale Textur werden verglichen. difference = max(globalDifference, 0,6 × stärkster zusammenhängender 2 × 2 Zellbereich). Werte 0…1; für Prozent mit 100 multiplizieren. Übereinstimmung = 1 − difference, keine Wahrscheinlichkeit. changedArea ist der Anteil der Zellen mit mindestens 2 % Differenz.",
                "source": "usesImageReference und usesObjectness sind unabhängig kombinierbar. Bilder: ursprünglicher belichtungsbereinigter 64×64-Vergleich. Objektfinder: nur Vision-Objectness Revision 2, 256px Ausschnitt, Rechtecke ohne Klassen/Heatmap-Beimischung. Kein Tiefen- oder Attention-Modus und kein Modelldownload.",
                "threshold": "backgroundComparison und savedPhotoComparison: difference >= threshold bedeutet Motivänderung. previousComparison und stabilityComparison: difference <= threshold erlaubt Stillhalten. previousComparison verwendet im Countdown den letzten akzeptierten ruhigen Frame, sonst den vorherigen Messframe; verworfene Ausreißer werden nicht übernommen. stabilityComparison prüft die feste Countdownreferenz oder während der ersten Erfassung die Hintergrund-Vorgangsreferenz, inklusive temporärer Toleranzanpassung.",
                "capture": "Gemeinsamer sceneScore >= sceneThreshold (1) gegen Hintergrund und letzte erfolgreiche Aufnahme nötig. imageRatio = Bilddifferenz / fusionImageThreshold; objectRatio = Rechteckdifferenz / fusionObjectThreshold (Basis 0,18, gewählte Sensitivität und Sitzungsanpassung); jeweils 0…2. Beide aktiv: 85% imageRatio + 15% objectRatio; einzeln: jeweiliger Ratio. Ohne Quellen keine Aufnahme. Object-only ohne bestätigte Objekte löst nicht aus. Nur Bildquelle benötigt Vorruhe und Countdown-Ruhe (25% höhere Grenze); Objektpositionen haben keine Ruhebedingung. Countdown braucht drei Sekunden frische Messungen, freie Kamera und abgelaufene Speicherpause.",
                "noise": "Bild-Rauschmarge und Schwellwertanpassungen bleiben sitzungsgebunden. fusionImageThreshold dokumentiert die tatsächlich zur Entscheidung genutzte Bildschwelle. Objektgeometrie wird getrennt und ohne Bild-Ruheprüfung ausgewertet.",
                "dynamic": "Bei gewählter Zauberstab-Stufe werden die Einstellungen während der Sitzung multipliziert: kleine Signale senken die Änderungsschwelle schrittweise; drei direkte oder sechs Abbrüche ohne Foto erhöhen Änderungsmarge und Bewegungstoleranz. Erfolgsserien führen sanft zurück. Anpassungen erfolgen zwischen Countdowns und werden als thresholdAdjusted protokolliert. Die Rausch-Untergrenze bleibt erhalten. Manuelle Stufen 1 und 2 erleichtern zusätzlich das Stillhalten; Stufe 3 entspricht der bisherigen niedrigsten Sensitivität, Stufe 4 ist empfindlicher.",
                "references": "Hintergrund und letzte erfolgreich gespeicherte Motivreferenz sind Medianbilder aus mehreren ruhigen Messframes. Zur erneuten Freigabe desselben Motivs müssen zwei Leer-Frames unter 60 % der Änderungsschwelle liegen. Ein Einzelbild oder Schwellenflattern darf diese Sperre nicht lösen.",
                "state": "returnedToBackgroundBeforeComparison: Motiv war seit dem letzten Foto wieder im Hintergrund; dadurch ist erneutes Einlegen desselben Motivs erlaubt. waitingForStabilityBeforeComparison: Motivänderung bereits erkannt, es wird auf einen ruhigen Frame gewartet. Beide Werte zeigen den Zustand vor diesem Vergleich.",
                "progress": "changeProgress und captureProgress sind auf 0…1 begrenzte Fortschrittswerte. Die Rohdifferenzen in den Vergleichen sind ungekürzt. Fehlende Vergleiche bedeuten: Referenz noch nicht vorhanden.",
                "objects": "Rechtecke müssen in drei direkt aufeinanderfolgenden Messungen zugeordnet werden; bis zu zwei fehlende Treffer bleiben ausgeblendet als Änderungen, danach Entfernung. EMA alpha=0,35 für x/y/Breite/Höhe. Zuordnung über Mittelpunkt und Größe, ohne Kategorien. Rechteckdifferenz = Mittel der begrenzten (2×Mittelpunktdistanz + Breiten-/Höhendifferenz), fehlende/neue Objekte zählen 1. currentObjectRegions, backgroundObjectRegions und savedObjectRegions enthalten die vollständigen normalisierten Rechteckreferenzen (Vision-Ursprung unten links; CGRect als [[x,y],[Breite,Höhe]] kodiert). Nur erfolgreiche Speicherung ersetzt savedObjectRegions.",
                "retention": "Höchstens \(capacity) Ereignisse im Speicher dieses App-Laufs; omittedOldEntries nennt verworfene ältere Ereignisse. Es werden keine Fotos, Namen oder Diktate protokolliert."
            ], omittedOldEntries: omittedOldEntries, entries: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    func export() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BoxHelper-Automatik-\(UUID().uuidString).json")
        try encoded().write(to: url, options: .atomic)
        return url
    }
}
