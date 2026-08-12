//
//  WeightSweepRobustnessAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.5 - robustness analysis
//  Separate analyzer. Uses the shared WeightSweepCore.
//

import Foundation

/// Repeats the Alpha 7.5 validation/holdout split over several temporal windows.
/// Additionally compares the selected Alpha profile directly against the fixed
/// 50-draw frequency baseline on the exact same split boundaries.
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
        let validationStart: Int
        let validationEnd: Int
        let holdoutStart: Int
        let holdoutEnd: Int
        let winner: WeightSweepProfile
        let validation: Aggregate
        let holdout: Aggregate
        let frequencyValidation: Aggregate
        let frequencyHoldout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let frequencyWindow = 50

    func run(draws: [EuroJackpotDraw], recommendationCount: Int, splitCount: Int = 5) {
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
        print("")
        print("🔒 A100 wird nicht bevorzugt.")
        print("🔒 WeightSweepCore ist die gemeinsame Berechnungsquelle für die Alpha-Analyse.")
        print("🔒 F2 verwendet exakt dieselben zeitlichen Validation-/Holdout-Grenzen.")
        print("")

        for split in 0..<requestedSplits {
            let validationStart = warmup + split * availableWindow
            let splitEnd = split == requestedSplits - 1
                ? draws.count
                : min(draws.count, warmup + (split + 1) * availableWindow)
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
                let candidates = generator.generate(
                    count: candidateCount,
                    draws: trainingDraws,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )
                let cache = ScoreCache(draws: trainingDraws)
                let scoreEngines = profiles.map { ScoreEngine(cache: cache, goal: $0.goal) }

                for profileIndex in profiles.indices {
                    let best = WeightSweepCore.bestTickets(
                        candidates: candidates,
                        scoreEngine: scoreEngines[profileIndex],
                        limit: recommendationCount
                    )
                    add(tickets: best, target: targetDraw, to: &validationTotals[profileIndex])
                }

                let frequencyTicket = makeFrequencyTicket(from: trainingDraws, window: frequencyWindow)
                add(tickets: [frequencyTicket], target: targetDraw, to: &frequencyValidation)
            }

            guard let winnerIndex = validationTotals.indices.max(by: {
                validationTotals[$0].score < validationTotals[$1].score
            }) else { continue }

            let winner = profiles[winnerIndex]
            var holdout = Aggregate()
            var frequencyHoldout = Aggregate()

            for index in holdoutStart..<holdoutEnd {
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
                let best = WeightSweepCore.bestTickets(
                    candidates: candidates,
                    scoreEngine: scoreEngine,
                    limit: recommendationCount
                )
                add(tickets: best, target: targetDraw, to: &holdout)

                let frequencyTicket = makeFrequencyTicket(from: trainingDraws, window: frequencyWindow)
                add(tickets: [frequencyTicket], target: targetDraw, to: &frequencyHoldout)
            }

            results.append(
                SplitResult(
                    split: split + 1,
                    validationStart: validationStart,
                    validationEnd: holdoutStart,
                    holdoutStart: holdoutStart,
                    holdoutEnd: holdoutEnd,
                    winner: winner,
                    validation: validationTotals[winnerIndex],
                    holdout: holdout,
                    frequencyValidation: frequencyValidation,
                    frequencyHoldout: frequencyHoldout
                )
            )
        }

        print("SPLIT-ERGEBNISSE")
        print("-----------------------------------")
        print("Split | Alpha Profil | Alpha Val Δ | F2 Val Δ | Alpha Hold Δ | F2 Hold Δ")
        for result in results {
            print(String(format: " %2d   | P%02d          | %+.3f      | %+.3f    | %+.3f       | %+.3f",
                         result.split,
                         result.winner.id,
                         result.validation.score,
                         result.frequencyValidation.score,
                         result.holdout.score,
                         result.frequencyHoldout.score))
        }

        var wins: [Int: Int] = [:]
        for result in results { wins[result.winner.id, default: 0] += 1 }

        print("")
        print("PROFIL-HÄUFIGKEIT")
        print("-----------------------------------")
        for profile in profiles.sorted(by: { (wins[$0.id] ?? 0) > (wins[$1.id] ?? 0) }) {
            let count = wins[profile.id] ?? 0
            guard count > 0 else { continue }
            print("P\(String(format: "%02d", profile.id)) : \(count)x | \(profile.weights.map { String(format: "%.0f", $0) }.joined(separator: " | "))")
        }

        print("")
        print("ALPHA 7.5 vs. F2 / 50 – GESAMT")
        print("-----------------------------------")
        var alphaValidation = Aggregate()
        var alphaHoldout = Aggregate()
        var frequencyValidation = Aggregate()
        var frequencyHoldout = Aggregate()
        for result in results {
            merge(result.validation, into: &alphaValidation)
            merge(result.holdout, into: &alphaHoldout)
            merge(result.frequencyValidation, into: &frequencyValidation)
            merge(result.frequencyHoldout, into: &frequencyHoldout)
        }

        print(String(format: "Alpha 7.5  | Val Δ %+.3f | Holdout Δ %+.3f | Haupt %.3f | Euro %.3f",
                     alphaValidation.score, alphaHoldout.score, alphaHoldout.averageMain, alphaHoldout.averageEuro))
        print(String(format: "F2 / 50    | Val Δ %+.3f | Holdout Δ %+.3f | Haupt %.3f | Euro %.3f",
                     frequencyValidation.score, frequencyHoldout.score, frequencyHoldout.averageMain, frequencyHoldout.averageEuro))
        print(String(format: "Vorteil Alpha im Holdout: %+.3f Δ-Punkte",
                     alphaHoldout.score - frequencyHoldout.score))

        let alphaHoldoutWins = results.filter { $0.holdout.score > $0.frequencyHoldout.score }.count
        let frequencyHoldoutWins = results.filter { $0.frequencyHoldout.score > $0.holdout.score }.count
        let ties = results.count - alphaHoldoutWins - frequencyHoldoutWins
        print("Holdout-Splits: Alpha \(alphaHoldoutWins)x | F2 \(frequencyHoldoutWins)x | Gleichstand \(ties)x")

        print("")
        print("Interpretation: Alpha wählt sein Profil je Split ausschließlich aus der Validation.")
        print("F2 ist eine feste, nicht optimierte 50-Ziehungs-Baseline.")
        print("Beide Methoden werden auf exakt denselben Zielziehungen bewertet.")
        print("Der Produktions-WeightSweepEngine wurde nicht verändert.")
        print("")
        FrequencyBaselineAnalyzer().run(draws: draws, splitCount: requestedSplits)
        print("")
        print(String(format: "⏱ Robustheits-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeFrequencyTicket(from draws: [EuroJackpotDraw], window: Int) -> Ticket {
        let source = Array(draws.suffix(window))
        var mainCounts: [Int: Int] = [:]
        var euroCounts: [Int: Int] = [:]
        for draw in source {
            for number in draw.numbers { mainCounts[number, default: 0] += 1 }
            for number in draw.euroNumbers { euroCounts[number, default: 0] += 1 }
        }
        let numbers = (1...50).sorted {
            let lhs = mainCounts[$0, default: 0]
            let rhs = mainCounts[$1, default: 0]
            return lhs == rhs ? $0 < $1 : lhs > rhs
        }.prefix(5).sorted()
        let euroNumbers = (1...12).sorted {
            let lhs = euroCounts[$0, default: 0]
            let rhs = euroCounts[$1, default: 0]
            return lhs == rhs ? $0 < $1 : lhs > rhs
        }.prefix(2).sorted()
        return Ticket(numbers: Array(numbers), euroNumbers: Array(euroNumbers))
    }

    private func add(tickets: [Ticket], target: EuroJackpotDraw, to aggregate: inout Aggregate) {
        for ticket in tickets {
            aggregate.hits += Set(ticket.numbers).intersection(target.numbers).count
            aggregate.euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
        }
        aggregate.tickets += tickets.count
        aggregate.expectedEuroHits += WeightSweepCore.expectedEuroHits(
            for: target.date,
            ticketCount: tickets.count
        )
    }

    private func merge(_ source: Aggregate, into target: inout Aggregate) {
        target.hits += source.hits
        target.euroHits += source.euroHits
        target.tickets += source.tickets
        target.expectedEuroHits += source.expectedEuroHits
    }
}
