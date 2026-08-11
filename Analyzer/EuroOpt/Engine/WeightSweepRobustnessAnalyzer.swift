//
//  WeightSweepRobustnessAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.5 - robustness analysis
//  Separate analyzer. Uses the shared WeightSweepCore.
//

import Foundation

/// Repeats the Alpha 7.5 validation/holdout split over several temporal windows.
///
/// The analyzer uses WeightSweepCore for profile generation, ticket selection,
/// expected Euro hits and validation scoring. It does not modify Alpha 7.5's
/// existing WeightSweepEngine.
final class WeightSweepRobustnessAnalyzer {

    private struct Aggregate {
        var hits = 0
        var euroHits = 0
        var tickets = 0
        var expectedEuroHits = 0.0

        var averageMain: Double {
            tickets > 0 ? Double(hits) / Double(tickets) : 0
        }

        var averageEuro: Double {
            tickets > 0 ? Double(euroHits) / Double(tickets) : 0
        }

        var averageExpectedEuro: Double {
            tickets > 0 ? expectedEuroHits / Double(tickets) : 0
        }

        var score: Double {
            (averageMain - 0.50) + (averageEuro - averageExpectedEuro)
        }
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
    }

    private let warmup = WeightSweepCore.warmup

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
        print("")
        print("🔒 A100 wird nicht bevorzugt.")
        print("🔒 WeightSweepCore ist die gemeinsame Berechnungsquelle für die Robustheitsanalyse.")
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
                    validationTotals[profileIndex].hits += best.reduce(0) {
                        $0 + Set($1.numbers).intersection(targetDraw.numbers).count
                    }
                    validationTotals[profileIndex].euroHits += best.reduce(0) {
                        $0 + Set($1.euroNumbers).intersection(targetDraw.euroNumbers).count
                    }
                    validationTotals[profileIndex].tickets += best.count
                    validationTotals[profileIndex].expectedEuroHits += WeightSweepCore.expectedEuroHits(
                        for: targetDraw.date,
                        ticketCount: best.count
                    )
                }
            }

            guard let winnerIndex = validationTotals.indices.max(by: {
                validationTotals[$0].score < validationTotals[$1].score
            }) else { continue }

            let winner = profiles[winnerIndex]
            var holdout = Aggregate()

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

                holdout.hits += best.reduce(0) {
                    $0 + Set($1.numbers).intersection(targetDraw.numbers).count
                }
                holdout.euroHits += best.reduce(0) {
                    $0 + Set($1.euroNumbers).intersection(targetDraw.euroNumbers).count
                }
                holdout.tickets += best.count
                holdout.expectedEuroHits += WeightSweepCore.expectedEuroHits(
                    for: targetDraw.date,
                    ticketCount: best.count
                )
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
                    holdout: holdout
                )
            )
        }

        print("SPLIT-ERGEBNISSE")
        print("-----------------------------------")
        for result in results {
            let weights = result.winner.weights.map { String(format: "%.0f", $0) }.joined(separator: " | ")
            print("Split \(result.split): \(weights)")
            print(String(format: "  Validation Δ : %+.3f", result.validation.score))
            print(String(format: "  Holdout Δ    : %+.3f", result.holdout.score))
            print("  Validation [\(result.validationStart)..<\(result.validationEnd)] | Holdout [\(result.holdoutStart)..<\(result.holdoutEnd)]")
        }

        var wins: [Int: Int] = [:]
        for result in results {
            wins[result.winner.id, default: 0] += 1
        }

        print("")
        print("PROFIL-HÄUFIGKEIT")
        print("-----------------------------------")
        for result in profiles.sorted(by: { (wins[$0.id] ?? 0) > (wins[$1.id] ?? 0) }) {
            let count = wins[result.id] ?? 0
            guard count > 0 else { continue }
            print("P\(String(format: "%02d", result.id)) : \(count)x | \(result.weights.map { String(format: "%.0f", $0) }.joined(separator: " | "))")
        }

        print("")
        print("Interpretation: Jeder Split wählt sein Profil ausschließlich aus seiner Validation-Hälfte.")
        print("Der zugehörige Holdout wird erst danach ausgewertet.")
        print("A100 wird wie jedes andere Profil behandelt.")
        print("Der Produktions-WeightSweepEngine wurde in diesem Schritt nicht verändert.")
        print("")
        print(String(format: "⏱ Robustheits-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }
}
