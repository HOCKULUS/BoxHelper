import Foundation

/// Bewegungszustand getrennt vom Rendering: Zufallswerte bleiben zwischen Frames stabil.
struct LaunchCloudField {
    struct Cloud: Identifiable {
        let id: Int
        var progress: Double
        var horizontalPosition: Double
        var relativeWidth: Double
        var opacity: Double
        var blurRadius: Double
        var speed: Double
        private let depthRange: ClosedRange<Double>

        init(id: Int, depthRange: ClosedRange<Double>) {
            self.id = id
            self.depthRange = depthRange
            progress = Double.random(in: 0..<1)
            horizontalPosition = 0
            relativeWidth = 0
            opacity = 0
            blurRadius = 0
            speed = 0
            randomizeAppearance()
        }

        mutating func randomizeAppearance() {
            // Die Größenklasse bleibt beim Loop-Wechsel erhalten. So werden
            // aus den vielen kleinen Wolken später keine zusätzlichen großen.
            let depth = Double.random(in: depthRange)
            horizontalPosition = Double.random(in: 0.02...0.98)
            // Ein gemeinsamer Tiefenwert koppelt Transparenz, Größe und Unschärfe:
            // Kleine, transparente Wolken liegen weiter hinten und gleiten langsamer.
            relativeWidth = 0.56 - depth * 0.40
            opacity = 0.75 - depth * 0.57
            blurRadius = 0.5 + depth * 17.5
            speed = 0.075 - depth * 0.05
        }

        var backdropBlurIntensity: Double {
            // Auch der Hintergrund wird bei transparenteren Wolken stärker geblurt.
            return 1 - proximity * 0.35
        }

        var renderedRelativeWidth: Double {
            // Sanftes exponentielles Wachstum pro Durchflug: entfernte Wolken
            // wachsen um etwa 15 %, die nächsten um höchstens 49 %.
            let growthRate = 0.14 + proximity * 0.26
            return relativeWidth * exp(progress * growthRate)
        }

        var renderedHorizontalPosition: Double {
            // Von der Mitte aus sanft nach außen gleiten: rechts nach rechts,
            // links nach links. In der Mitte bleibt die seitliche Bewegung ruhig.
            let horizontalTravel = 0.10 + proximity * 0.24
            let direction = (horizontalPosition - 0.5) * 2
            return horizontalPosition + (progress - 0.5) * horizontalTravel * direction
        }

        private var proximity: Double {
            (opacity - 0.18) / 0.57
        }
    }

    private(set) var clouds: [Cloud] = {
        // 32 Wolken: 20 kleine, 9 mittlere und nur 3 große. Innerhalb jeder
        // Gruppe variieren Größe, Transparenz, Unschärfe und Geschwindigkeit.
        let populations: [(count: Int, depthRange: ClosedRange<Double>)] = [
            (20, 0.675...1.0),
            (9, 0.35...0.675),
            (3, 0.0...0.35)
        ]
        return populations
            .flatMap { Array(repeating: $0.depthRange, count: $0.count) }
            .enumerated()
            .map { Cloud(id: $0.offset, depthRange: $0.element) }
    }()
    private(set) var hasStopped = false
    private var brakingElapsed: TimeInterval = 0
    private let brakingDuration: TimeInterval = 2.5

    mutating func advance(by interval: TimeInterval, isStopping: Bool) {
        guard !hasStopped else { return }
        // Begrenzte Frame-Zeit verhindert sichtbare Sprünge bei kurzen Renderpausen.
        let elapsed = max(0, min(interval, 0.1))
        let travelTime: TimeInterval

        if isStopping {
            let nextElapsed = min(brakingDuration, brakingElapsed + elapsed)
            // Das Integral der fallenden Geschwindigkeit (1 - t / Dauer)²
            // lässt die Wolken kontinuierlich bis zum Stillstand abbremsen.
            travelTime = brakingTravel(at: nextElapsed) - brakingTravel(at: brakingElapsed)
            brakingElapsed = nextElapsed
            hasStopped = brakingElapsed >= brakingDuration
        } else {
            travelTime = elapsed
        }

        for index in clouds.indices {
            // Wachstum und seitliche Position hängen am selben Fortschritt:
            // Beim Abbremsen und Anhalten stoppen dadurch alle Bewegungen gemeinsam.
            clouds[index].progress += clouds[index].speed * travelTime
            if clouds[index].progress >= 1 {
                clouds[index].progress -= 1
                // Erst unterhalb des Bildes neu würfeln, dann oben wieder einsteigen.
                clouds[index].randomizeAppearance()
            }
        }
    }

    private func brakingTravel(at elapsed: TimeInterval) -> TimeInterval {
        let progress = elapsed / brakingDuration
        return brakingDuration * (progress - progress * progress + pow(progress, 3) / 3)
    }
}
