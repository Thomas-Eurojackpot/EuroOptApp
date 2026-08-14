import Foundation

//
//  WeightSweepRobustnessAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.5 - robustness analysis
//  Separate analyzer. Uses the shared WeightSweepCore.
//
/// Repeats the Alpha 7.5 validation/holdout split over several temporal windows.
/// Additionally compares the selected Alpha profile directly against the fixed
/// 50-draw frequency baseline and against an F2 -> Alpha constrained candidate pool.
final class WeightSweepRobustnessAnalyzer {
    private struct Aggregate {
        var hits = 0
        var euroHits = 0
        var tickets = 0
        var expectedEuroHits = 0.0
        var averageMain: Double { tickets > 0 ? Double(hits) / Double(tickets) : 0 }
        var averageEuro: Double { tickets > 0 ? Double(euroHits) / Double(tickets) : 0 }
        var averageExpectedEuro: Double { tickets > 0 ? expectedEuroHits / Double(tickets) : 0 }
        var score: Double { (averageMain - 0.50) + (averageEuro - averageExpectedEuro) }
    }

    private struct SplitResult {
        let split: Int
        let winner: WeightSweepProfile
        let validation: Aggregate
        let holdout: Aggregate
        let frequencyValidation: Aggregate
        let frequencyHoldout: Aggregate
        let constrainedValidation: Aggregate
        let constrainedHoldout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let frequencyWindow = 50
    private let constrainedMainPoolSize = 10
    private let constrainedEuroPoolSize = 4

    func run(draws: [EuroJackpotDraw], recommendationCount: Int, splitCount: Int = 10) {
        guard draws.count > warmup + 20 else {
            print("❌ Alpha 7.5 Robustheit: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - warmup
        let requestedSplits = max(1, splitCount)
        let availableWindow = totalTests / requestedSplits
        let profiles = WeightSweepCore.makeProfiles()
        let generator = TicketGenerator()
        let candidateCount = WeightSweepCore.candidateCount()
        var results: [SplitResult] = []

        print("")
        print("===================================")
        print("🧪 ALPHA 7.5 ROBUSTHEITS-ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Testbereich         : \(totalTests)")
        print("Geplante Splits     : \(requestedSplits)")
        print("Split-Prinzip       : Validation 50 % / Holdout 50 %")
        print("Profile             : \(profiles.count)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Profilwahl          : ausschließlich Validation")
        print("Holdout             : erst nach Profilwahl")
        print("Vergleichsbasis     : F2 / letzte \(frequencyWindow) Ziehungen")
        print("F2 → Alpha          : Top \(constrainedMainPoolSize) Hauptzahlen + Top \(constrainedEuroPoolSize) Eurozahlen")
        print("")

        for split in 0..<requestedSplits {
            let validationStart = warmup + split * availableWindow
            let splitEnd = split == requestedSplits - 1 ? draws.count : min(draws.count, warmup + (split + 1) * availableWindow)
            let splitSize = splitEnd - validationStart
            guard splitSize >= 2 else { continue }
            let validationSize = splitSize / 2
            let holdoutStart = validationStart + validationSize
            let holdoutEnd = splitEnd

            var validationTotals = Array(repeating: Aggregate(), count: profiles.count)
            var frequencyValidation = Aggregate()

            for index in validationStart..<holdoutStart {
                let trainingDraws = Array(draws.prefix(index))
                let targetDraw = draws[index]
                let candidates = generator.generate(count: candidateCount, draws: trainingDraws, goal: OptimizationGoal(), hillClimbingIterations: 0)
                let cache = ScoreCache(draws: trainingDraws)
                let scoreEngines = profiles.map { ScoreEngine(cache: cache, goal: $0.goal) }

                for profileIndex in profiles.indices {
                    let best = WeightSweepCore.bestTickets(candidates: candidates, scoreEngine: scoreEngines[profileIndex], limit: recommendationCount)
                    add(tickets: best, target: targetDraw, to: &validationTotals[profileIndex])
                }

                add(tickets: [makeFrequencyTicket(from: trainingDraws)], target: targetDraw, to: &frequencyValidation)
            }

            guard let winnerIndex = validationTotals.indices.max(by: { validationTotals[$0].score < validationTotals[$1].score }) else { continue }
            let winner = profiles[winnerIndex]
            var holdout = Aggregate()
            var frequencyHoldout = Aggregate()
            var constrainedValidation = Aggregate()
            var constrainedHoldout = Aggregate()

            // F2 → Alpha: the Alpha profile is selected from the unrestricted Validation.
            // For every target, the constrained ticket is built only from draws before that target.
            for index in validationStart..<holdoutStart {
                let trainingDraws = Array(draws.prefix(index))
                let targetDraw = draws[index]
                let cache = ScoreCache(draws: trainingDraws)
                let scoreEngine = ScoreEngine(cache: cache, goal: winner.goal)
                let constrainedTickets = makeConstrainedTickets(from: trainingDraws, scoreEngine: scoreEngine, limit: recommendationCount)
                add(tickets: constrainedTickets, target: targetDraw, to: &constrainedValidation)
            }

            for index in holdoutStart..<holdoutEnd {
                let trainingDraws = Array(draws.prefix(index))
                let targetDraw = draws[index]
                let candidates = generator.generate(count: candidateCount, draws: trainingDraws, goal: OptimizationGoal(), hillClimbingIterations: 0)
                let cache = ScoreCache(draws: trainingDraws)
                let scoreEngine = ScoreEngine(cache: cache, goal: winner.goal)
                let best = WeightSweepCore.bestTickets(candidates: candidates, scoreEngine: scoreEngine, limit: recommendationCount)
                add(tickets: best, target: targetDraw, to: &holdout)
                add(tickets: [makeFrequencyTicket(from: trainingDraws)], target: targetDraw, to: &frequencyHoldout)

                let constrainedHoldoutTickets = makeConstrainedTickets(from: trainingDraws, scoreEngine: scoreEngine, limit: recommendationCount)
                add(tickets: constrainedHoldoutTickets, target: targetDraw, to: &constrainedHoldout)
            }

            results.append(SplitResult(split: split + 1, winner: winner, validation: validationTotals[winnerIndex], holdout: holdout, frequencyValidation: frequencyValidation, frequencyHoldout: frequencyHoldout, constrainedValidation: constrainedValidation, constrainedHoldout: constrainedHoldout))
        }

        print("SPLIT-ERGEBNISSE")
        print("-----------------------------------")
        print("Split | Alpha Profil | Alpha Val Δ | F2 Val Δ | Alpha Hold Δ | F2 Hold Δ")
        for result in results {
            print(String(format: " %2d   | P%02d          | %+.3f      | %+.3f    | %+.3f       | %+.3f", result.split, result.winner.id, result.validation.score, result.frequencyValidation.score, result.holdout.score, result.frequencyHoldout.score))
        }

        print("")
        print("ALPHA 7.5 vs. F2 / 50 – GESAMT")
        print("-----------------------------------")
        var alphaValidation = Aggregate()
        var alphaHoldout = Aggregate()
        var frequencyValidation = Aggregate()
        var frequencyHoldout = Aggregate()
        var constrainedValidation = Aggregate()
        var constrainedHoldout = Aggregate()
        for result in results {
            merge(result.validation, into: &alphaValidation)
            merge(result.holdout, into: &alphaHoldout)
            merge(result.frequencyValidation, into: &frequencyValidation)
            merge(result.frequencyHoldout, into: &frequencyHoldout)
            merge(result.constrainedValidation, into: &constrainedValidation)
            merge(result.constrainedHoldout, into: &constrainedHoldout)
        }
        print(String(format: "Alpha 7.5  | Val Δ %+.3f | Holdout Δ %+.3f", alphaValidation.score, alphaHoldout.score))
        print(String(format: "F2 / 50    | Val Δ %+.3f | Holdout Δ %+.3f", frequencyValidation.score, frequencyHoldout.score))
        print(String(format: "Vorteil Alpha im Holdout: %+.3f Δ-Punkte", alphaHoldout.score - frequencyHoldout.score))
        let alphaWins = results.filter { $0.holdout.score > $0.frequencyHoldout.score }.count
        let f2Wins = results.filter { $0.frequencyHoldout.score > $0.holdout.score }.count
        print("Holdout-Splits: Alpha \(alphaWins)x | F2 \(f2Wins)x | Gleichstand \(results.count - alphaWins - f2Wins)x")

        print("")
        print("F2 → ALPHA – GESAMT")
        print("-----------------------------------")
        print(String(format: "F2 → Alpha  | Val Δ %+.3f | Holdout Δ %+.3f", constrainedValidation.score, constrainedHoldout.score))
        print(String(format: "Mehrwert gegenüber F2 im Holdout: %+.3f Δ-Punkte", constrainedHoldout.score - frequencyHoldout.score))
        let constrainedWins = results.filter { $0.constrainedHoldout.score > $0.frequencyHoldout.score }.count
        let constrainedLosses = results.filter { $0.constrainedHoldout.score < $0.frequencyHoldout.score }.count
        print("Holdout-Splits gegen F2: F2→Alpha \(constrainedWins)x | F2 \(constrainedLosses)x | Gleichstand \(results.count - constrainedWins - constrainedLosses)x")

        print("")
        FrequencyBaselineAnalyzer().run(draws: draws, splitCount: requestedSplits)
        print("")
        print(String(format: "⏱ Robustheits-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeFrequencyTicket(from draws: [EuroJackpotDraw]) -> Ticket {
        let source = Array(draws.suffix(frequencyWindow))
        return makeFrequencyTicket(from: source, mainLimit: 5, euroLimit: 2)
    }

    private func makeConstrainedTickets(from draws: [EuroJackpotDraw], scoreEngine: ScoreEngine, limit: Int) -> [Ticket] {
        let source = Array(draws.suffix(frequencyWindow))
        let mainPool = rankedNumbers(in: source, range: 1...50, limit: constrainedMainPoolSize, isEuro: false)
        let euroPool = rankedNumbers(in: source, range: 1...12, limit: constrainedEuroPoolSize, isEuro: true)
        var tickets: [Ticket] = []
        let mainCombinations = combinations(mainPool, choosing: 5)
        let euroCombinations = combinations(euroPool, choosing: 2)
        tickets.reserveCapacity(mainCombinations.count * euroCombinations.count)
        for main in mainCombinations {
            for euro in euroCombinations {
                tickets.append(Ticket(numbers: main.sorted(), euroNumbers: euro.sorted()))
            }
        }
        return WeightSweepCore.bestTickets(candidates: tickets, scoreEngine: scoreEngine, limit: limit)
    }

    private func makeFrequencyTicket(from source: [EuroJackpotDraw], mainLimit: Int, euroLimit: Int) -> Ticket {
        let mainNumbers = rankedNumbers(in: source, range: 1...50, limit: mainLimit, isEuro: false)
        let euroNumbers = rankedNumbers(in: source, range: 1...12, limit: euroLimit, isEuro: true)
        return Ticket(numbers: mainNumbers.sorted(), euroNumbers: euroNumbers.sorted())
    }

    private func rankedNumbers(in draws: [EuroJackpotDraw], range: ClosedRange<Int>, limit: Int, isEuro: Bool) -> [Int] {
        var counts: [Int: Int] = [:]
        for draw in draws {
            let values = isEuro ? draw.euroNumbers : draw.numbers
            for value in values { counts[value, default: 0] += 1 }
        }
        return Array(range.sorted {
            let left = counts[$0, default: 0]
            let right = counts[$1, default: 0]
            return left == right ? $0 < $1 : left > right
        }.prefix(limit))
    }

    private func combinations(_ values: [Int], choosing k: Int) -> [[Int]] {
        guard k > 0, values.count >= k else { return k == 0 ? [[]] : [] }
        if k == 1 { return values.map { [$0] } }
        var result: [[Int]] = []
        for index in 0...(values.count - k) {
            let head = values[index]
            let tails = combinations(Array(values[(index + 1)...]), choosing: k - 1)
            for tail in tails { result.append([head] + tail) }
        }
        return result
    }

    private func add(tickets: [Ticket], target: EuroJackpotDraw, to aggregate: inout Aggregate) {
        for ticket in tickets {
            aggregate.hits += Set(ticket.numbers).intersection(target.numbers).count
            aggregate.euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
        }
        aggregate.tickets += tickets.count
        aggregate.expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: tickets.count)
    }

    private func merge(_ source: Aggregate, into target: inout Aggregate) {
        target.hits += source.hits
        target.euroHits += source.euroHits
        target.tickets += source.tickets
        target.expectedEuroHits += source.expectedEuroHits
    }
}
