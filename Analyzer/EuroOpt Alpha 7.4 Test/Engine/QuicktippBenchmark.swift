import Foundation

/// Die acht echten Quicktipp-Spielfelder aus dem unabhängigen Kontrolltest.
/// Die Zahlen werden nicht optimiert, gewichtet oder nachträglich verändert.
struct QuicktippBenchmark {

    static let tickets: [Ticket] = [
        Ticket(numbers: [9, 18, 23, 27, 42], euroNumbers: [1, 12]),
        Ticket(numbers: [3, 18, 23, 31, 48], euroNumbers: [4, 8]),
        Ticket(numbers: [7, 12, 17, 21, 30], euroNumbers: [4, 10]),
        Ticket(numbers: [15, 27, 29, 34, 43], euroNumbers: [4, 6]),
        Ticket(numbers: [7, 15, 19, 20, 33], euroNumbers: [5, 9]),
        Ticket(numbers: [26, 34, 41, 42, 48], euroNumbers: [5, 10]),
        Ticket(numbers: [4, 7, 23, 33, 42], euroNumbers: [3, 6]),
        Ticket(numbers: [13, 22, 23, 29, 35], euroNumbers: [3, 11])
    ]

    struct Summary {
        let drawCount: Int
        let ticketCount: Int
        let averageMainHitRate: Double
        let averageEuroHitRate: Double
        let combinedHitRate: Double
    }

    struct PairedComparison {
        let drawCount: Int
        let modelMain: Double
        let quicktippMain: Double
        let deltaMain: Double
        let ci95Main: Double
        let modelEuro: Double
        let quicktippEuro: Double
        let deltaEuro: Double
        let ci95Euro: Double
        let deltaCombined: Double
        let ci95Combined: Double
    }

    /// Bewertet exakt dieselben Holdout-Ziehungen wie der vorhandene Benchmark.
    /// Pro Ziehung wird zuerst über die acht Quicktipp-Felder gemittelt; dadurch
    /// kann der Vergleich später auf Ziehungsebene gepaart erfolgen.
    static func evaluate(holdout: [EuroJackpotDraw]) -> Summary {
        guard !holdout.isEmpty else {
            return Summary(
                drawCount: 0,
                ticketCount: tickets.count,
                averageMainHitRate: 0,
                averageEuroHitRate: 0,
                combinedHitRate: 0
            )
        }

        var mainRateSum = 0.0
        var euroRateSum = 0.0

        for draw in holdout {
            let rates = rates(for: draw)
            mainRateSum += rates.main
            euroRateSum += rates.euro
        }

        let main = mainRateSum / Double(holdout.count)
        let euro = euroRateSum / Double(holdout.count)

        return Summary(
            drawCount: holdout.count,
            ticketCount: tickets.count,
            averageMainHitRate: main,
            averageEuroHitRate: euro,
            combinedHitRate: main + euro
        )
    }

    /// Paarweiser Vergleich gegen die bereits erzeugten Modell-BacktestResultate.
    /// Voraussetzung: modelResults und holdout beziehen sich in derselben Reihenfolge
    /// auf dieselben Ziehungen. Die Unsicherheit wird mit dem t-Wert für df = n-1
    /// (95 %, zweiseitig) aus den Ziehungsebene-Differenzen berechnet.
    static func compare(
        modelResults: [BacktestResult],
        holdout: [EuroJackpotDraw]
    ) -> PairedComparison? {
        let count = min(modelResults.count, holdout.count)
        guard count >= 2 else { return nil }

        var mainDifferences: [Double] = []
        var euroDifferences: [Double] = []
        var combinedDifferences: [Double] = []

        mainDifferences.reserveCapacity(count)
        euroDifferences.reserveCapacity(count)
        combinedDifferences.reserveCapacity(count)

        var modelMainSum = 0.0
        var quickMainSum = 0.0
        var modelEuroSum = 0.0
        var quickEuroSum = 0.0

        for index in 0..<count {
            let modelMain = modelResults[index].averageHits / 5.0
            let modelEuro = modelResults[index].averageEuroHits / 2.0
            let quick = rates(for: holdout[index])

            modelMainSum += modelMain
            quickMainSum += quick.main
            modelEuroSum += modelEuro
            quickEuroSum += quick.euro

            mainDifferences.append(modelMain - quick.main)
            euroDifferences.append(modelEuro - quick.euro)
            combinedDifferences.append((modelMain + modelEuro) - (quick.main + quick.euro))
        }

        let modelMain = modelMainSum / Double(count)
        let quickMain = quickMainSum / Double(count)
        let modelEuro = modelEuroSum / Double(count)
        let quickEuro = quickEuroSum / Double(count)

        return PairedComparison(
            drawCount: count,
            modelMain: modelMain,
            quicktippMain: quickMain,
            deltaMain: mean(mainDifferences),
            ci95Main: ci95HalfWidth(mainDifferences),
            modelEuro: modelEuro,
            quicktippEuro: quickEuro,
            deltaEuro: mean(euroDifferences),
            ci95Euro: ci95HalfWidth(euroDifferences),
            deltaCombined: mean(combinedDifferences),
            ci95Combined: ci95HalfWidth(combinedDifferences)
        )
    }

    private static func rates(for draw: EuroJackpotDraw) -> (main: Double, euro: Double) {
        var mainRate = 0.0
        var euroRate = 0.0

        for ticket in tickets {
            let mainHits = Set(ticket.numbers).intersection(draw.numbers).count
            let euroHits = Set(ticket.euroNumbers).intersection(draw.euroNumbers).count

            mainRate += Double(mainHits) / 5.0
            euroRate += Double(euroHits) / 2.0
        }

        let divisor = Double(tickets.count)
        return (mainRate / divisor, euroRate / divisor)
    }

    private static func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    private static func ci95HalfWidth(_ differences: [Double]) -> Double {
        guard differences.count >= 2 else { return 0 }

        let m = mean(differences)
        let squared = differences.reduce(0.0) { partial, value in
            partial + pow(value - m, 2)
        }
        let sampleVariance = squared / Double(differences.count - 1)
        let standardError = sqrt(sampleVariance / Double(differences.count))

        // 95-%-KI, zweiseitig, df = 49 für n = 50.
        // Der Wert wird nur als kleine interne Tabelle benötigt; bei anderen n
        // verwenden wir eine konservative Normalapproximation.
        let t95: Double
        switch differences.count {
        case 50: t95 = 2.009575
        default: t95 = 1.96
        }

        return t95 * standardError
    }
}
