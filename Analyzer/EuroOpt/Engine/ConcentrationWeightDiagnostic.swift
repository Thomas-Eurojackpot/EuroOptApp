import Foundation

struct ConcentrationWeightDiagnostic {

    private let variants: [(name: String, alpha: Double, concentration: Double)] = [
        ("A100", 1.00, 0.00),
        ("A80C20", 0.80, 0.20),
        ("A70C30", 0.70, 0.30),
        ("A60C40", 0.60, 0.40),
        ("C100", 0.00, 1.00)
    ]

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        splitCount: Int = 10
    ) {
        let holdoutSize = 40
        let minimumTrainingSize = 300

        guard draws.count > minimumTrainingSize + holdoutSize else {
            print("❌ Konzentrationsvergleich: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let candidateCount = max(
            AppSettings.backtestCandidateCount + 1,
            301
        )

        let generator = TicketGenerator()

        let firstHoldoutStart = minimumTrainingSize
        let lastHoldoutStart = draws.count - holdoutSize
        let availableRange = lastHoldoutStart - firstHoldoutStart

        var totals = variants.map {
            (
                name: $0.name,
                main: 0.0,
                euro: 0.0,
                score: 0.0,
                wins: 0
            )
        }

        print("")
        print("===================================")
        print("🧪 ALPHA / KONZENTRATION – ABLATION")
        print("===================================")
        print("Splits              : \(splitCount)")
        print("Holdout je Split    : \(holdoutSize)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("⚡ Kandidaten/Scores werden je Holdout nur einmal berechnet.")
        print("")

        for split in 0..<splitCount {

            let holdoutStart: Int

            if splitCount == 1 {
                holdoutStart = firstHoldoutStart
            } else {
                holdoutStart = firstHoldoutStart
                    + Int(
                        (Double(split) / Double(splitCount - 1))
                        * Double(availableRange)
                    )
            }

            let holdoutEnd = holdoutStart + holdoutSize

            var splitTotals = variants.map {
                (
                    name: $0.name,
                    main: 0,
                    euro: 0,
                    tickets: 0
                )
            }

            for index in holdoutStart..<holdoutEnd {

                let targetDraw = draws[index]
                let trainingDraws = Array(draws.prefix(index))

                // -------------------------------------------------
                // 1. Kandidaten EINMAL erzeugen
                // -------------------------------------------------

                let candidates = generator.generate(
                    count: candidateCount,
                    draws: trainingDraws,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )

                // -------------------------------------------------
                // 2. Alpha EINMAL berechnen
                // -------------------------------------------------

                let scoreEngine = ScoreEngine(
                    goal: OptimizationGoal()
                )

                let alphaScores = candidates.map {
                    scoreEngine.score(
                        ticket: $0,
                        draws: trainingDraws
                    )
                }

                // -------------------------------------------------
                // 3. Konzentration EINMAL berechnen
                // -------------------------------------------------

                let concentration = concentrationScores(
                    candidates: candidates,
                    draws: trainingDraws
                )

                // -------------------------------------------------
                // 4. Beide Werte EINMAL normalisieren
                // -------------------------------------------------

                let normalizedAlpha = normalize(alphaScores)
                let normalizedConcentration = normalize(concentration)

                // -------------------------------------------------
                // 5. Jetzt nur noch die fünf Gewichtungen testen
                // -------------------------------------------------

                for variantIndex in variants.indices {

                    let variant = variants[variantIndex]

                    let rankedIndices = candidates.indices.sorted {
                        let lhs =
                            variant.alpha * normalizedAlpha[$0]
                            + variant.concentration
                            * normalizedConcentration[$0]

                        let rhs =
                            variant.alpha * normalizedAlpha[$1]
                            + variant.concentration
                            * normalizedConcentration[$1]

                        if lhs == rhs {
                            return $0 < $1
                        }

                        return lhs > rhs
                    }

                    var selected: [Ticket] = []

                    for candidateIndex in rankedIndices.prefix(
                        min(36, rankedIndices.count)
                    ) {
                        let ticket = candidates[candidateIndex]

                        if selected.allSatisfy({
                            commonNumbers($0, ticket) < 3
                        }) {
                            selected.append(ticket)
                        }

                        if selected.count == recommendationCount {
                            break
                        }
                    }

                    for ticket in selected {

                        splitTotals[variantIndex].main +=
                            Set(ticket.numbers)
                                .intersection(targetDraw.numbers)
                                .count

                        splitTotals[variantIndex].euro +=
                            Set(ticket.euroNumbers)
                                .intersection(targetDraw.euroNumbers)
                                .count
                    }

                    splitTotals[variantIndex].tickets +=
                        selected.count
                }
            }

            // -----------------------------------------------------
            // Split-Auswertung
            // -----------------------------------------------------

            var splitResults: [
                (
                    name: String,
                    main: Double,
                    euro: Double,
                    score: Double
                )
            ] = []

            for result in splitTotals {

                let main = result.tickets > 0
                    ? Double(result.main) / Double(result.tickets)
                    : 0

                let euro = result.tickets > 0
                    ? Double(result.euro) / Double(result.tickets)
                    : 0

                let score =
                    (main - 0.50)
                    + (euro - 0.333333)

                splitResults.append(
                    (
                        name: result.name,
                        main: main,
                        euro: euro,
                        score: score
                    )
                )
            }

            if let winner = splitResults.max(
                by: { $0.score < $1.score }
            ) {
                if let index = totals.firstIndex(
                    where: { $0.name == winner.name }
                ) {
                    totals[index].wins += 1
                }
            }

            for result in splitResults {

                if let index = totals.firstIndex(
                    where: { $0.name == result.name }
                ) {
                    totals[index].main += result.main
                    totals[index].euro += result.euro
                    totals[index].score += result.score
                }
            }

            print("")
            print("SPLIT \(split + 1)")
            print("-----------------------------------")
            print(
                "Holdout: Ziehungen \(holdoutStart + 1)–\(holdoutEnd)"
            )

            for result in splitResults {

                print(
                    String(
                        format:
                            "%@  Haupt %.3f  Euro %.3f  Score %+.3f",
                        result.name,
                        result.main,
                        result.euro,
                        result.score
                    )
                )
            }
        }

        // ---------------------------------------------------------
        // Gesamtergebnis
        // ---------------------------------------------------------

        print("")
        print("===================================")
        print("GESAMTERGEBNIS")
        print("===================================")

        for variant in totals {

            let averageMain =
                variant.main / Double(splitCount)

            let averageEuro =
                variant.euro / Double(splitCount)

            let averageScore =
                variant.score / Double(splitCount)

            print(
                String(
                    format:
                        "%@  Siege %2d/%d | Haupt %.3f | Euro %.3f | Score %+.3f",
                    variant.name,
                    variant.wins,
                    splitCount,
                    averageMain,
                    averageEuro,
                    averageScore
                )
            )
        }

        if let winner = totals.max(
            by: {
                if $0.wins == $1.wins {
                    return $0.score < $1.score
                }

                return $0.wins < $1.wins
            }
        ) {
            print("")
            print("🥇 Häufigster Sieger: \(winner.name)")
            print("   Siege: \(winner.wins)/\(splitCount)")
        }

        print(
            String(
                format:
                    "⏱ Konzentrations-Ablation: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )

        print("===================================")
    }

    private func concentrationScores(
        candidates: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> [Double] {

        let counts = Dictionary(
            uniqueKeysWithValues:
                (1...50).map { number in
                    (
                        number,
                        draws.reduce(0) { count, draw in
                            count
                                + (
                                    draw.numbers.contains(number)
                                    ? 1
                                    : 0
                                )
                        }
                    )
                }
        )

        let ranked = (1...50).sorted {

            if counts[$0, default: 0]
                == counts[$1, default: 0] {
                return $0 < $1
            }

            return counts[$0, default: 0]
                > counts[$1, default: 0]
        }

        let denominator =
            Double(max(1, ranked.count - 1))

        let rankMap = Dictionary(
            uniqueKeysWithValues:
                ranked.enumerated().map {
                    (
                        $0.element,
                        1.0
                            - Double($0.offset)
                            / denominator
                    )
                }
        )

        return candidates.map { ticket in

            let ranks = ticket.numbers
                .map {
                    rankMap[$0, default: 0]
                }
                .sorted(by: >)

            guard ranks.count == 5 else {
                return 0
            }

            return ranks[0] * 0.35
                + ranks[1] * 0.25
                + ranks[2] * 0.20
                + ranks[3] * 0.12
                + ranks[4] * 0.08
        }
    }

    private func normalize(
        _ values: [Double]
    ) -> [Double] {

        guard let minValue = values.min(),
              let maxValue = values.max(),
              maxValue > minValue else {
            return values.map { _ in 0.5 }
        }

        return values.map {
            ($0 - minValue)
                / (maxValue - minValue)
        }
    }

    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        Set(lhs.numbers)
            .intersection(rhs.numbers)
            .count
    }
}


// =============================================================
// KONZENTRATION – HISTORY-WINDOW-DIAGNOSE
// Separater Diagnosetest – Produktions-Optimizer unverändert
// =============================================================

struct ConcentrationHistoryWindowDiagnostic {

    private let windows: [(name: String, size: Int?)] = [
        ("FULL", nil),
        ("W300", 300),
        ("W200", 200),
        ("W150", 150),
        ("W100", 100)
    ]

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        splitCount: Int = 20
    ) {

        let holdoutSize = 40
        let minimumTrainingSize = 300

        guard draws.count > minimumTrainingSize + holdoutSize else {
            print("❌ Konzentrations-History: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let candidateCount = max(
            AppSettings.backtestCandidateCount + 1,
            301
        )

        let generator = TicketGenerator()

        let firstHoldoutStart = minimumTrainingSize
        let lastHoldoutStart = draws.count - holdoutSize
        let availableRange = lastHoldoutStart - firstHoldoutStart

        var totals = windows.map {
            (
                name: $0.name,
                main: 0.0,
                euro: 0.0,
                score: 0.0,
                wins: 0
            )
        }

        print("")
        print("===================================")
        print("🔬 KONZENTRATION – HISTORY-WINDOW")
        print("===================================")
        print("Splits              : \(splitCount)")
        print("Holdout je Split    : \(holdoutSize)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Fenster             : FULL / W300 / W200 / W150 / W100")
        print("")

        for split in 0..<splitCount {

            let holdoutStart: Int

            if splitCount == 1 {
                holdoutStart = firstHoldoutStart
            } else {
                holdoutStart =
                    firstHoldoutStart
                    + Int(
                        (Double(split) / Double(splitCount - 1))
                        * Double(availableRange)
                    )
            }

            let holdoutEnd = holdoutStart + holdoutSize

            var splitTotals = windows.map {
                (
                    name: $0.name,
                    main: 0,
                    euro: 0,
                    tickets: 0
                )
            }

            for index in holdoutStart..<holdoutEnd {

                let targetDraw = draws[index]
                let trainingDraws = Array(draws.prefix(index))

                let candidates = generator.generate(
                    count: candidateCount,
                    draws: trainingDraws,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )

                for windowIndex in windows.indices {

                    let window = windows[windowIndex]

                    let frequencyDraws: [EuroJackpotDraw]

                    if let size = window.size {
                        frequencyDraws = Array(
                            trainingDraws.suffix(
                                min(size, trainingDraws.count)
                            )
                        )
                    } else {
                        frequencyDraws = trainingDraws
                    }

                    let concentration = concentrationScores(
                        candidates: candidates,
                        draws: frequencyDraws
                    )

                    let normalized = normalize(concentration)

                    let rankedIndices = candidates.indices.sorted {

                        if normalized[$0] == normalized[$1] {
                            return $0 < $1
                        }

                        return normalized[$0] > normalized[$1]
                    }

                    var selected: [Ticket] = []

                    for candidateIndex in rankedIndices.prefix(
                        min(36, rankedIndices.count)
                    ) {

                        let ticket = candidates[candidateIndex]

                        if selected.allSatisfy({
                            commonNumbers($0, ticket) < 3
                        }) {
                            selected.append(ticket)
                        }

                        if selected.count == recommendationCount {
                            break
                        }
                    }

                    for ticket in selected {

                        splitTotals[windowIndex].main +=
                            Set(ticket.numbers)
                                .intersection(targetDraw.numbers)
                                .count

                        splitTotals[windowIndex].euro +=
                            Set(ticket.euroNumbers)
                                .intersection(targetDraw.euroNumbers)
                                .count

                        splitTotals[windowIndex].tickets += 1
                    }
                }
            }

            var splitResults: [
                (
                    name: String,
                    main: Double,
                    euro: Double,
                    score: Double
                )
            ] = []

            for result in splitTotals {

                let main =
                    result.tickets > 0
                    ? Double(result.main) / Double(result.tickets)
                    : 0

                let euro =
                    result.tickets > 0
                    ? Double(result.euro) / Double(result.tickets)
                    : 0

                let score =
                    (main - 0.50)
                    + (euro - 0.333333)

                splitResults.append(
                    (
                        name: result.name,
                        main: main,
                        euro: euro,
                        score: score
                    )
                )
            }

            if let winner = splitResults.max(
                by: { $0.score < $1.score }
            ) {

                if let index = totals.firstIndex(
                    where: { $0.name == winner.name }
                ) {
                    totals[index].wins += 1
                }
            }

            for result in splitResults {

                if let index = totals.firstIndex(
                    where: { $0.name == result.name }
                ) {
                    totals[index].main += result.main
                    totals[index].euro += result.euro
                    totals[index].score += result.score
                }
            }

            print("")
            print("SPLIT \(split + 1)")
            print("-----------------------------------")
            print(
                "Holdout: Ziehungen \(holdoutStart + 1)–\(holdoutEnd)"
            )

            for result in splitResults {

                print(
                    String(
                        format:
                            "%@  Haupt %.3f  Euro %.3f  Score %+.3f",
                        result.name,
                        result.main,
                        result.euro,
                        result.score
                    )
                )
            }
        }

        print("")
        print("===================================")
        print("GESAMTERGEBNIS")
        print("===================================")

        for variant in totals {

            let averageMain =
                variant.main / Double(splitCount)

            let averageEuro =
                variant.euro / Double(splitCount)

            let averageScore =
                variant.score / Double(splitCount)

            print(
                String(
                    format:
                        "%@  Siege %2d/%d | Haupt %.3f | Euro %.3f | Score %+.3f",
                    variant.name,
                    variant.wins,
                    splitCount,
                    averageMain,
                    averageEuro,
                    averageScore
                )
            )
        }

        if let winner = totals.max(
            by: {
                if $0.wins == $1.wins {
                    return $0.score < $1.score
                }

                return $0.wins < $1.wins
            }
        ) {

            print("")
            print("🥇 Häufigster Sieger: \(winner.name)")
            print("   Siege: \(winner.wins)/\(splitCount)")
        }

        print(
            String(
                format:
                    "⏱ Konzentrations-History: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )

        print("===================================")
    }

    private func concentrationScores(
        candidates: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> [Double] {

        var counts = Array(
            repeating: 0,
            count: 51
        )

        for draw in draws {
            for number in draw.numbers
            where (1...50).contains(number) {
                counts[number] += 1
            }
        }

        let ranked = (1...50).sorted {

            if counts[$0] == counts[$1] {
                return $0 < $1
            }

            return counts[$0] > counts[$1]
        }

        let denominator =
            Double(max(1, ranked.count - 1))

        let rankMap = Dictionary(
            uniqueKeysWithValues:
                ranked.enumerated().map {
                    (
                        $0.element,
                        1.0
                        - Double($0.offset) / denominator
                    )
                }
        )

        return candidates.map { ticket in

            let ranks = ticket.numbers
                .map {
                    rankMap[$0, default: 0]
                }
                .sorted(by: >)

            guard ranks.count == 5 else {
                return 0
            }

            return
                ranks[0] * 0.35
                + ranks[1] * 0.25
                + ranks[2] * 0.20
                + ranks[3] * 0.12
                + ranks[4] * 0.08
        }
    }

    private func normalize(
        _ values: [Double]
    ) -> [Double] {

        guard
            let minValue = values.min(),
            let maxValue = values.max(),
            maxValue > minValue
        else {
            return values.map { _ in 0.5 }
        }

        return values.map {
            ($0 - minValue)
            / (maxValue - minValue)
        }
    }

    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        Set(lhs.numbers)
            .intersection(rhs.numbers)
            .count
    }
}


// =============================================================
// F2 HISTORY-WINDOW DIAGNOSTIC
// Vergleicht ausschließlich die bestehende F2-Logik mit
// unterschiedlichen Frequenzfenstern.
// Produktions-F2/50 bleibt unverändert.
// =============================================================

struct F2HistoryWindowDiagnostic {

    private let windows = [50, 100, 150, 200]

    func run(
        draws: [EuroJackpotDraw],
        splitCount: Int = 20
    ) {

        let holdoutSize = 40
        let minimumTrainingSize = 300

        guard draws.count > minimumTrainingSize + holdoutSize else {
            print("❌ F2-History: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let firstHoldoutStart = minimumTrainingSize
        let lastHoldoutStart = draws.count - holdoutSize
        let availableRange = lastHoldoutStart - firstHoldoutStart

        var totals = windows.map {
            (
                window: $0,
                main: 0.0,
                euro: 0.0,
                score: 0.0,
                wins: 0
            )
        }

        print("")
        print("===================================")
        print("🔬 F2 HISTORY-WINDOW DIAGNOSTIC")
        print("===================================")
        print("Fenster             : 50 / 100 / 150 / 200")
        print("Splits              : \(splitCount)")
        print("Holdout je Split    : \(holdoutSize)")
        print("F2-Tipp je Ziehung  : 1")
        print("Produktions-F2/50   : unverändert")
        print("")

        for split in 0..<splitCount {

            let holdoutStart: Int

            if splitCount == 1 {
                holdoutStart = firstHoldoutStart
            } else {
                holdoutStart =
                    firstHoldoutStart
                    + Int(
                        (Double(split) / Double(splitCount - 1))
                        * Double(availableRange)
                    )
            }

            let holdoutEnd = holdoutStart + holdoutSize

            var splitResults = windows.map {
                (
                    window: $0,
                    main: 0,
                    euro: 0
                )
            }

            for index in holdoutStart..<holdoutEnd {

                let target = draws[index]
                let trainingDraws = Array(draws.prefix(index))

                for windowIndex in windows.indices {

                    let window = windows[windowIndex]

                    let source = Array(
                        trainingDraws.suffix(window)
                    )

                    let main = rankedNumbers(
                        in: source,
                        range: 1...50,
                        limit: 5
                    )

                    let euro = rankedNumbers(
                        in: source,
                        range: 1...12,
                        limit: 2
                    )

                    splitResults[windowIndex].main +=
                        Set(main).intersection(target.numbers).count

                    splitResults[windowIndex].euro +=
                        Set(euro).intersection(target.euroNumbers).count
                }
            }

            var splitScores: [
                (
                    window: Int,
                    main: Double,
                    euro: Double,
                    score: Double
                )
            ] = []

            for result in splitResults {

                let main =
                    Double(result.main)
                    / Double(holdoutSize)

                let euro =
                    Double(result.euro)
                    / Double(holdoutSize)

                let score =
                    (main - 0.50)
                    + (euro - 0.333333)

                splitScores.append(
                    (
                        window: result.window,
                        main: main,
                        euro: euro,
                        score: score
                    )
                )
            }

            if let winner = splitScores.max(
                by: { $0.score < $1.score }
            ) {
                if let index = totals.firstIndex(
                    where: { $0.window == winner.window }
                ) {
                    totals[index].wins += 1
                }
            }

            for result in splitScores {

                if let index = totals.firstIndex(
                    where: { $0.window == result.window }
                ) {
                    totals[index].main += result.main
                    totals[index].euro += result.euro
                    totals[index].score += result.score
                }
            }

            print("")
            print("SPLIT \(split + 1)")
            print("-----------------------------------")
            print(
                "Holdout: Ziehungen \(holdoutStart + 1)–\(holdoutEnd)"
            )

            for result in splitScores {

                print(
                    String(
                        format:
                            "F2-%d  Haupt %.3f  Euro %.3f  Score %+.3f",
                        result.window,
                        result.main,
                        result.euro,
                        result.score
                    )
                )
            }
        }

        print("")
        print("===================================")
        print("GESAMTERGEBNIS F2 HISTORY")
        print("===================================")

        for result in totals {

            let main =
                result.main / Double(splitCount)

            let euro =
                result.euro / Double(splitCount)

            let score =
                result.score / Double(splitCount)

            print(
                String(
                    format:
                        "F2-%d  Siege %2d/%d | Haupt %.3f | Euro %.3f | Score %+.3f",
                    result.window,
                    result.wins,
                    splitCount,
                    main,
                    euro,
                    score
                )
            )
        }

        if let winner = totals.max(
            by: {
                if $0.wins == $1.wins {
                    return $0.score < $1.score
                }

                return $0.wins < $1.wins
            }
        ) {

            print("")
            print("🥇 Häufigster Sieger: F2-\(winner.window)")
            print("   Siege: \(winner.wins)/\(splitCount)")
        }

        print(
            String(
                format:
                    "⏱ F2-History: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )

        print("===================================")
    }

    private func rankedNumbers(
        in draws: [EuroJackpotDraw],
        range: ClosedRange<Int>,
        limit: Int
    ) -> [Int] {

        var counts: [Int: Int] = [:]

        for draw in draws {

            for value in draw.numbers
                where range.contains(value) {

                counts[value, default: 0] += 1
            }
        }

        return Array(
            range.sorted {

                let left = counts[$0, default: 0]
                let right = counts[$1, default: 0]

                if left == right {
                    return $0 < $1
                }

                return left > right
            }
            .prefix(limit)
        )
    }
}

// =============================================================
// F2 + KONZENTRATION KOMBINATIONSDIAGNOSTIK
// =============================================================

struct F2ConcentrationCombinationDiagnostic {

    private let variants: [
        (
            name: String,
            alphaWeight: Double,
            concentrationWeight: Double
        )
    ] = [
        ("F2-50", 1.00, 0.00),
        ("F2-100", 0.00, 1.00)
    ]

    func run(
        draws: [EuroJackpotDraw],
        splitCount: Int = 20
    ) {

        let holdoutSize = 40
        let minimumTrainingSize = 300
        let repetitions = 5

        let candidateCount = max(
            AppSettings.backtestCandidateCount + 1,
            301
        )

        let recommendationCount =
            AppSettings.recommendationCount

        guard draws.count > minimumTrainingSize + holdoutSize else {
            print("❌ F2+Konzentration: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let generator = TicketGenerator()

        // Bestätigungstest: nur die jüngsten 200 Ziehungen
        // als Holdout-Bereich verwenden.
        let firstHoldoutStart =
            max(
                minimumTrainingSize,
                draws.count - 200
            )

        let lastHoldoutStart =
            draws.count - holdoutSize

        let availableRange =
            lastHoldoutStart - firstHoldoutStart

        var totals = variants.map {
            (
                name: $0.name,
                main: 0.0,
                euro: 0.0,
                score: 0.0,
                wins: 0
            )
        }

        print("")
        print("===================================")
        print("🔬 F2 HISTORY-WINDOW KONTROLLTEST")
        print("===================================")
        print("Varianten            : F2-50 / F2-100")
        print("Splits               : \(splitCount)")
        print("Wiederholungen       : \(repetitions)")
        print("Holdout je Split     : \(holdoutSize)")
        print("Kandidaten je Test   : \(candidateCount)")
        print("F2-50                : letzte 50 Ziehungen")
        print("F2-100               : letzte 100 Ziehungen")
        print("⚠️ Alle Varianten eines Tests nutzen denselben Kandidatenpool.")
        print("")

        for repetition in 1...repetitions {

            print("")
            print("===================================")
            print("WIEDERHOLUNG \(repetition)/\(repetitions)")
            print("===================================")

            for split in 0..<splitCount {

                let holdoutStart =
                    firstHoldoutStart
                    + Int(
                        (Double(split)
                         / Double(max(1, splitCount - 1)))
                        * Double(availableRange)
                    )

                let holdoutEnd =
                    holdoutStart + holdoutSize

                var splitResults: [
                    (
                        name: String,
                        main: Double,
                        euro: Double,
                        score: Double
                    )
                ] = []

                for index in holdoutStart..<holdoutEnd {

                    let target = draws[index]

                    let training =
                        Array(draws.prefix(index))

                    let candidates =
                        generator.generate(
                            count: candidateCount,
                            draws: training,
                            goal: OptimizationGoal(),
                            hillClimbingIterations: 0
                        )

                    let f2Draws =
                        Array(training.suffix(50))

                    let concentrationDraws =
                        Array(training.suffix(100))

                    let f2Scores =
                        candidates.map {
                            frequencyScore(
                                ticket: $0,
                                draws: f2Draws
                            )
                        }

                    let concentrationScores =
                        candidates.map {
                            frequencyScore(
                                ticket: $0,
                                draws: concentrationDraws
                            )
                        }

                    let normalizedF2 =
                        normalize(f2Scores)

                    let normalizedConcentration =
                        normalize(concentrationScores)

                    var variantTotals =
                        variants.map { _ in
                            (
                                main: 0,
                                euro: 0,
                                tickets: 0
                            )
                        }

                    for variantIndex in variants.indices {

                        let variant =
                            variants[variantIndex]

                        let rankedIndices =
                            candidates.indices.sorted {

                                let lhs =
                                    variant.alphaWeight
                                    * normalizedF2[$0]
                                    + variant.concentrationWeight
                                    * normalizedConcentration[$0]

                                let rhs =
                                    variant.alphaWeight
                                    * normalizedF2[$1]
                                    + variant.concentrationWeight
                                    * normalizedConcentration[$1]

                                if abs(lhs - rhs) < 0.0000000001 {
                                    return $0 < $1
                                }

                                return lhs > rhs
                            }

                        var selected: [Ticket] = []

                        for candidateIndex in rankedIndices {

                            let ticket =
                                candidates[candidateIndex]

                            if selected.allSatisfy({
                                commonNumbers($0, ticket) < 3
                            }) {
                                selected.append(ticket)
                            }

                            if selected.count ==
                                recommendationCount {
                                break
                            }
                        }

                        for ticket in selected {

                            variantTotals[variantIndex].main +=
                                Set(ticket.numbers)
                                .intersection(target.numbers)
                                .count

                            variantTotals[variantIndex].euro +=
                                Set(ticket.euroNumbers)
                                .intersection(target.euroNumbers)
                                .count

                            variantTotals[variantIndex].tickets += 1
                        }
                    }

                    for variantIndex in variants.indices {

                        guard variantTotals[variantIndex].tickets > 0
                        else {
                            continue
                        }

                        let main =
                            Double(
                                variantTotals[variantIndex].main
                            )
                            / Double(
                                variantTotals[variantIndex].tickets
                            )

                        let euro =
                            Double(
                                variantTotals[variantIndex].euro
                            )
                            / Double(
                                variantTotals[variantIndex].tickets
                            )

                        let score =
                            (main - 0.50)
                            + (euro - 0.333333)

                        splitResults.append(
                            (
                                name:
                                    variants[variantIndex].name,
                                main: main,
                                euro: euro,
                                score: score
                            )
                        )
                    }
                }

                // -------------------------------------------------
                // Split-Ergebnis aus allen Holdout-Ziehungen aggregieren
                // -------------------------------------------------

                var aggregatedSplitResults: [
                    (
                        name: String,
                        main: Double,
                        euro: Double,
                        score: Double
                    )
                ] = []

                for variant in variants {

                    let values = splitResults.filter {
                        $0.name == variant.name
                    }

                    guard !values.isEmpty else {
                        continue
                    }

                    let main =
                        values.reduce(0.0) { $0 + $1.main }
                        / Double(values.count)

                    let euro =
                        values.reduce(0.0) { $0 + $1.euro }
                        / Double(values.count)

                    let score =
                        (main - 0.50)
                        + (euro - 0.333333)

                    aggregatedSplitResults.append(
                        (
                            name: variant.name,
                            main: main,
                            euro: euro,
                            score: score
                        )
                    )
                }

                splitResults = aggregatedSplitResults

                let bestScore =
                    splitResults.map(\.score).max() ?? 0

                let winners =
                    splitResults.filter {
                        abs($0.score - bestScore)
                            < 0.000001
                    }

                if winners.count == 1,
                   let winner = winners.first,
                   let index = totals.firstIndex(
                        where: {
                            $0.name == winner.name
                        }
                   ) {

                    totals[index].wins += 1
                }

                for result in splitResults {

                    if let index = totals.firstIndex(
                        where: {
                            $0.name == result.name
                        }
                    ) {

                        totals[index].main +=
                            result.main

                        totals[index].euro +=
                            result.euro

                        totals[index].score +=
                            result.score
                    }
                }

                if repetition == repetitions {

                    print("")
                    print("SPLIT \(split + 1)")
                    print("-----------------------------------")
                    print(
                        "Holdout: Ziehungen \(holdoutStart + 1)–\(holdoutEnd)"
                    )

                    for result in splitResults {

                        print(
                            String(
                                format:
                                    "%@  Haupt %.3f  Euro %.3f  Score %+.3f",
                                result.name,
                                result.main,
                                result.euro,
                                result.score
                            )
                        )
                    }
                }
            }
        }

        let denominator =
            Double(splitCount * repetitions)

        print("")
        print("===================================")
        print("GESAMTERGEBNIS KONTROLLTEST")
        print("===================================")

        for result in totals {

            let main =
                result.main / denominator

            let euro =
                result.euro / denominator

            let score =
                result.score / denominator

            print(
                String(
                    format:
                        "%@  Siege %2d/%d | Haupt %.3f | Euro %.3f | Score %+.3f",
                    result.name,
                    result.wins,
                    splitCount * repetitions,
                    main,
                    euro,
                    score
                )
            )
        }

        if let winner = totals.max(
            by: {

                if $0.wins == $1.wins {
                    return $0.score < $1.score
                }

                return $0.wins < $1.wins
            }
        ) {

            print("")
            print("🥇 Häufigster eindeutiger Sieger: \(winner.name)")
            print(
                "   Siege: \(winner.wins)/\(splitCount * repetitions)"
            )
        }

        print(
            String(
                format:
                    "⏱ F2-50 + W100 Kontrolltest: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )

        print("===================================")
    }

    private func frequencyScore(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> Double {

        var counts: [Int: Int] = [:]

        for draw in draws {

            for number in draw.numbers {
                counts[number, default: 0] += 1
            }
        }

        let total =
            Double(max(1, draws.count))

        return ticket.numbers.reduce(0.0) {
            $0 + Double(
                counts[$1, default: 0]
            ) / total
        }
    }

    private func normalize(
        _ values: [Double]
    ) -> [Double] {

        guard
            let minValue = values.min(),
            let maxValue = values.max(),
            maxValue > minValue
        else {
            return values.map { _ in 0.5 }
        }

        return values.map {
            ($0 - minValue)
            / (maxValue - minValue)
        }
    }

    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        Set(lhs.numbers)
            .intersection(rhs.numbers)
            .count
    }
}
