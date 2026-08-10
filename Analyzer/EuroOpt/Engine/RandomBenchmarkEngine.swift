//
//  RandomBenchmarkEngine.swift
//  EuroOpt
//
//  Alpha 7.5 - fixed-profile empirical random benchmark
//  with paired holdout comparison
//

import Foundation

final class RandomBenchmarkEngine {

    private struct Profile {
        let weights: [Double]
        let goal: OptimizationGoal
    }

    private let monteCarloRuns = 50
    private let candidateCountMinimum = 301

    // Alpha 7.5 profile selected previously on the Validation half.
    // IMPORTANT: this benchmark must never re-select or re-optimize it.
    private let fixedWeights: [Double] = [34, 0, 0, 33, 33, 0]

    func run(draws: [EuroJackpotDraw], recommendationCount: Int) {
        guard draws.count > 140 else {
            print("❌ Zufallsbenchmark: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let holdoutCount = draws.count - holdoutStart
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)
        let profile = Profile(weights: fixedWeights, goal: makeGoal(fixedWeights))

        print("")
        print("===================================")
        print("🎲 BESCHLEUNIGTER ZUFALLSBENCHMARK")
        print("===================================")
        print("Profil              : \(weightLabel(profile))")
        print("Profilwahl          : FEST VORGEGEBEN")
        print("Holdout-Ziehungen   : \(holdoutCount)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Monte-Carlo-Läufe   : \(monteCarloRuns)")
        print("Validation          : NICHT verwendet")
        print("Gewichte / EQI      : keine erneute Auswahl / Optimierung")
        print("Diversitätsregel    : maximal 2 gemeinsame Hauptzahlen")
        print("Euro-Basis          : 10 bis 24.03.2022 / 12 ab 25.03.2022")
        print("")
        print("🔒 Exakt das zuvor festgelegte Alpha-7.5-Profil wird verwendet.")
        print("🔒 Das Holdout wird weder zur Profilwahl noch zur Tippauswahl verwendet.")
        print("🔒 Zufallserzeugung nutzt schnelle Stichproben statt vollständiger Array-Shuffles.")
        print("🔒 Modell und Zufall werden über 50 unabhängige Monte-Carlo-Replikationen gepaart verglichen.")
        print("")

        // Fixed Alpha 7.5 model on the untouched holdout.
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
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )
            let cache = ScoreCache(draws: trainingDraws)
            let scoreEngine = ScoreEngine(cache: cache, goal: profile.goal)
            let selected = bestTickets(
                candidates: candidates,
                scoreEngine: scoreEngine,
                limit: recommendationCount
            )

            for ticket in selected {
                modelMainHits += commonHitCount(ticket.numbers, targetDraw.numbers)
                modelEuroHits += commonHitCount(ticket.euroNumbers, targetDraw.euroNumbers)
                modelTickets += 1
            }
        }

        guard modelTickets > 0 else {
            print("❌ Zufallsbenchmark: kein Modell-Holdout vorhanden")
            return
        }

        let modelMainAverage = Double(modelMainHits) / Double(modelTickets)
        let modelEuroAverage = Double(modelEuroHits) / Double(modelTickets)

        var pairedMainDeltas: [Double] = []
        var pairedEuroDeltas: [Double] = []
        var pairedCombinedDeltas: [Double] = []
        pairedMainDeltas.reserveCapacity(monteCarloRuns)
        pairedEuroDeltas.reserveCapacity(monteCarloRuns)
        pairedCombinedDeltas.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {
            let rng = SeededRandomGenerator(seed: 0xE7A7_7500 &+ UInt64(run))
            var randomMainHits = 0
            var randomEuroHits = 0
            var randomTickets = 0

            for index in holdoutStart..<draws.count {
                let targetDraw = draws[index]
                let euroMaximum = targetDraw.date < euroFormatCutoverDate() ? 10 : 12
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
                    randomMainHits += commonHitCount(ticket.numbers, targetDraw.numbers)
                    randomEuroHits += commonHitCount(ticket.euroNumbers, targetDraw.euroNumbers)
                    randomTickets += 1
                }
            }

            guard randomTickets > 0 else { continue }

            let randomMainAverage = Double(randomMainHits) / Double(randomTickets)
            let randomEuroAverage = Double(randomEuroHits) / Double(randomTickets)

            pairedMainDeltas.append(modelMainAverage - randomMainAverage)
            pairedEuroDeltas.append(modelEuroAverage - randomEuroAverage)
            pairedCombinedDeltas.append(
                (modelMainAverage + modelEuroAverage) -
                (randomMainAverage + randomEuroAverage)
            )

            if (run + 1).isMultiple(of: 5) || run == monteCarloRuns - 1 {
                print("... Monte-Carlo \(run + 1) / \(monteCarloRuns)")
            }
        }

        let randomMainAverage = modelMainAverage - mean(pairedMainDeltas)
        let randomEuroAverage = modelEuroAverage - mean(pairedEuroDeltas)

        let mainCI = pairedConfidenceInterval(pairedMainDeltas)
        let euroCI = pairedConfidenceInterval(pairedEuroDeltas)
        let combinedCI = pairedConfidenceInterval(pairedCombinedDeltas)
        let theoryEuro = weightedHistoricalEuroExpectation(
            draws: Array(draws[holdoutStart..<draws.count])
        )

        print("")
        print("===================================")
        print("🎲 ZUFALLSBENCHMARK – FIXED ALPHA 7.5")
        print("===================================")
        print(String(format: "Profil              : %@", weightLabel(profile)))
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
        print("- Gepaarter Vergleich: jedes Monte-Carlo-Ergebnis wird gegen dasselbe feste Modellprofil gestellt.")
        print("- 95-%-KI basiert auf den 50 unabhängigen Monte-Carlo-Replikationen.")
        print("- Ein KI, das 0 nicht einschließt, wäre ein Hinweis auf einen stabilen Unterschied im Benchmark.")
        print("- Das Alpha-7.5-Profil wurde im Benchmark weder neu gewählt noch verändert.")
        print("- Der Holdout wurde nicht zur Gewichtswahl verwendet.")
        print("- Der Zufall verwendet keine EQI-Komponenten und keine historischen Treffer.")
        print("- Hauptzahl-Regeln und Diversitätsregel entsprechen dem bisherigen Benchmark.")
        print("- Historisches 10/12-Eurozahlen-Format wird pro Ziehung berücksichtigt.")
        print("")
        print(String(format: "⏱ Beschleunigter Zufallsbenchmark: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func generateCandidatesFast(
        count: Int,
        euroMaximum: Int,
        rng: SeededRandomGenerator
    ) -> [Ticket] {
        var candidates: [Ticket] = []
        candidates.reserveCapacity(count)

        while candidates.count < count {
            let ticket = rng.makeTicketFast(euroMaximum: euroMaximum)
            if isValid(ticket: ticket) {
                candidates.append(ticket)
            }
        }
        return candidates
    }

    private func selectRandomDiversifiedTicketsFast(
        candidates: [Ticket],
        limit: Int,
        rng: SeededRandomGenerator
    ) -> [Ticket] {
        guard !candidates.isEmpty, limit > 0 else { return [] }

        var order = Array(0..<candidates.count)
        var result: [Ticket] = []
        result.reserveCapacity(limit)
        var scanIndex = 0

        while scanIndex < order.count && result.count < limit {
            let remaining = order.count - scanIndex
            let swapIndex = scanIndex + rng.nextInt(upperBound: remaining)
            order.swapAt(scanIndex, swapIndex)
            let candidate = candidates[order[scanIndex]]
            scanIndex += 1

            var different = true
            for existing in result {
                if commonNumbers(existing, candidate) >= 3 {
                    different = false
                    break
                }
            }

            if different {
                result.append(candidate)
            }
        }

        return result
    }

    private func bestTickets(
        candidates: [Ticket],
        scoreEngine: ScoreEngine,
        limit: Int
    ) -> [Ticket] {
        guard !candidates.isEmpty, limit > 0 else { return [] }

        let scored = candidates
            .map { ($0, scoreEngine.score(ticket: $0)) }
            .sorted { $0.1 > $1.1 }

        var result: [Ticket] = []
        result.reserveCapacity(limit)

        for candidate in scored {
            var different = true
            for existing in result {
                if commonNumbers(existing, candidate.0) >= 3 {
                    different = false
                    break
                }
            }

            if different {
                result.append(candidate.0)
                if result.count == limit { break }
            }
        }

        return result
    }

    @inline(__always)
    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        commonHitCount(lhs.numbers, rhs.numbers)
    }

    @inline(__always)
    private func commonHitCount(_ lhs: [Int], _ rhs: [Int]) -> Int {
        var count = 0
        for value in lhs where rhs.contains(value) {
            count += 1
        }
        return count
    }

    private func isValid(ticket: Ticket) -> Bool {
        let numbers = ticket.numbers
        var even = 0
        var high = 0
        var sum = 0
        var consecutive = 1
        var smallGaps = 0

        for i in numbers.indices {
            let value = numbers[i]
            sum += value
            if value.isMultiple(of: 2) { even += 1 }
            if value > 25 { high += 1 }

            if i > 0 {
                let gap = value - numbers[i - 1]
                if gap == 1 {
                    consecutive += 1
                    if consecutive > AppSettings.maximumConsecutiveNumbers {
                        return false
                    }
                } else {
                    consecutive = 1
                }
                if gap <= 2 { smallGaps += 1 }
            }
        }

        guard even >= AppSettings.minimumEvenNumbers &&
              even <= AppSettings.maximumEvenNumbers else { return false }
        guard high >= AppSettings.minimumHighNumbers &&
              high <= AppSettings.maximumHighNumbers else { return false }
        guard sum >= AppSettings.minimumSum &&
              sum <= AppSettings.maximumSum else { return false }
        guard smallGaps <= AppSettings.maximumSmallGaps else { return false }
        return true
    }

    private func expectedEuroHitsForDate(_ date: Date) -> Double {
        date < euroFormatCutoverDate() ? 0.400 : (1.0 / 3.0)
    }

    private func weightedHistoricalEuroExpectation(draws: [EuroJackpotDraw]) -> Double {
        guard !draws.isEmpty else { return 0 }
        return draws.reduce(0.0) { partial, draw in
            partial + expectedEuroHitsForDate(draw.date)
        } / Double(draws.count)
    }

    private func euroFormatCutoverDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2022, month: 3, day: 25))!
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let average = mean(values)
        let variance = values.reduce(0.0) { partial, value in
            let delta = value - average
            return partial + delta * delta
        } / Double(values.count - 1)
        return sqrt(variance)
    }

    private func pairedConfidenceInterval(_ deltas: [Double]) -> Double {
        guard deltas.count > 1 else { return 0 }
        let tCritical = deltas.count == 50 ? 2.0096 : 1.96
        return tCritical * standardDeviation(deltas) / sqrt(Double(deltas.count))
    }

    private func makeGoal(_ weights: [Double]) -> OptimizationGoal {
        OptimizationGoal(
            frequencyWeight: weights[0],
            pairWeight: weights[1],
            evenOddWeight: weights[2],
            highLowWeight: weights[3],
            sumWeight: weights[4],
            gapWeight: weights[5]
        )
    }

    private func weightLabel(_ profile: Profile) -> String {
        String(
            format: "F %.0f | P %.0f | G/U %.0f | H/N %.0f | S %.0f | A %.0f",
            profile.weights[0], profile.weights[1], profile.weights[2],
            profile.weights[3], profile.weights[4], profile.weights[5]
        )
    }
}

private final class SeededRandomGenerator {

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

        return Ticket(numbers: numbers, euroNumbers: euroNumbers)
    }
}
