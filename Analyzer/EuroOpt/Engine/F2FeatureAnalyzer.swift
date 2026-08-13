import Foundation

/// Isolated F2/50 pair-frequency analysis.
/// F2 remains the unchanged baseline and nothing is fed into production Alpha.
final class F2FeatureAnalyzer {
    private struct Aggregate {
        var hits = 0
        var euroHits = 0
        var tickets = 0
        var expectedEuroHits = 0.0

        var mainRate: Double { tickets > 0 ? Double(hits) / Double(tickets) : 0 }
        var euroRate: Double { tickets > 0 ? Double(euroHits) / Double(tickets) : 0 }
        var euroExpected: Double { tickets > 0 ? expectedEuroHits / Double(tickets) : 0 }
        var delta: Double { (mainRate - 0.50) + (euroRate - euroExpected) }

        mutating func add(ticket: Ticket, target: EuroJackpotDraw) {
            hits += Set(ticket.numbers).intersection(Set(target.numbers)).count
            euroHits += Set(ticket.euroNumbers).intersection(Set(target.euroNumbers)).count
            tickets += 1
            expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: 1)
        }
    }

    private struct Variant {
        let name: String
        let weight: Double
    }

    private struct Candidate {
        let numbers: [Int]
        let baseScore: Double
        let pairScore: Double
    }

    private struct SplitResult {
        let variant: String
        let validation: Aggregate
        let holdout: Aggregate
        let baselineValidation: Aggregate
        let baselineHoldout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let f2Window = 50
    private let multiWindows = [50, 100, 200, 400]
    private let splitCount = 10
    private let candidatePoolSize = 15
    private let weights = [0.05, 0.10, 0.15, 0.20, 0.25]
    private let shrinkage = 10.0

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 120 else {
            print("❌ F2-Pair-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        print("\n===================================")
        print("🔗 F2/50 PAIR-FREQUENCY ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(f2Window) Trainingsziehungen")
        print("Kandidatenpool      : Top \(candidatePoolSize) Hauptzahlen nach F2-Frequenz")
        print("Paarfenster         : 50 / 100 / 200 / 400")
        print("Shrinkage           : \(Int(shrinkage))")
        print("Pair-Gewichte       : 5% / 10% / 15% / 20% / 25%")
        print("Auswahl             : ausschließlich Validation")
        print("Holdout             : erst nach der Auswahl")
        print("Splits              : \(splitCount) zeitlich getrennte Walk-Forward-Splits\n")

        let variants = weights.map { Variant(name: "F2 + PairConsensus @ \(Int($0 * 100))%", weight: $0) }
        var results: [SplitResult] = []
        results.reserveCapacity(splitCount)

        for split in 0..<splitCount {
            let available = draws.count - warmup
            let block = available / splitCount
            let validationStart = warmup + split * block
            let validationEnd = split == splitCount - 1
                ? warmup + Int(Double(available) * 0.92)
                : validationStart + max(8, block * 2 / 3)
            let holdoutEnd = split == splitCount - 1 ? draws.count : validationStart + block

            guard validationStart < validationEnd,
                  validationEnd < holdoutEnd,
                  holdoutEnd <= draws.count else { continue }

            var validation = Array(repeating: Aggregate(), count: variants.count)
            var holdout = Array(repeating: Aggregate(), count: variants.count)
            var baselineValidation = Aggregate()
            var baselineHoldout = Aggregate()

            print("Split \(split + 1)/\(splitCount) – Validation ...")
            for index in validationStart..<validationEnd {
                let tickets = makeTickets(from: Array(draws.prefix(index)), variants: variants)
                let target = draws[index]
                for i in variants.indices { validation[i].add(ticket: tickets[i + 1], target: target) }
                baselineValidation.add(ticket: tickets[0], target: target)
            }

            let selected = selectVariant(validation: validation, baseline: baselineValidation)

            print("Split \(split + 1)/\(splitCount) – Holdout ...")
            for index in validationEnd..<holdoutEnd {
                let tickets = makeTickets(from: Array(draws.prefix(index)), variants: variants)
                let target = draws[index]
                holdout[selected].add(ticket: tickets[selected + 1], target: target)
                baselineHoldout.add(ticket: tickets[0], target: target)
            }

            results.append(SplitResult(
                variant: variants[selected].name,
                validation: validation[selected],
                holdout: holdout[selected],
                baselineValidation: baselineValidation,
                baselineHoldout: baselineHoldout
            ))
        }

        printSplitResults(results)
        printAggregateResults(results)
        print("\nInterpretation:")
        print("F2/50 bleibt unverändert die Referenz.")
        print("PairConsensus verändert nur die Rangfolge der F2-Kandidaten.")
        print("Die Paarstärke wird über 50/100/200/400 Ziehungen gemittelt und gegen die theoretische Paarerwartung geshrinkt.")
        print("Die Gewichtung wird ausschließlich auf der Validation gewählt.")
        print("Der Holdout wird erst nach der Auswahl ausgewertet.")
        print(String(format: "⏱ F2/50 Pair-Frequency-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func selectVariant(validation: [Aggregate], baseline: Aggregate) -> Int {
        var best = 0
        var bestScore = -Double.infinity
        for i in validation.indices {
            let delta = validation[i].delta - baseline.delta
            let score = delta - 0.15 * max(0, -delta)
            if score > bestScore { bestScore = score; best = i }
        }
        return best
    }

    private func makeTickets(from draws: [EuroJackpotDraw], variants: [Variant]) -> [Ticket] {
        let source = Array(draws.suffix(f2Window))
        var main: [Int: Int] = [:]
        var euro: [Int: Int] = [:]
        for draw in source {
            for n in draw.numbers { main[n, default: 0] += 1 }
            for n in draw.euroNumbers { euro[n, default: 0] += 1 }
        }

        let rankedMain = (1...50).sorted {
            main[$0, default: 0] == main[$1, default: 0]
                ? $0 < $1
                : main[$0, default: 0] > main[$1, default: 0]
        }
        let rankedEuro = (1...12).sorted {
            euro[$0, default: 0] == euro[$1, default: 0]
                ? $0 < $1
                : euro[$0, default: 0] > euro[$1, default: 0]
        }

        let euroNumbers = Array(rankedEuro.prefix(2)).sorted()
        let baselineNumbers = Array(rankedMain.prefix(5)).sorted()
        let baseline = Ticket(numbers: baselineNumbers, euroNumbers: euroNumbers)
        let candidates = makeCandidates(rankedMain: rankedMain, frequencies: main, draws: draws)

        var result = [baseline]
        result.reserveCapacity(variants.count + 1)
        for variant in variants {
            result.append(bestTicket(candidates: candidates, euroNumbers: euroNumbers, weight: variant.weight))
        }
        return result
    }

    private func makeCandidates(rankedMain: [Int], frequencies: [Int: Int], draws: [EuroJackpotDraw]) -> [Candidate] {
        let pool = Array(rankedMain.prefix(candidatePoolSize))
        guard pool.count >= 5 else { return [] }

        var pairConsensus: [Int: Double] = [:]
        let expectedProbability = 10.0 / (50.0 * 49.0 / 2.0)

        for window in multiWindows {
            let source = Array(draws.suffix(window))
            var counts: [Int: Int] = [:]
            for draw in source {
                let numbers = draw.numbers.sorted()
                for i in 0..<(numbers.count - 1) {
                    for j in (i + 1)..<numbers.count {
                        let key = numbers[i] * 100 + numbers[j]
                        counts[key, default: 0] += 1
                    }
                }
            }

            for i in 0..<(pool.count - 1) {
                for j in (i + 1)..<pool.count {
                    let a = min(pool[i], pool[j])
                    let b = max(pool[i], pool[j])
                    let key = a * 100 + b
                    let observed = Double(counts[key, default: 0])
                    let expected = Double(window) * expectedProbability
                    let smoothed = (observed + shrinkage * expected) / (Double(window) + shrinkage)
                    pairConsensus[key, default: 0] += smoothed / expected
                }
            }
        }

        let denominator = Double(multiWindows.count)
        var candidates: [Candidate] = []
        candidates.reserveCapacity(3003)

        for a in 0..<(pool.count - 4) {
            for b in (a + 1)..<(pool.count - 3) {
                for c in (b + 1)..<(pool.count - 2) {
                    for d in (c + 1)..<(pool.count - 1) {
                        for e in (d + 1)..<pool.count {
                            let numbers = [pool[a], pool[b], pool[c], pool[d], pool[e]].sorted()
                            let base = Double(numbers.reduce(0) { $0 + frequencies[$1, default: 0] })
                            var pairSum = 0.0
                            for i in 0..<(numbers.count - 1) {
                                for j in (i + 1)..<numbers.count {
                                    let key = numbers[i] * 100 + numbers[j]
                                    pairSum += pairConsensus[key, default: 1.0] / denominator
                                }
                            }
                            candidates.append(Candidate(numbers: numbers, baseScore: base, pairScore: pairSum / 10.0))
                        }
                    }
                }
            }
        }
        return candidates
    }

    private func bestTicket(candidates: [Candidate], euroNumbers: [Int], weight: Double) -> Ticket {
        guard let first = candidates.first else { return Ticket(numbers: [], euroNumbers: euroNumbers) }
        var best = first
        var bestScore = first.baseScore * (1.0 + weight * max(0, first.pairScore - 1.0))
        for candidate in candidates.dropFirst() {
            let score = candidate.baseScore * (1.0 + weight * max(0, candidate.pairScore - 1.0))
            if score > bestScore || (score == bestScore && candidate.numbers.lexicographicallyPrecedes(best.numbers)) {
                best = candidate
                bestScore = score
            }
        }
        return Ticket(numbers: best.numbers, euroNumbers: euroNumbers)
    }

    private func printSplitResults(_ results: [SplitResult]) {
        print("\n## PAIR-FREQUENCY-SPLITS")
        print("Split | Gewinner | Val Δ ggü F2 | Hold Δ | F2 Hold Δ")
        for (i, r) in results.enumerated() {
            let val = r.validation.delta - r.baselineValidation.delta
            print(String(format: "%2d | %@ | %+.3f | %+.3f | %+.3f", i + 1, r.variant, val, r.holdout.delta, r.baselineHoldout.delta))
        }
    }

    private func printAggregateResults(_ results: [SplitResult]) {
        guard !results.isEmpty else { return }
        let selected = results.reduce(0.0) { $0 + $1.holdout.delta } / Double(results.count)
        let f2 = results.reduce(0.0) { $0 + $1.baselineHoldout.delta } / Double(results.count)
        let better = results.filter { $0.holdout.delta > $0.baselineHoldout.delta }.count
        let f2Better = results.filter { $0.holdout.delta < $0.baselineHoldout.delta }.count
        var counts: [String: Int] = [:]
        for r in results { counts[r.variant, default: 0] += 1 }

        print("\n## PAIR-FREQUENCY – GESAMT")
        print(String(format: "Gewählte Varianten Hold Δ : %+.3f", selected))
        print(String(format: "F2/50 Hold Δ              : %+.3f", f2))
        print(String(format: "Vorteil ggü. F2           : %+.3f", selected - f2))
        print("Gewählte Variante besser  : \(better)/\(results.count)")
        print("F2 besser                 : \(f2Better)/\(results.count)")
        print("\n## GEWÄHLTE VARIANTEN")
        for item in counts.sorted(by: { $0.value > $1.value }) {
            print("\(item.key) : \(item.value)/\(results.count)")
        }
    }
}
