import Foundation

/// Tests Alpha 7.5 as a controlled overlay on top of the fixed F2/50 baseline.
///
/// F2/50 always produces the baseline ticket. Alpha may replace that ticket only
/// when its validation score exceeds F2 by at least the configured threshold.
/// Holdout data is never used for the decision.
final class F2AlphaFilterAnalyzer {
    private struct Aggregate {
        var hits = 0
        var euroHits = 0
        var tickets = 0
        var expectedEuroHits = 0.0

        var score: Double {
            guard tickets > 0 else { return 0 }
            let main = Double(hits) / Double(tickets)
            let euro = Double(euroHits) / Double(tickets)
            let expected = expectedEuroHits / Double(tickets)
            return (main - 0.50) + (euro - expected)
        }

        mutating func add(tickets: [Ticket], target: EuroJackpotDraw) {
            for ticket in tickets {
                hits += Set(ticket.numbers).intersection(target.numbers).count
                euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
            }
            self.tickets += tickets.count
            expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: tickets.count)
        }

        mutating func merge(_ other: Aggregate) {
            hits += other.hits
            euroHits += other.euroHits
            tickets += other.tickets
            expectedEuroHits += other.expectedEuroHits
        }
    }

    private struct SplitResult {
        let split: Int
        let alphaProfile: WeightSweepProfile
        let alphaValidation: Aggregate
        let f2Validation: Aggregate
        let alphaHoldout: Aggregate
        let f2Holdout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let frequencyWindow = 50
    private let thresholds: [Double] = [0.00, 0.02, 0.04, 0.06, 0.08, 0.10]

    func run(draws: [EuroJackpotDraw], recommendationCount: Int, splitCount: Int = 10) {
        guard draws.count > warmup + 20 else {
            print("❌ F2/50 → Alpha Filter: zu wenige Ziehungen")
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
        print("🛡️ F2/50 → ALPHA KONTROLLFILTER")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Splits              : \(requestedSplits)")
        print("F2                  : letzte \(frequencyWindow) Trainingsziehungen")
        print("Alpha               : Profilwahl ausschließlich aus Validation")
        print("Filter              : Alpha darf F2 nur ab Validation-Δ-Schwelle ersetzen")
        print("Schwellen           : \(thresholds.map { String(format: "%+.2f", $0) }.joined(separator: " / "))")
        print("Holdout             : erst nach der Entscheidung")
        print("")

        for split in 0..<requestedSplits {
            let splitStart = warmup + split * availableWindow
            let splitEnd = split == requestedSplits - 1
                ? draws.count
                : min(draws.count, warmup + (split + 1) * availableWindow)
            let splitSize = splitEnd - splitStart
            guard splitSize >= 2 else { continue }

            let validationEnd = splitStart + splitSize / 2
            var alphaValidationByProfile = Array(repeating: Aggregate(), count: profiles.count)
            var f2Validation = Aggregate()

            for index in splitStart..<validationEnd {
                let trainingDraws = Array(draws.prefix(index))
                let target = draws[index]
                let candidates = generator.generate(
                    count: candidateCount,
                    draws: trainingDraws,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )
                let cache = ScoreCache(draws: trainingDraws)
                let scoreEngines = profiles.map { ScoreEngine(cache: cache, goal: $0.goal) }

                for profileIndex in profiles.indices {
                    let alphaTickets = WeightSweepCore.bestTickets(
                        candidates: candidates,
                        scoreEngine: scoreEngines[profileIndex],
                        limit: recommendationCount
                    )
                    alphaValidationByProfile[profileIndex].add(tickets: alphaTickets, target: target)
                }

                f2Validation.add(
                    tickets: [makeF2Ticket(from: trainingDraws)],
                    target: target
                )
            }

            guard let winnerIndex = alphaValidationByProfile.indices.max(by: {
                alphaValidationByProfile[$0].score < alphaValidationByProfile[$1].score
            }) else { continue }

            let winner = profiles[winnerIndex]
            var alphaHoldout = Aggregate()
            var f2Holdout = Aggregate()

            for index in validationEnd..<splitEnd {
                let trainingDraws = Array(draws.prefix(index))
                let target = draws[index]
                let candidates = generator.generate(
                    count: candidateCount,
                    draws: trainingDraws,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )
                let cache = ScoreCache(draws: trainingDraws)
                let scoreEngine = ScoreEngine(cache: cache, goal: winner.goal)
                let alphaTickets = WeightSweepCore.bestTickets(
                    candidates: candidates,
                    scoreEngine: scoreEngine,
                    limit: recommendationCount
                )
                let f2Tickets = [makeF2Ticket(from: trainingDraws)]

                alphaHoldout.add(tickets: alphaTickets, target: target)
                f2Holdout.add(tickets: f2Tickets, target: target)
            }

            results.append(
                SplitResult(
                    split: split + 1,
                    alphaProfile: winner,
                    alphaValidation: alphaValidationByProfile[winnerIndex],
                    f2Validation: f2Validation,
                    alphaHoldout: alphaHoldout,
                    f2Holdout: f2Holdout
                )
            )
        }

        print("SPLIT-ERGEBNISSE")
        print("-----------------------------------")
        print("Split | Alpha Profil | Alpha Val Δ | F2 Val Δ | Alpha Hold Δ | F2 Hold Δ")
        for result in results {
            print(String(format: "%2d    | P%02d          | %+.3f      | %+.3f    | %+.3f       | %+.3f",
                         result.split,
                         result.alphaProfile.id,
                         result.alphaValidation.score,
                         result.f2Validation.score,
                         result.alphaHoldout.score,
                         result.f2Holdout.score))
        }

        print("")
        print("===================================")
        print("FILTER-SWEEP")
        print("===================================")
        print("Schwelle | Alpha-Überstimmungen | Holdout Δ | Vorteil vs F2 | Pos. Splits")

        for threshold in thresholds {
            var filtered = Aggregate()
            var f2 = Aggregate()
            var overrides = 0
            var positiveSplits = 0

            for result in results {
                let alphaAdvantage = result.alphaValidation.score - result.f2Validation.score
                let useAlpha = alphaAdvantage >= threshold
                let selected = useAlpha ? result.alphaHoldout : result.f2Holdout
                filtered.merge(selected)
                f2.merge(result.f2Holdout)
                if useAlpha { overrides += 1 }
                if selected.score > result.f2Holdout.score { positiveSplits += 1 }
            }

            print(String(format: "%+.2f     | %2d/%d                 | %+.3f    | %+.3f         | %d/%d",
                         threshold,
                         overrides,
                         results.count,
                         filtered.score,
                         filtered.score - f2.score,
                         positiveSplits,
                         results.count))
        }

        print("")
        print("Interpretation:")
        print("F2/50 ist immer die Basis.")
        print("Alpha ersetzt F2 nur dann, wenn Alpha auf der Validation mindestens die jeweilige Schwelle besser ist.")
        print("Der Holdout wird erst nach dieser Entscheidung ausgewertet.")
        print("Die Schwelle wird nicht anhand des Holdouts ausgewählt.")
        print("")
        print(String(format: "⏱ F2/50 → Alpha Filter: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeF2Ticket(from draws: [EuroJackpotDraw]) -> Ticket {
        let source = Array(draws.suffix(frequencyWindow))
        let main = rankedNumbers(in: source, range: 1...50, limit: 5, isEuro: false)
        let euro = rankedNumbers(in: source, range: 1...12, limit: 2, isEuro: true)
        return Ticket(numbers: main.sorted(), euroNumbers: euro.sorted())
    }

    private func rankedNumbers(in draws: [EuroJackpotDraw], range: ClosedRange<Int>, limit: Int, isEuro: Bool) -> [Int] {
        var counts: [Int: Int] = [:]
        for draw in draws {
            let values = isEuro ? draw.euroNumbers : draw.numbers
            for value in values {
                counts[value, default: 0] += 1
            }
        }
        return Array(range.sorted {
            let left = counts[$0, default: 0]
            let right = counts[$1, default: 0]
            return left == right ? $0 < $1 : left > right
        }.prefix(limit))
    }
}
