import Foundation

/// F2 feature analysis with soft feature weighting.
/// F2 remains the unchanged baseline. Feature signals modify candidate ranking
/// softly; no feature is used as a hard production filter.
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
        let mask: Int
        let weight: Double
    }

    private struct Candidate {
        let numbers: [Int]
        let baseScore: Double
        let featureMask: Int
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
    private let weights = [0.05, 0.10, 0.15, 0.20, 0.25]

    // Feature bits:
    // 0 Sum100–124, 1 Even2, 2 High2, 3 Adj0,
    // 4 Spread20–29, 5 Spread30–39, 6 Spread40+
    private let featureNames: [Int: String] = [
        0: "Sum100–124",
        1: "Even2",
        2: "High2",
        3: "Adj0",
        4: "Spread20–29",
        5: "Spread30–39",
        6: "Spread40+"
    ]

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 120 else {
            print("❌ F2-Feature-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        print("\n===================================")
        print("🔎 F2/50 SOFT-FEATURE-WEIGHT ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(window) Trainingsziehungen")
        print("Kandidatenpool      : Top \(candidatePoolSize) Hauptzahlen nach F2-Frequenz")
        print("Features            : Summe / Gerade / Hoch / Adjacent / Spread")
        print("Gewichte            : 5% / 10% / 15% / 20% / 25%")
        print("Varianten            : einzelne Features + Feature-Kombinationen")
        print("Optimierung          : Kandidatenkombinationen werden pro Ziehung nur einmal berechnet")
        print("Auswahl             : ausschließlich Validation")
        print("Holdout             : erst nach der Auswahl")
        print("Splits               : \(splitCount) zeitlich getrennte Walk-Forward-Splits\n")

        let variants = makeVariants()
        var splitResults: [SplitResult] = []
        splitResults.reserveCapacity(splitCount)

        for split in 0..<splitCount {
            let available = draws.count - warmup
            let block = available / splitCount
            let validationStart = warmup + split * block
            let validationEnd = split == splitCount - 1
                ? warmup + Int(Double(available) * 0.92)
                : validationStart + max(8, block * 2 / 3)
            let holdoutEnd = split == splitCount - 1 ? draws.count : validationStart + block

            guard validationStart >= warmup,
                  validationStart < validationEnd,
                  validationEnd < holdoutEnd,
                  holdoutEnd <= draws.count else { continue }

            var validationAggregates = Array(repeating: Aggregate(), count: variants.count)
            var holdoutAggregates = Array(repeating: Aggregate(), count: variants.count)
            var baselineValidation = Aggregate()
            var baselineHoldout = Aggregate()

            print("Split \(split + 1)/\(splitCount) – Validation ...")

            for index in validationStart..<validationEnd {
                let training = Array(draws.prefix(index))
                let target = draws[index]
                let tickets = makeVariantTickets(from: training, variants: variants)

                for variantIndex in variants.indices {
                    validationAggregates[variantIndex].add(ticket: tickets[variantIndex], target: target)
                }
                baselineValidation.add(ticket: tickets[0], target: target)
            }

            let selectedIndex = selectVariant(validation: validationAggregates, baseline: baselineValidation)

            print("Split \(split + 1)/\(splitCount) – Holdout ...")

            for index in validationEnd..<holdoutEnd {
                let training = Array(draws.prefix(index))
                let target = draws[index]
                let tickets = makeVariantTickets(from: training, variants: variants)
                holdoutAggregates[selectedIndex].add(ticket: tickets[selectedIndex], target: target)
                baselineHoldout.add(ticket: tickets[0], target: target)
            }

            splitResults.append(
                SplitResult(
                    variant: variants[selectedIndex].name,
                    validation: validationAggregates[selectedIndex],
                    holdout: holdoutAggregates[selectedIndex],
                    baselineValidation: baselineValidation,
                    baselineHoldout: baselineHoldout
                )
            )
        }

        printSplitResults(splitResults)
        printAggregateResults(splitResults)
        print("\nInterpretation:")
        print("F2 bleibt unverändert die Basis.")
        print("Features wirken nur als weiche Gewichtung und ersetzen F2 nicht durch harte Filter.")
        print("Die Gewichtung wird ausschließlich auf der Validation ausgewählt.")
        print("Der Holdout wird erst danach mit der ausgewählten Variante ausgewertet.")
        print(String(format: "⏱ F2-Soft-Feature-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeVariants() -> [Variant] {
        var variants = [Variant(name: "F2", mask: 0, weight: 0)]
        let singleBits = Array(0...6)

        for bit in singleBits {
            for weight in weights {
                let featureName = featureNames[bit] ?? "Feature"
                variants.append(
                    Variant(
                        name: "F2 + \(featureName) @ \(Int(weight * 100))%",
                        mask: 1 << bit,
                        weight: weight
                    )
                )
            }
        }

        for i in 0..<singleBits.count {
            for j in (i + 1)..<singleBits.count {
                let first = singleBits[i]
                let second = singleBits[j]
                let mask = (1 << first) | (1 << second)
                let firstName = featureNames[first] ?? "Feature"
                let secondName = featureNames[second] ?? "Feature"

                for weight in weights {
                    variants.append(
                        Variant(
                            name: "F2 + \(firstName) + \(secondName) @ \(Int(weight * 100))%",
                            mask: mask,
                            weight: weight
                        )
                    )
                }
            }
        }

        return variants
    }

    private func selectVariant(validation: [Aggregate], baseline: Aggregate) -> Int {
        var bestIndex = 0
        var bestScore = -Double.infinity

        for index in validation.indices {
            let delta = validation[index].delta - baseline.delta
            let score = delta - 0.15 * max(0, -delta)

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex
    }

    private func makeVariantTickets(from draws: [EuroJackpotDraw], variants: [Variant]) -> [Ticket] {
        let source = Array(draws.suffix(window))
        var main: [Int: Int] = [:]
        var euro: [Int: Int] = [:]

        for draw in source {
            for number in draw.numbers {
                main[number, default: 0] += 1
            }
            for number in draw.euroNumbers {
                euro[number, default: 0] += 1
            }
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

        let candidates = makeCandidates(rankedMain: rankedMain, frequencies: main)
        let bestByVariant = makeBestTickets(candidates: candidates, euroNumbers: euroNumbers, variants: variants)

        var result: [Ticket] = []
        result.reserveCapacity(variants.count)

        for variant in variants {
            if variant.mask == 0 {
                result.append(baseline)
            } else if let ticket = bestByVariant[variantKey(mask: variant.mask, weight: variant.weight)] {
                result.append(ticket)
            } else {
                result.append(baseline)
            }
        }

        return result
    }

    private func makeCandidates(rankedMain: [Int], frequencies: [Int: Int]) -> [Candidate] {
        let pool = Array(rankedMain.prefix(candidatePoolSize))
        guard pool.count >= 5 else { return [] }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(3003)

        for a in 0..<(pool.count - 4) {
            for b in (a + 1)..<(pool.count - 3) {
                for c in (b + 1)..<(pool.count - 2) {
                    for d in (c + 1)..<(pool.count - 1) {
                        for e in (d + 1)..<pool.count {
                            let numbers = [pool[a], pool[b], pool[c], pool[d], pool[e]].sorted()
                            let baseScore = Double(numbers.reduce(0) { $0 + frequencies[$1, default: 0] })
                            candidates.append(
                                Candidate(
                                    numbers: numbers,
                                    baseScore: baseScore,
                                    featureMask: featureMask(for: numbers)
                                )
                            )
                        }
                    }
                }
            }
        }

        return candidates
    }

    private func makeBestTickets(
        candidates: [Candidate],
        euroNumbers: [Int],
        variants: [Variant]
    ) -> [String: Ticket] {
        var best: [String: (numbers: [Int], score: Double)] = [:]
        best.reserveCapacity(max(1, variants.count - 1))

        for variant in variants where variant.mask != 0 {
            var bestNumbers: [Int]?
            var bestScore = -Double.infinity
            let requestedBits = variant.mask.nonzeroBitCount

            for candidate in candidates {
                let matchedMask = candidate.featureMask & variant.mask
                let matchedCount = matchedMask.nonzeroBitCount

                // Soft weighting: partial matches remain eligible.
                // Full matches receive the largest feature contribution.
                let normalizedMatch = Double(matchedCount) / Double(requestedBits)
                let score = candidate.baseScore * (1.0 + variant.weight * normalizedMatch)

                if score > bestScore {
                    bestScore = score
                    bestNumbers = candidate.numbers
                } else if score == bestScore,
                          let current = bestNumbers,
                          candidate.numbers.lexicographicallyPrecedes(current) {
                    bestNumbers = candidate.numbers
                }
            }

            if let bestNumbers {
                best[variantKey(mask: variant.mask, weight: variant.weight)] = (
                    bestNumbers,
                    bestScore
                )
            }
        }

        var result: [String: Ticket] = [:]
        result.reserveCapacity(best.count)

        for (key, value) in best {
            result[key] = Ticket(numbers: value.numbers, euroNumbers: euroNumbers)
        }

        return result
    }

    private func featureMask(for numbers: [Int]) -> Int {
        let sum = numbers.reduce(0, +)
        let even = numbers.filter { $0.isMultiple(of: 2) }.count
        let high = numbers.filter { $0 >= 26 }.count

        var adjacent = 0
        if numbers.count > 1 {
            for index in 1..<numbers.count where numbers[index] == numbers[index - 1] + 1 {
                adjacent += 1
            }
        }

        let spread = (numbers.max() ?? 0) - (numbers.min() ?? 0)
        var mask = 0

        if sum >= 100 && sum < 125 { mask |= 1 << 0 }
        if even == 2 { mask |= 1 << 1 }
        if high == 2 { mask |= 1 << 2 }
        if adjacent == 0 { mask |= 1 << 3 }
        if spread >= 20 && spread < 30 { mask |= 1 << 4 }
        if spread >= 30 && spread < 40 { mask |= 1 << 5 }
        if spread >= 40 { mask |= 1 << 6 }

        return mask
    }

    private func variantKey(mask: Int, weight: Double) -> String {
        "\(mask)|\(Int(weight * 100))"
    }

    private func printSplitResults(_ results: [SplitResult]) {
        print("\n## SOFT-FEATURE-SPLITS")
        print("Split | Gewinner | Val Δ ggü F2 | Hold Δ | F2 Hold Δ")

        for (index, result) in results.enumerated() {
            let valAdvantage = result.validation.delta - result.baselineValidation.delta
            print(
                String(
                    format: "%2d | %@ | %+.3f | %+.3f | %+.3f",
                    index + 1,
                    result.variant,
                    valAdvantage,
                    result.holdout.delta,
                    result.baselineHoldout.delta
                )
            )
        }
    }

    private func printAggregateResults(_ results: [SplitResult]) {
        guard !results.isEmpty else { return }

        var holdSum = 0.0
        var f2HoldSum = 0.0
        var selectedBetter = 0
        var f2Better = 0
        var variantCounts: [String: Int] = [:]

        for result in results {
            holdSum += result.holdout.delta
            f2HoldSum += result.baselineHoldout.delta
            variantCounts[result.variant, default: 0] += 1

            if result.holdout.delta > result.baselineHoldout.delta {
                selectedBetter += 1
            } else if result.holdout.delta < result.baselineHoldout.delta {
                f2Better += 1
            }
        }

        let selectedAverage = holdSum / Double(results.count)
        let f2Average = f2HoldSum / Double(results.count)

        print("\n## SOFT-FEATURE – GESAMT")
        print(String(format: "Gewählte Varianten Hold Δ : %+.3f", selectedAverage))
        print(String(format: "F2/50 Hold Δ              : %+.3f", f2Average))
        print(String(format: "Vorteil ggü. F2           : %+.3f", selectedAverage - f2Average))
        print("Gewählte Variante besser  : \(selectedBetter)/\(results.count)")
        print("F2 besser                 : \(f2Better)/\(results.count)")
        print("\n## GEWÄHLTE VARIANTEN")

        for item in variantCounts.sorted(by: { $0.value > $1.value }) {
            print("\(item.key) : \(item.value)/\(results.count)")
        }
    }
}
