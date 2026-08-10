//
//  RandomBenchmarkEngine.swift
//  EuroOpt
//
//  Alpha 7.5 - accelerated empirical random benchmark
//  with paired holdout comparison
//

import Foundation

final class RandomBenchmarkEngine {

    private struct Profile {
        let id: Int
        let goal: OptimizationGoal
        let weights: [Double]
    }

    private struct Aggregate {
        var hits = 0
        var euroHits = 0
        var tickets = 0
        var expectedEuroHits = 0.0
    }

    private let monteCarloRuns = 50
    private let candidateCountMinimum = 301
    private let profileCount = 32

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

        print("")
        print("===================================")
        print("🎲 BESCHLEUNIGTER ZUFALLSBENCHMARK")
        print("===================================")
        print("Holdout-Ziehungen  : \(holdoutCount)")
        print("Kandidaten je Test : \(candidateCount)")
        print("Empfehlungen       : \(recommendationCount)")
        print("Monte-Carlo-Läufe  : \(monteCarloRuns)")
        print("Validation         : nur zur Bestimmung des Alpha-7.5-Profils")
        print("Gewichte / EQI     : nur für das reproduzierte Modellprofil")
        print("Diversitätsregel   : maximal 2 gemeinsame Hauptzahlen")
        print("Euro-Basis         : 10 bis 24.03.2022 / 12 ab 25.03.2022")
        print("")
        print("🔒 Holdout wird weder zur Profilwahl noch zur Zufallserzeugung verwendet.")
        print("🔒 Zufallserzeugung nutzt schnelle Stichproben statt vollständiger Array-Shuffles.")
        print("🔒 Modell und Zufall werden pro Monte-Carlo-Lauf gepaart verglichen.")
        print("")

        let winner = findValidationWinner(
            draws: draws,
            validationRange: 100..<holdoutStart,
            candidateCount: candidateCount,
            recommendationCount: recommendationCount
        )

        guard let winner else {
            print("❌ Zufallsbenchmark: kein Validation-Profil gefunden")
            return
        }

        print("-----------------------------------")
        print("🏆 REPRODUZIERTES ALPHA-7.5-PROFIL")
        print(weightLabel(winner))
        print("-----------------------------------")
        print("")

        // Reproduce the model once on the untouched holdout.
        // This is the fixed baseline for every Monte-Carlo run.
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
            let scoreEngine = ScoreEngine(cache: cache, goal: winner.goal)
            let selected = bestTickets(candidates: candidates, scoreEngine: scoreEngine, limit: recommendationCount)

            for ticket in selected {
                modelMainHits += Set(ticket.numbers).intersection(targetDraw.numbers).count
                modelEuroHits += Set(ticket.euroNumbers).intersection(targetDraw.euroNumbers).count
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
                (modelMainAverage + modelEuroAverage) - (randomMainAverage + randomEuroAverage)
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

        print("")
        print("===================================")
        print("🎲 ZUFALLSBENCHMARK – PAIRED ERGEBNIS")
        print("===================================")
        print(String(format: "Profil              : %@", weightLabel(winner)))
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
        print(String(format: "Theorie Euro        : %.4f", weightedHistoricalEuroExpectation(draws: Array(draws[holdoutStart..<draws.count]))))
        print("")
        print("Statistik:")
        print("- Gepaarter Vergleich: jedes Monte-Carlo-Ergebnis wird gegen dasselbe Modellprofil gestellt.")
        print("- 95-%-KI basiert auf den 50 unabhängigen Monte-Carlo-Replikationen.")
        print("- Ein KI, das 0 nicht einschließt, wäre ein Hinweis auf einen stabilen Unterschied im Benchmark.")
        print("- Der Holdout wurde nicht zur Auswahl des Profils verwendet.")
        print("- Der Zufall verwendet keine EQI-Komponenten und keine historischen Treffer.")
        print("- Hauptzahl-Regeln und Diversitätsregel entsprechen dem bisherigen Benchmark.")
        print("- Historisches 10/12-Eurozahlen-Format wird pro Ziehung berücksichtigt.")
        print("")
        print(String(format: "⏱ Beschleunigter Zufallsbenchmark: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func findValidationWinner(
        draws: [EuroJackpotDraw],
        validationRange: Range<Int>,
        candidateCount: Int,
        recommendationCount: Int
    ) -> Profile? {
        let profiles = makeProfiles()
        let generator = TicketGenerator()
        var totals = Array(repeating: Aggregate(), count: profiles.count)

        for index in validationRange {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )
            let cache = ScoreCache(draws: trainingDraws)

            for profileIndex in profiles.indices {
                let scoreEngine = ScoreEngine(cache: cache, goal: profiles[profileIndex].goal)
                let selected = bestTickets(candidates: candidates, scoreEngine: scoreEngine, limit: recommendationCount)
                totals[profileIndex].hits += selected.reduce(0) {
                    $0 + commonHitCount($1.numbers, targetDraw.numbers)
                }
                totals[profileIndex].euroHits += selected.reduce(0) {
                    $0 + commonHitCount($1.euroNumbers, targetDraw.euroNumbers)
                }
                totals[profileIndex].tickets += selected.count
                totals[profileIndex].expectedEuroHits += expectedEuroHitsForTickets(
                    for: targetDraw.date,
                    ticketCount: selected.count
                )
            }
        }

        guard let winnerIndex = profiles.indices.max(by: {
            validationScore(totals[$0]) < validationScore(totals[$1])
        }) else {
            return nil
        }
        return profiles[winnerIndex]
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
            let swapIndex = scanIndex + rng.nextInt(upperBound: order.count - scanIndex)
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

    private func bestTickets(candidates: [Ticket], scoreEngine: ScoreEngine, limit: Int) -> [Ticket] {
        guard !candidates.isEmpty else { return [] }
        let scored = candidates.map { ($0, scoreEngine.score(ticket: $0)) }.sorted { $0.1 > $1.1 }
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
                    if consecutive > AppSettings.maximumConsecutiveNumbers { return false }
                } else {
                    consecutive = 1
                }
                if gap <= 2 { smallGaps += 1 }
            }
        }

        guard even >= AppSettings.minimumEvenNumbers && even <= AppSettings.maximumEvenNumbers else { return false }
        guard high >= AppSettings.minimumHighNumbers && high <= AppSettings.maximumHighNumbers else { return false }
        guard sum >= AppSettings.minimumSum && sum <= AppSettings.maximumSum else { return false }
        guard smallGaps <= AppSettings.maximumSmallGaps else { return false }
        return true
    }

    private func validationScore(_ aggregate: Aggregate) -> Double {
        let main = aggregate.tickets > 0 ? Double(aggregate.hits) / Double(aggregate.tickets) : 0
        let euro = aggregate.tickets > 0 ? Double(aggregate.euroHits) / Double(aggregate.tickets) : 0
        let expectedEuro = aggregate.tickets > 0 ? aggregate.expectedEuroHits / Double(aggregate.tickets) : 0
        return (main - 0.50) + (euro - expectedEuro)
    }

    private func expectedEuroHitsForTickets(for date: Date, ticketCount: Int) -> Double {
        guard ticketCount > 0 else { return 0 }
        return (date < euroFormatCutoverDate() ? 0.400 : (1.0 / 3.0)) * Double(ticketCount)
    }

    private func weightedHistoricalEuroExpectation(draws: [EuroJackpotDraw]) -> Double {
        guard !draws.isEmpty else { return 0 }
        return draws.reduce(0.0) { partial, draw in
            partial + (draw.date < euroFormatCutoverDate() ? 0.400 : (1.0 / 3.0))
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
        // t(0.975, 49) ≈ 2.009 for the default 50 Monte-Carlo replications.
        let tCritical = deltas.count == 50 ? 2.0096 : 1.96
        return tCritical * standardDeviation(deltas) / sqrt(Double(deltas.count))
    }

    private func makeProfiles() -> [Profile] {
        var profiles: [Profile] = []
        let singles: [[Double]] = [
            [100, 0, 0, 0, 0, 0], [0, 100, 0, 0, 0, 0], [0, 0, 100, 0, 0, 0],
            [0, 0, 0, 100, 0, 0], [0, 0, 0, 0, 100, 0], [0, 0, 0, 0, 0, 100]
        ]
        for weights in singles {
            profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(weights), weights: weights))
        }
        for lhs in 0..<6 {
            for rhs in (lhs + 1)..<6 {
                var weights = Array(repeating: 0.0, count: 6)
                weights[lhs] = 50
                weights[rhs] = 50
                profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(weights), weights: weights))
            }
        }
        for a in 0..<4 {
            for b in (a + 1)..<5 {
                for c in (b + 1)..<6 {
                    var weights = Array(repeating: 0.0, count: 6)
                    weights[a] = 34
                    weights[b] = 33
                    weights[c] = 33
                    profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(weights), weights: weights))
                }
            }
        }
        let diversified = [20.0, 20.0, 15.0, 15.0, 15.0, 15.0]
        profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(diversified), weights: diversified))
        return Array(profiles.prefix(profileCount))
    }

    private func makeGoal(_ weights: [Double]) -> OptimizationGoal {
        OptimizationGoal(
            frequencyWeight: weights[0], pairWeight: weights[1], evenOddWeight: weights[2],
            highLowWeight: weights[3], sumWeight: weights[4], gapWeight: weights[5]
        )
    }

    private func weightLabel(_ profile: Profile) -> String {
        String(format: "F %.0f | P %.0f | G/U %.0f | H/N %.0f | S %.0f | A %.0f",
               profile.weights[0], profile.weights[1], profile.weights[2], profile.weights[3],
               profile.weights[4], profile.weights[5])
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
