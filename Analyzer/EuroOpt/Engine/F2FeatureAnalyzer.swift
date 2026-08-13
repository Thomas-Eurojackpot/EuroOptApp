import Foundation

/// F2 feature analysis and validation-only feature-conditioned variants.
/// F2 itself is never changed. Every variant is selected on validation only,
/// then evaluated unchanged on the subsequent holdout.
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
    private struct Variant { let name: String; let rules: [Rule] }
    private enum Rule { case sum(Int); case even(Int); case high(Int); case consecutive(Int); case spread(Int) }
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

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 120 else { print("❌ F2-Feature-Test: zu wenige Ziehungen"); return }
        let start = Date()
        print("\n===================================")
        print("🔎 F2/50 FEATURE-KOMBINATIONSANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(window) Trainingsziehungen")
        print("Kandidatenpool      : Top \(candidatePoolSize) Hauptzahlen nach F2-Frequenz")
        print("Varianten            : F2 + einzelne Features + Feature-Kombinationen")
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
            let validationEnd = split == splitCount - 1 ? warmup + Int(Double(available) * 0.92) : validationStart + max(8, block * 2 / 3)
            let holdoutEnd = split == splitCount - 1 ? draws.count : validationStart + block
            guard validationStart >= warmup, validationStart < validationEnd, validationEnd < holdoutEnd, holdoutEnd <= draws.count else { continue }

            var validationAggregates = Array(repeating: Aggregate(), count: variants.count)
            var holdoutAggregates = Array(repeating: Aggregate(), count: variants.count)
            var baselineValidation = Aggregate()
            var baselineHoldout = Aggregate()

            for index in validationStart..<validationEnd {
                let training = Array(draws.prefix(index))
                let target = draws[index]
                let tickets = makeVariantTickets(from: training, variants: variants)
                for variantIndex in variants.indices { validationAggregates[variantIndex].add(ticket: tickets[variantIndex], target: target) }
                baselineValidation.add(ticket: makeF2Ticket(from: training), target: target)
            }

            let selectedIndex = selectVariant(validation: validationAggregates, baseline: baselineValidation)

            for index in validationEnd..<holdoutEnd {
                let training = Array(draws.prefix(index))
                let target = draws[index]
                let tickets = makeVariantTickets(from: training, variants: variants)
                holdoutAggregates[selectedIndex].add(ticket: tickets[selectedIndex], target: target)
                baselineHoldout.add(ticket: makeF2Ticket(from: training), target: target)
            }

            splitResults.append(SplitResult(variant: variants[selectedIndex].name, validation: validationAggregates[selectedIndex], holdout: holdoutAggregates[selectedIndex], baselineValidation: baselineValidation, baselineHoldout: baselineHoldout))
        }

        printSplitResults(splitResults)
        printAggregateResults(splitResults)
        print("\nInterpretation:")
        print("F2 bleibt unverändert die Basis.")
        print("Feature-Varianten werden ausschließlich auf der jeweiligen Validation ausgewählt.")
        print("Der Holdout wird erst danach mit derselben ausgewählten Variante ausgewertet.")
        print("Eine gute Variante muss wiederholt gegen F2 bestehen; einzelne starke Holdout-Splits reichen nicht aus.")
        print(String(format: "⏱ F2-Feature-Kombinationsanalyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeVariants() -> [Variant] {
        var variants: [Variant] = [Variant(name: "F2", rules: [])]
        let singles: [(String, Rule)] = [
            ("Sum100–124", .sum(1)), ("Even2", .even(2)), ("High2", .high(2)),
            ("Adj0", .consecutive(0)), ("Spread20–29", .spread(1)),
            ("Spread30–39", .spread(2)), ("Spread40+", .spread(3))
        ]
        for item in singles { variants.append(Variant(name: "F2 + \(item.0)", rules: [item.1])) }
        for i in 0..<singles.count {
            for j in (i + 1)..<singles.count {
                variants.append(Variant(name: "F2 + \(singles[i].0) + \(singles[j].0)", rules: [singles[i].1, singles[j].1]))
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
            if score > bestScore { bestScore = score; bestIndex = index }
        }
        return bestIndex
    }

    private func makeVariantTickets(from draws: [EuroJackpotDraw], variants: [Variant]) -> [Ticket] {
        let source = Array(draws.suffix(window))
        var main: [Int: Int] = [:]
        var euro: [Int: Int] = [:]
        for draw in source {
            for number in draw.numbers { main[number, default: 0] += 1 }
            for number in draw.euroNumbers { euro[number, default: 0] += 1 }
        }
        let rankedMain = (1...50).sorted { main[$0, default: 0] == main[$1, default: 0] ? $0 < $1 : main[$0, default: 0] > main[$1, default: 0] }
        let rankedEuro = (1...12).sorted { euro[$0, default: 0] == euro[$1, default: 0] ? $0 < $1 : euro[$0, default: 0] > euro[$1, default: 0] }
        let baseline = Ticket(numbers: Array(rankedMain.prefix(5)).sorted(), euroNumbers: Array(rankedEuro.prefix(2)).sorted())
        var result: [Ticket] = []
        result.reserveCapacity(variants.count)
        for variant in variants {
            if variant.rules.isEmpty { result.append(baseline) }
            else { result.append(bestTicket(rankedMain: rankedMain, rankedEuro: rankedEuro, frequencies: main, rules: variant.rules, fallback: baseline)) }
        }
        return result
    }

    private func bestTicket(rankedMain: [Int], rankedEuro: [Int], frequencies: [Int: Int], rules: [Rule], fallback: Ticket) -> Ticket {
        let pool = Array(rankedMain.prefix(candidatePoolSize))
        var best: ([Int], Double)?
        if pool.count >= 5 {
            for a in 0..<(pool.count - 4) {
                for b in (a + 1)..<(pool.count - 3) {
                    for c in (b + 1)..<(pool.count - 2) {
                        for d in (c + 1)..<(pool.count - 1) {
                            for e in (d + 1)..<pool.count {
                                let numbers = [pool[a], pool[b], pool[c], pool[d], pool[e]].sorted()
                                guard matches(numbers: numbers, rules: rules) else { continue }
                                let score = Double(numbers.reduce(0) { $0 + frequencies[$1, default: 0] })
                                if best == nil || score > best!.1 || (score == best!.1 && numbers.lexicographicallyPrecedes(best!.0)) { best = (numbers, score) }
                            }
                        }
                    }
                }
            }
        }
        guard let best else { return fallback }
        return Ticket(numbers: best.0, euroNumbers: Array(rankedEuro.prefix(2)).sorted())
    }

    private func matches(numbers: [Int], rules: [Rule]) -> Bool {
        let sum = numbers.reduce(0, +)
        let even = numbers.filter { $0.isMultiple(of: 2) }.count
        let high = numbers.filter { $0 >= 26 }.count
        var adjacent = 0
        if numbers.count > 1 { for index in 1..<numbers.count where numbers[index] == numbers[index - 1] + 1 { adjacent += 1 } }
        let spread = (numbers.max() ?? 0) - (numbers.min() ?? 0)
        for rule in rules {
            switch rule {
            case .sum(let bucket): if !matchesSum(sum, bucket: bucket) { return false }
            case .even(let value): if even != value { return false }
            case .high(let value): if high != value { return false }
            case .consecutive(let value): if adjacent != value { return false }
            case .spread(let bucket): if !matchesSpread(spread, bucket: bucket) { return false }
            }
        }
        return true
    }

    private func matchesSum(_ sum: Int, bucket: Int) -> Bool {
        switch bucket { case 0: return sum < 100; case 1: return sum >= 100 && sum < 125; case 2: return sum >= 125 && sum < 150; default: return sum >= 150 }
    }

    private func matchesSpread(_ spread: Int, bucket: Int) -> Bool {
        switch bucket { case 0: return spread < 20; case 1: return spread >= 20 && spread < 30; case 2: return spread >= 30 && spread < 40; default: return spread >= 40 }
    }

    private func makeF2Ticket(from draws: [EuroJackpotDraw]) -> Ticket {
        let source = Array(draws.suffix(window))
        var main: [Int: Int] = [:]
        var euro: [Int: Int] = [:]
        for draw in source {
            for number in draw.numbers { main[number, default: 0] += 1 }
            for number in draw.euroNumbers { euro[number, default: 0] += 1 }
        }
        return Ticket(
            numbers: Array((1...50).sorted { main[$0, default: 0] == main[$1, default: 0] ? $0 < $1 : main[$0, default: 0] > main[$1, default: 0] }.prefix(5)).sorted(),
            euroNumbers: Array((1...12).sorted { euro[$0, default: 0] == euro[$1, default: 0] ? $0 < $1 : euro[$0, default: 0] > euro[$1, default: 0] }.prefix(2)).sorted()
        )
    }

    private func printSplitResults(_ results: [SplitResult]) {
        print("\n## FEATURE-SPLITS")
        print("Split | Gewinner | Val Δ ggü F2 | Hold Δ | F2 Hold Δ")
        for (index, result) in results.enumerated() {
            let valAdvantage = result.validation.delta - result.baselineValidation.delta
            print(String(format: "%2d | %@ | %+.3f | %+.3f | %+.3f", index + 1, result.variant, valAdvantage, result.holdout.delta, result.baselineHoldout.delta))
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
            if result.holdout.delta > result.baselineHoldout.delta { selectedBetter += 1 }
            else if result.holdout.delta < result.baselineHoldout.delta { f2Better += 1 }
        }
        let selectedAverage = holdSum / Double(results.count)
        let f2Average = f2HoldSum / Double(results.count)
        print("\n## FEATURE-KOMBINATIONEN – GESAMT")
        print(String(format: "Gewählte Varianten Hold Δ : %+.3f", selectedAverage))
        print(String(format: "F2/50 Hold Δ              : %+.3f", f2Average))
        print(String(format: "Vorteil ggü. F2           : %+.3f", selectedAverage - f2Average))
        print("Gewählte Variante besser  : \(selectedBetter)/\(results.count)")
        print("F2 besser                 : \(f2Better)/\(results.count)")
        print("\n## GEWÄHLTE VARIANTEN")
        for item in variantCounts.sorted(by: { $0.value > $1.value }) { print("\(item.key) : \(item.value)/\(results.count)") }
    }
}
