import Foundation

/// Isolated F2/50 recency-weighted frequency analysis.
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
        let recencyPower: Double
    }

    private struct Candidate {
        let numbers: [Int]
        let score: Double
    }

    private struct SplitResult {
        let variant: String
        let validation: Aggregate
        let holdout: Aggregate
        let baselineValidation: Aggregate
        let baselineHoldout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let window = 50
    private let splitCount = 10
    private let candidatePoolSize = 15

    // 0 = ordinary F2 frequency.
    // Higher powers increasingly favor the most recent observations.
    private let powers = [0.00, 0.25, 0.50, 0.75, 1.00, 1.50, 2.00]

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 120 else {
            print("❌ F2-Recency-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        print("\n===================================")
        print("⏱ F2/50 RECENCY-FREQUENCY ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(window) Trainingsziehungen")
        print("Kandidatenpool      : Top \(candidatePoolSize) Hauptzahlen")
        print("Recency-Potenz      : 0 / 0.25 / 0.50 / 0.75 / 1.00 / 1.50 / 2.00")
        print("Auswahl             : ausschließlich Validation")
        print("Holdout             : erst nach der Auswahl")
        print("Splits              : \(splitCount) zeitlich getrennte Walk-Forward-Splits\n")

        let variants = powers.map {
            Variant(name: $0 == 0 ? "F2 + Recency 0.00 (Basis)" : String(format: "F2 + Recency %.2f", $0), recencyPower: $0)
        }
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
                let tickets = makeTickets(from: draws, endIndex: index, variants: variants)
                let target = draws[index]
                for i in variants.indices { validation[i].add(ticket: tickets[i], target: target) }
                baselineValidation.add(ticket: tickets[0], target: target)
            }

            let selected = selectVariant(validation: validation, baseline: baselineValidation)

            print("Split \(split + 1)/\(splitCount) – Holdout ...")
            for index in validationEnd..<holdoutEnd {
                let tickets = makeTickets(from: draws, endIndex: index, variants: variants)
                let target = draws[index]
                holdout[selected].add(ticket: tickets[selected], target: target)
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
        print("Recency verändert ausschließlich die Gewichtung der 50 F2-Trainingsziehungen.")
        print("Potenz 0.00 entspricht exakt der normalen F2-Frequenz.")
        print("Die Variante wird ausschließlich auf der Validation ausgewählt.")
        print("Der Holdout wird erst nach der Auswahl ausgewertet.")
        print(String(format: "⏱ F2/50 Recency-Frequency-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func selectVariant(validation: [Aggregate], baseline: Aggregate) -> Int {
        var best = 0
        var bestScore = -Double.infinity

        for i in validation.indices {
            let delta = validation[i].delta - baseline.delta
            // Mild penalty for negative validation results; baseline remains a safe fallback.
            let score = delta - 0.15 * max(0, -delta)
            if score > bestScore {
                bestScore = score
                best = i
            }
        }
        return best
    }

    private func makeTickets(from draws: [EuroJackpotDraw], endIndex: Int, variants: [Variant]) -> [Ticket] {
        let startIndex = max(0, endIndex - window)
        let source = Array(draws[startIndex..<endIndex])
        guard !source.isEmpty else {
            return variants.map { _ in Ticket(numbers: [], euroNumbers: []) }
        }

        var mainFrequency: [Int: Double] = [:]
        var euroFrequency: [Int: Double] = [:]
        let count = source.count

        for (offset, draw) in source.enumerated() {
            // Older observations receive a smaller linear weight.
            let position = Double(offset + 1) / Double(count)
            for number in draw.numbers {
                mainFrequency[number, default: 0] += position
            }
            for number in draw.euroNumbers {
                euroFrequency[number, default: 0] += position
            }
        }

        let ordinaryMain = frequencyMap(draws: source, euro: false)
        let ordinaryEuro = frequencyMap(draws: source, euro: true)

        let rankedMain = (1...50).sorted {
            ordinaryMain[$0, default: 0] == ordinaryMain[$1, default: 0]
                ? $0 < $1
                : ordinaryMain[$0, default: 0] > ordinaryMain[$1, default: 0]
        }
        let rankedEuro = (1...12).sorted {
            ordinaryEuro[$0, default: 0] == ordinaryEuro[$1, default: 0]
                ? $0 < $1
                : ordinaryEuro[$0, default: 0] > ordinaryEuro[$1, default: 0]
        }

        let euroNumbers = Array(rankedEuro.prefix(2)).sorted()
        let pool = Array(rankedMain.prefix(candidatePoolSize))
        guard pool.count >= 5 else {
            return variants.map { _ in Ticket(numbers: Array(pool.prefix(5)).sorted(), euroNumbers: euroNumbers) }
        }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(3003)

        for a in 0..<(pool.count - 4) {
            for b in (a + 1)..<(pool.count - 3) {
                for c in (b + 1)..<(pool.count - 2) {
                    for d in (c + 1)..<(pool.count - 1) {
                        for e in (d + 1)..<pool.count {
                            let numbers = [pool[a], pool[b], pool[c], pool[d], pool[e]].sorted()
                            let score = numbers.reduce(0.0) { $0 + mainFrequency[$1, default: 0] }
                            candidates.append(Candidate(numbers: numbers, score: score))
                        }
                    }
                }
            }
        }

        var result: [Ticket] = []
        result.reserveCapacity(variants.count)

        for variant in variants {
            let ticket: Ticket
            if variant.recencyPower == 0 {
                ticket = bestOrdinaryTicket(pool: pool, frequencies: ordinaryMain, euroNumbers: euroNumbers)
            } else {
                ticket = bestRecencyTicket(
                    candidates: candidates,
                    ordinaryFrequency: ordinaryMain,
                    euroNumbers: euroNumbers,
                    power: variant.recencyPower
                )
            }
            result.append(ticket)
        }

        return result
    }

    private func frequencyMap(draws: [EuroJackpotDraw], euro: Bool) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for draw in draws {
            for number in (euro ? draw.euroNumbers : draw.numbers) {
                result[number, default: 0] += 1
            }
        }
        return result
    }

    private func bestOrdinaryTicket(pool: [Int], frequencies: [Int: Int], euroNumbers: [Int]) -> Ticket {
        let numbers = pool.sorted {
            frequencies[$0, default: 0] == frequencies[$1, default: 0]
                ? $0 < $1
                : frequencies[$0, default: 0] > frequencies[$1, default: 0]
        }.prefix(5).sorted()
        return Ticket(numbers: Array(numbers), euroNumbers: euroNumbers)
    }

    private func bestRecencyTicket(
        candidates: [Candidate],
        ordinaryFrequency: [Int: Int],
        euroNumbers: [Int],
        power: Double
    ) -> Ticket {
        guard let first = candidates.first else { return Ticket(numbers: [], euroNumbers: euroNumbers) }

        var best = first
        var bestScore = recencyScore(candidate: first, ordinaryFrequency: ordinaryFrequency, power: power)

        for candidate in candidates.dropFirst() {
            let score = recencyScore(candidate: candidate, ordinaryFrequency: ordinaryFrequency, power: power)
            if score > bestScore || (score == bestScore && candidate.numbers.lexicographicallyPrecedes(best.numbers)) {
                best = candidate
                bestScore = score
            }
        }

        return Ticket(numbers: best.numbers, euroNumbers: euroNumbers)
    }

    private func recencyScore(candidate: Candidate, ordinaryFrequency: [Int: Int], power: Double) -> Double {
        // Blend ordinary F2 frequency with a recency-shaped score.
        // The recency component is normalized against the ordinary frequency
        // so that the power changes ranking rather than its absolute scale.
        let ordinary = candidate.numbers.reduce(0.0) { $0 + Double(ordinaryFrequency[$1, default: 0]) }
        guard ordinary > 0 else { return candidate.score }

        let recencyFactor = pow(candidate.score / max(1.0, ordinary), power)
        return ordinary * (1.0 + 0.25 * (recencyFactor - 1.0))
    }

    private func printSplitResults(_ results: [SplitResult]) {
        print("\n## RECENCY-FREQUENCY-SPLITS")
        print("Split | Gewinner | Val Δ ggü F2 | Hold Δ | F2 Hold Δ")

        for (i, result) in results.enumerated() {
            let val = result.validation.delta - result.baselineValidation.delta
            print(String(format: "%2d | %@ | %+.3f | %+.3f | %+.3f", i + 1, result.variant, val, result.holdout.delta, result.baselineHoldout.delta))
        }
    }

    private func printAggregateResults(_ results: [SplitResult]) {
        guard !results.isEmpty else { return }

        let selected = results.reduce(0.0) { $0 + $1.holdout.delta } / Double(results.count)
        let f2 = results.reduce(0.0) { $0 + $1.baselineHoldout.delta } / Double(results.count)
        let better = results.filter { $0.holdout.delta > $0.baselineHoldout.delta }.count
        let f2Better = results.filter { $0.holdout.delta < $0.baselineHoldout.delta }.count
        let equal = results.count - better - f2Better

        var counts: [String: Int] = [:]
        for result in results { counts[result.variant, default: 0] += 1 }

        print("\n## RECENCY-FREQUENCY – GESAMT")
        print(String(format: "Gewählte Varianten Hold Δ : %+.3f", selected))
        print(String(format: "F2/50 Hold Δ              : %+.3f", f2))
        print(String(format: "Vorteil ggü. F2           : %+.3f", selected - f2))
        print("Gewählte Variante besser  : \(better)/\(results.count)")
        print("F2 besser                 : \(f2Better)/\(results.count)")
        print("Gleichstand               : \(equal)/\(results.count)")

        print("\n## GEWÄHLTE VARIANTEN")
        for item in counts.sorted(by: { $0.value > $1.value }) {
            print("\(item.key) : \(item.value)/\(results.count)")
        }
    }
}
