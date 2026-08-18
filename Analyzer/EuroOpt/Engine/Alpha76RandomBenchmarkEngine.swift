//
//  Alpha76RandomBenchmarkEngine.swift
//  EuroOpt
//
//  Alpha 7.6 - fixed model vs paired random benchmark
//

import Foundation

final class Alpha76RandomBenchmarkEngine {

    private let monteCarloRuns = 50
    private let candidateCountMinimum = 301

    // Alpha 7.5 fixed profile:
    // F 34 | P 0 | G/U 0 | H/N 33 | S 33 | A 0
    //
    // Alpha 7.6 adds the independently defined
    // 70 % Alpha + 30 % main-number concentration blend.
    private let fixedWeights: [Double] = [34, 0, 0, 33, 33, 0]

    private let alphaWeight = 0.70
    private let concentrationWeight = 0.30

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) {
        guard draws.count > 140 else {
            print("❌ Alpha-7.6-Benchmark: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let holdoutCount = draws.count - holdoutStart

        let candidateCount = max(
            AppSettings.backtestCandidateCount + 1,
            candidateCountMinimum
        )

        let goal = makeGoal(fixedWeights)

        print("")
        print("===================================")
        print("🎲 ZUFALLSBENCHMARK – FIXED ALPHA 7.6")
        print("===================================")
        print("Profil              : F 34 | P 0 | G/U 0 | H/N 33 | S 33 | A 0")
        print("Profil vorher festgelegt: JA")
        print("Alpha-Gewichtung    : 70 %")
        print("Konzentration       : 30 %")
        print("Holdout-Ziehungen   : \(holdoutCount)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Monte-Carlo-Läufe   : \(monteCarloRuns)")
        print("Validation          : NICHT verwendet")
        print("Gewichte / EQI      : keine erneute Auswahl / Optimierung")
        print("Diversitätsregel    : maximal 2 gemeinsame Hauptzahlen")
        print("Euro-Basis          : 10 bis 24.03.2022 / 12 ab 25.03.2022")
        print("")
        print("🔒 Alpha 7.6 wird nicht neu gewählt oder optimiert.")
        print("🔒 Die 30-%-Konzentration wird ausschließlich aus den Trainingsziehungen berechnet.")
        print("🔒 Das Holdout wird weder zur Profilwahl noch zur Tippauswahl verwendet.")
        print("🔒 Modell und Zufall werden gepaart verglichen.")
        print("")

        let generator = TicketGenerator()

        var modelMainHits = 0
        var modelEuroHits = 0
        var modelTickets = 0

        for index in holdoutStart..<draws.count {

            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: goal,
                hillClimbingIterations: 0,
                useQuickScore: false
            )

            let selected = alpha76Tickets(
                candidates: candidates,
                draws: trainingDraws,
                goal: goal,
                limit: recommendationCount
            )

            for ticket in selected {
                modelMainHits += commonHitCount(
                    ticket.numbers,
                    targetDraw.numbers
                )

                modelEuroHits += commonHitCount(
                    ticket.euroNumbers,
                    targetDraw.euroNumbers
                )

                modelTickets += 1
            }

            let current = index - holdoutStart + 1

            if current.isMultiple(of: 50) {
                print("... Alpha-7.6 Holdout \(current) / \(holdoutCount)")
            }
        }

        guard modelTickets > 0 else {
            print("❌ Alpha-7.6-Benchmark: kein Modell-Holdout vorhanden")
            return
        }

        let modelMainAverage =
            Double(modelMainHits) / Double(modelTickets)

        let modelEuroAverage =
            Double(modelEuroHits) / Double(modelTickets)

        var pairedMainDeltas: [Double] = []
        var pairedEuroDeltas: [Double] = []
        var pairedCombinedDeltas: [Double] = []

        pairedMainDeltas.reserveCapacity(monteCarloRuns)
        pairedEuroDeltas.reserveCapacity(monteCarloRuns)
        pairedCombinedDeltas.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {

            let rng = Alpha76SeededRandomGenerator(
                seed: 0xA7_6000_7500 &+ UInt64(run)
            )

            var randomMainHits = 0
            var randomEuroHits = 0
            var randomTickets = 0

            for index in holdoutStart..<draws.count {

                let targetDraw = draws[index]

                let euroMaximum =
                    targetDraw.date < euroFormatCutoverDate()
                    ? 10
                    : 12

                let candidates = generateCandidatesFast(
                    count: candidateCount,
                    euroMaximum: euroMaximum,
                    rng: rng
                )

                let selected = selectRandomDiversifiedTicketsFast(
                    candidates: candidates,
                    limit: recommendationCount,
                    rng: rng
                )

                for ticket in selected {

                    randomMainHits += commonHitCount(
                        ticket.numbers,
                        targetDraw.numbers
                    )

                    randomEuroHits += commonHitCount(
                        ticket.euroNumbers,
                        targetDraw.euroNumbers
                    )

                    randomTickets += 1
                }
            }

            guard randomTickets > 0 else { continue }

            let randomMainAverage =
                Double(randomMainHits) / Double(randomTickets)

            let randomEuroAverage =
                Double(randomEuroHits) / Double(randomTickets)

            let mainDelta =
                modelMainAverage - randomMainAverage

            let euroDelta =
                modelEuroAverage - randomEuroAverage

            pairedMainDeltas.append(mainDelta)
            pairedEuroDeltas.append(euroDelta)
            pairedCombinedDeltas.append(mainDelta + euroDelta)

            if (run + 1).isMultiple(of: 5) ||
                run == monteCarloRuns - 1 {

                print(
                    "... Monte-Carlo \(run + 1) / \(monteCarloRuns)"
                )
            }
        }

        let randomMainAverage =
            modelMainAverage - mean(pairedMainDeltas)

        let randomEuroAverage =
            modelEuroAverage - mean(pairedEuroDeltas)

        let mainCI =
            pairedConfidenceInterval(pairedMainDeltas)

        let euroCI =
            pairedConfidenceInterval(pairedEuroDeltas)

        let combinedCI =
            pairedConfidenceInterval(pairedCombinedDeltas)

        let theoryEuro =
            weightedHistoricalEuroExpectation(
                draws: Array(draws[holdoutStart..<draws.count])
            )

        print("")
        print("===================================")
        print("🎲 ZUFALLSBENCHMARK – FIXED ALPHA 7.6")
        print("===================================")
        print("Profil              : F 34 | P 0 | G/U 0 | H/N 33 | S 33 | A 0")
        print("Profil vorher festgelegt: JA")
        print("Gewichte im Benchmark verändert: NEIN")
        print("")
        print(String(format: "Ø Modell Haupt      : %.4f", modelMainAverage))
        print(String(format: "Ø Zufall Haupt      : %.4f", randomMainAverage))
        print(String(format: "Δ Modell - Zufall   : %+.4f", mean(pairedMainDeltas)))
        print(String(format: "95%% CI Δ Haupt      : ±%.4f", mainCI))
        print("")
        print(String(format: "Ø Modell Euro       : %.4f", modelEuroAverage))
        print(String(format: "Ø Zufall Euro       : %.4f", randomEuroAverage))
        print(String(format: "Δ Modell - Zufall   : %+.4f", mean(pairedEuroDeltas)))
        print(String(format: "95%% CI Δ Euro       : ±%.4f", euroCI))
        print("")
        print(String(format: "Δ kombiniert        : %+.4f", mean(pairedCombinedDeltas)))
        print(String(format: "95%% CI Δ kombiniert : ±%.4f", combinedCI))
        print("")
        print(String(format: "Theorie Haupt       : %.4f", 0.5000))
        print(String(format: "Theorie Euro        : %.4f", theoryEuro))
        print("")
        print("Statistik:")
        print("- Gepaarter Vergleich gegen denselben Holdout.")
        print("- Alpha 7.6 = 70 % Alpha + 30 % Hauptzahl-Konzentration.")
        print("- Das Profil wurde nicht im Holdout neu gewählt.")
        print("- Keine EQI-Komponenten im Zufallsbenchmark.")
        print("- Diversitätsregel: maximal 2 gemeinsame Hauptzahlen.")
        print("- Historisches 10/12-Eurozahlen-Format wird berücksichtigt.")
        print("")
        print(
            String(
                format: "⏱ Alpha-7.6-Zufallsbenchmark: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
    }

    private func alpha76Tickets(
        candidates: [Ticket],
        draws: [EuroJackpotDraw],
        goal: OptimizationGoal,
        limit: Int
    ) -> [Ticket] {

        guard !candidates.isEmpty, limit > 0 else {
            return []
        }

        let cache = ScoreCache(draws: draws)
        let scoreEngine = ScoreEngine(
            cache: cache,
            goal: goal
        )

        let alphaScores = candidates.map {
            scoreEngine.score(ticket: $0)
        }

        let concentrationScores =
            mainConcentrationScores(
                for: candidates,
                draws: draws
            )

        let normalizedAlpha = normalize(alphaScores)
        let normalizedConcentration =
            normalize(concentrationScores)

        let ranked = candidates.indices.sorted {
            let lhs =
                alphaWeight * normalizedAlpha[$0] +
                concentrationWeight *
                normalizedConcentration[$0]

            let rhs =
                alphaWeight * normalizedAlpha[$1] +
                concentrationWeight *
                normalizedConcentration[$1]

            if lhs == rhs {
                return $0 < $1
            }

            return lhs > rhs
        }

        var result: [Ticket] = []
        result.reserveCapacity(limit)

        for index in ranked {

            let ticket = candidates[index]

            if result.allSatisfy({
                commonNumbers($0, ticket) < 3
            }) {
                result.append(ticket)
            }

            if result.count == limit {
                break
            }
        }

        return result
    }

    private func mainConcentrationScores(
        for tickets: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> [Double] {

        let mainRank = rankMap(
            counts(
                draws: draws,
                range: 1...50
            ),
            range: 1...50
        )

        return tickets.map { ticket in

            let ranks = ticket.numbers
                .map {
                    mainRank[$0, default: 0]
                }
                .sorted(by: >)

            guard ranks.count == 5 else {
                return 0.0
            }

            return ranks[0] * 0.35
                + ranks[1] * 0.25
                + ranks[2] * 0.20
                + ranks[3] * 0.12
                + ranks[4] * 0.08
        }
    }

    private func counts(
        draws: [EuroJackpotDraw],
        range: ClosedRange<Int>
    ) -> [Int: Int] {

        var result =
            Dictionary(
                uniqueKeysWithValues:
                    range.map { ($0, 0) }
            )

        for draw in draws {
            for value in draw.numbers
            where range.contains(value) {
                result[value, default: 0] += 1
            }
        }

        return result
    }

    private func rankMap(
        _ counts: [Int: Int],
        range: ClosedRange<Int>
    ) -> [Int: Double] {

        let ranked = range.sorted {
            if counts[$0, default: 0] ==
                counts[$1, default: 0] {
                return $0 < $1
            }

            return counts[$0, default: 0] >
                counts[$1, default: 0]
        }

        let denominator =
            Double(max(1, ranked.count - 1))

        return Dictionary(
            uniqueKeysWithValues:
                ranked.enumerated().map {
                    (
                        $0.element,
                        1.0 -
                        Double($0.offset) /
                        denominator
                    )
                }
        )
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
            ($0 - minValue) /
            (maxValue - minValue)
        }
    }

    private func generateCandidatesFast(
        count: Int,
        euroMaximum: Int,
        rng: Alpha76SeededRandomGenerator
    ) -> [Ticket] {

        var candidates: [Ticket] = []
        candidates.reserveCapacity(count)

        while candidates.count < count {

            let ticket =
                rng.makeTicketFast(
                    euroMaximum: euroMaximum
                )

            if isValid(ticket: ticket) {
                candidates.append(ticket)
            }
        }

        return candidates
    }

    private func selectRandomDiversifiedTicketsFast(
        candidates: [Ticket],
        limit: Int,
        rng: Alpha76SeededRandomGenerator
    ) -> [Ticket] {

        guard !candidates.isEmpty, limit > 0 else {
            return []
        }

        var order =
            Array(0..<candidates.count)

        var result: [Ticket] = []
        result.reserveCapacity(limit)

        var scanIndex = 0

        while scanIndex < order.count &&
              result.count < limit {

            let remaining =
                order.count - scanIndex

            let swapIndex =
                scanIndex +
                rng.nextInt(
                    upperBound: remaining
                )

            order.swapAt(
                scanIndex,
                swapIndex
            )

            let candidate =
                candidates[order[scanIndex]]

            if result.allSatisfy({
                commonNumbers($0, candidate) < 3
            }) {
                result.append(candidate)
            }

            scanIndex += 1
        }

        return result
    }

    private func isValid(
        ticket: Ticket
    ) -> Bool {

        let numbers = ticket.numbers

        var even = 0
        var high = 0
        var sum = 0
        var consecutive = 1
        var smallGaps = 0

        for i in numbers.indices {

            let value = numbers[i]

            sum += value

            if value.isMultiple(of: 2) {
                even += 1
            }

            if value > 25 {
                high += 1
            }

            if i > 0 {

                let gap =
                    value -
                    numbers[i - 1]

                if gap == 1 {

                    consecutive += 1

                    if consecutive >
                        AppSettings.maximumConsecutiveNumbers {
                        return false
                    }

                } else {

                    consecutive = 1
                }

                if gap <= 2 {
                    smallGaps += 1
                }
            }
        }

        guard
            even >= AppSettings.minimumEvenNumbers &&
            even <= AppSettings.maximumEvenNumbers
        else {
            return false
        }

        guard
            high >= AppSettings.minimumHighNumbers &&
            high <= AppSettings.maximumHighNumbers
        else {
            return false
        }

        guard
            sum >= AppSettings.minimumSum &&
            sum <= AppSettings.maximumSum
        else {
            return false
        }

        guard
            smallGaps <= AppSettings.maximumSmallGaps
        else {
            return false
        }

        return true
    }

    @inline(__always)
    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        commonHitCount(
            lhs.numbers,
            rhs.numbers
        )
    }

    @inline(__always)
    private func commonHitCount(
        _ lhs: [Int],
        _ rhs: [Int]
    ) -> Int {

        var count = 0

        for value in lhs
        where rhs.contains(value) {

            count += 1

            if count >= 3 {
                return count
            }
        }

        return count
    }

    private func mean(
        _ values: [Double]
    ) -> Double {

        guard !values.isEmpty else {
            return 0
        }

        return values.reduce(0, +) /
            Double(values.count)
    }

    private func pairedConfidenceInterval(
        _ values: [Double]
    ) -> Double {

        guard values.count > 1 else {
            return 0
        }

        let average = mean(values)

        let variance =
            values.reduce(0.0) {
                $0 +
                pow($1 - average, 2)
            } /
            Double(values.count - 1)

        let standardError =
            sqrt(variance) /
            sqrt(Double(values.count))

        return 1.96 * standardError
    }

    private func weightedHistoricalEuroExpectation(
        draws: [EuroJackpotDraw]
    ) -> Double {

        guard !draws.isEmpty else {
            return 0
        }

        return draws.reduce(0.0) {
            partial,
            draw in

            partial +
            (
                draw.date <
                euroFormatCutoverDate()
                ? 2.0 / 10.0
                : 2.0 / 12.0
            )
        } / Double(draws.count)
    }

    private func euroFormatCutoverDate() -> Date {

        var components =
            DateComponents()

        components.year = 2022
        components.month = 3
        components.day = 25

        return Calendar.current.date(
            from: components
        ) ?? Date.distantFuture
    }

    private func makeGoal(
        _ weights: [Double]
    ) -> OptimizationGoal {

        OptimizationGoal(
            frequencyWeight: weights[0],
            pairWeight: weights[1],
            evenOddWeight: weights[2],
            highLowWeight: weights[3],
            sumWeight: weights[4],
            gapWeight: weights[5]
        )
    }

    private func weightLabel(
        _ weights: [Double]
    ) -> String {

        String(
            format:
                "F %.0f | P %.0f | G/U %.0f | H/N %.0f | S %.0f | A %.0f",
            weights[0],
            weights[1],
            weights[2],
            weights[3],
            weights[4],
            weights[5]
        )
    }

    private func weightLabel(
        _ profile: Any
    ) -> String {

        "F 34 | P 0 | G/U 0 | H/N 33 | S 33 | A 0"
    }
}


private final class Alpha76SeededRandomGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    @inline(__always)
    func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    @inline(__always)
    func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }

    @inline(__always)
    func makeTicketFast(euroMaximum: Int) -> Ticket {
        var numbers: [Int] = []
        numbers.reserveCapacity(5)

        while numbers.count < 5 {
            let value = nextInt(upperBound: 50) + 1
            if !numbers.contains(value) {
                numbers.append(value)
            }
        }

        numbers.sort()

        var euroNumbers: [Int] = []
        euroNumbers.reserveCapacity(2)

        while euroNumbers.count < 2 {
            let value = nextInt(upperBound: euroMaximum) + 1
            if !euroNumbers.contains(value) {
                euroNumbers.append(value)
            }
        }

        euroNumbers.sort()

        return Ticket(
            numbers: numbers,
            euroNumbers: euroNumbers
        )
    }
}
