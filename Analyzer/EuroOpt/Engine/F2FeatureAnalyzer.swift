import Foundation

/// Isolated F2/50 combination-selection analysis.
/// Production Alpha/F2 is never modified by this analyzer.
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
        mutating func add(_ ticket: Ticket, _ target: EuroJackpotDraw) {
            hits += Set(ticket.numbers).intersection(Set(target.numbers)).count
            euroHits += Set(ticket.euroNumbers).intersection(Set(target.euroNumbers)).count
            tickets += 1
            expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: 1)
        }
    }

    private enum Mode: String, CaseIterable {
        case f2 = "F2 (Top5 Frequenz)"
        case pair = "F2 + Pair-Synergy"
        case conditional = "F2 + Conditional-Synergy"
        case robust = "F2 + Robust-Combination"
    }

    private struct SplitResult {
        let mode: Mode
        let validation: Aggregate
        let holdout: Aggregate
        let baseValidation: Aggregate
        let baseHoldout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let window = 50
    private let splitCount = 10
    private let poolSize = 15

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 120 else {
            print("❌ F2-Combination-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let modes = Mode.allCases
        print("\n===================================")
        print("🧮 F2/50 COMBINATION-SELECTION ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(window) Trainingsziehungen")
        print("Kandidatenpool      : Top \(poolSize) Hauptzahlen nach F2-Frequenz")
        print("Varianten            : Top5 / Pair-Synergy / Conditional-Synergy / Robust-Combination")
        print("Auswahl             : ausschließlich Validation")
        print("Holdout             : erst nach der Auswahl")
        print("Splits               : \(splitCount) zeitlich getrennte Walk-Forward-Splits\n")

        var results: [SplitResult] = []
        results.reserveCapacity(splitCount)

        for split in 0..<splitCount {
            let available = draws.count - warmup
            let block = available / splitCount
            let validationStart = warmup + split * block
            let validationEnd = split == splitCount - 1 ? warmup + Int(Double(available) * 0.92) : validationStart + max(8, block * 2 / 3)
            let holdoutEnd = split == splitCount - 1 ? draws.count : validationStart + block
            guard validationStart < validationEnd, validationEnd < holdoutEnd, holdoutEnd <= draws.count else { continue }

            var val = Array(repeating: Aggregate(), count: modes.count)
            var hold = Array(repeating: Aggregate(), count: modes.count)
            var baseVal = Aggregate()
            var baseHold = Aggregate()

            print("Split \(split + 1)/\(splitCount) – Validation ...")
            for i in validationStart..<validationEnd {
                let tickets = makeTickets(draws: draws, endIndex: i, modes: modes)
                for m in modes.indices { val[m].add(tickets[m], draws[i]) }
                baseVal.add(tickets[0], draws[i])
            }

            let selected = select(validation: val, baseline: baseVal)
            print("Split \(split + 1)/\(splitCount) – Holdout ...")
            for i in validationEnd..<holdoutEnd {
                let tickets = makeTickets(draws: draws, endIndex: i, modes: modes)
                hold[selected].add(tickets[selected], draws[i])
                baseHold.add(tickets[0], draws[i])
            }

            results.append(SplitResult(mode: modes[selected], validation: val[selected], holdout: hold[selected], baseValidation: baseVal, baseHoldout: baseHold))
        }

        printResults(results)
        print(String(format: "\n⏱ F2/50 Combination-Selection-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private func select(validation: [Aggregate], baseline: Aggregate) -> Int {
        var best = 0
        var bestScore = -Double.infinity
        for i in validation.indices {
            let d = validation[i].delta - baseline.delta
            let penalty = i == 0 ? 0.0 : 0.01
            let score = d - penalty - 0.15 * max(0, -d)
            if score > bestScore { bestScore = score; best = i }
        }
        return best
    }

    private func makeTickets(draws: [EuroJackpotDraw], endIndex: Int, modes: [Mode]) -> [Ticket] {
        let start = max(0, endIndex - window)
        let source = Array(draws[start..<endIndex])
        let mainCounts = mainFrequency(source)
        let euroCounts = euroFrequency(source)
        let pool = Array((1...50).sorted {
            mainCounts[$0, default: 0] == mainCounts[$1, default: 0] ? $0 < $1 : mainCounts[$0, default: 0] > mainCounts[$1, default: 0]
        }.prefix(poolSize))
        let euro = Array((1...12).sorted {
            euroCounts[$0, default: 0] == euroCounts[$1, default: 0] ? $0 < $1 : euroCounts[$0, default: 0] > euroCounts[$1, default: 0]
        }.prefix(2)).sorted()

        let pair = pairCounts(source)
        let conditional = conditionalScores(source: source, pool: pool, counts: mainCounts)
        let candidates = combinations(pool)

        return modes.map { mode in
            let chosen: [Int]
            switch mode {
            case .f2:
                chosen = Array(pool.prefix(5)).sorted()
            case .pair:
                chosen = bestCombination(candidates, counts: mainCounts, pair: pair, conditional: conditional, mode: .pair)
            case .conditional:
                chosen = bestCombination(candidates, counts: mainCounts, pair: pair, conditional: conditional, mode: .conditional)
            case .robust:
                chosen = bestCombination(candidates, counts: mainCounts, pair: pair, conditional: conditional, mode: .robust)
            }
            return Ticket(numbers: chosen, euroNumbers: euro)
        }
    }

    private enum CombinationMode { case pair, conditional, robust }

    private func bestCombination(_ candidates: [[Int]], counts: [Int: Int], pair: [Int: Int], conditional: [Int: Double], mode: CombinationMode) -> [Int] {
        var best = candidates[0]
        var bestScore = -Double.infinity
        for c in candidates {
            var score = c.reduce(0.0) { $0 + Double(counts[$1, default: 0]) }
            var pairSum = 0.0
            var pairCount = 0
            for i in 0..<c.count {
                for j in (i + 1)..<c.count {
                    pairSum += Double(pair[c[i] * 51 + c[j], default: 0])
                    pairCount += 1
                }
            }
            let pairRate = pairCount > 0 ? pairSum / Double(pairCount) : 0
            let cond = c.reduce(0.0) { $0 + conditional[$1, default: 0] }
            switch mode {
            case .pair:
                score += 0.20 * pairRate
            case .conditional:
                score += 0.20 * cond
            case .robust:
                score += 0.10 * pairRate + 0.10 * cond
                score -= 0.02 * abs(Double(c.max()! - c.min()!) - 28.0)
            }
            if score > bestScore || (score == bestScore && c.lexicographicallyPrecedes(best)) {
                bestScore = score
                best = c
            }
        }
        return best.sorted()
    }

    private func mainFrequency(_ draws: [EuroJackpotDraw]) -> [Int: Int] {
        var r: [Int: Int] = [:]
        for d in draws { for n in d.numbers { r[n, default: 0] += 1 } }
        return r
    }

    private func euroFrequency(_ draws: [EuroJackpotDraw]) -> [Int: Int] {
        var r: [Int: Int] = [:]
        for d in draws { for n in d.euroNumbers { r[n, default: 0] += 1 } }
        return r
    }

    private func pairCounts(_ draws: [EuroJackpotDraw]) -> [Int: Int] {
        var r: [Int: Int] = [:]
        for d in draws {
            let ns = d.numbers.sorted()
            for i in 0..<ns.count {
                for j in (i + 1)..<ns.count {
                    r[ns[i] * 51 + ns[j], default: 0] += 1
                }
            }
        }
        return r
    }

    private func conditionalScores(source: [EuroJackpotDraw], pool: [Int], counts: [Int: Int]) -> [Int: Double] {
        let pair = pairCounts(source)
        var r: [Int: Double] = [:]
        for n in pool {
            var total = 0.0
            for other in pool where other != n {
                let key = min(n, other) * 51 + max(n, other)
                let joint = Double(pair[key, default: 0])
                let marginal = Double(max(1, counts[other, default: 0]))
                total += joint / marginal
            }
            r[n] = total / Double(max(1, pool.count - 1))
        }
        return r
    }

    private func combinations(_ pool: [Int]) -> [[Int]] {
        var result: [[Int]] = []
        result.reserveCapacity(3003)
        guard pool.count >= 5 else { return [pool] }
        for a in 0..<(pool.count - 4) {
            for b in (a + 1)..<(pool.count - 3) {
                for c in (b + 1)..<(pool.count - 2) {
                    for d in (c + 1)..<(pool.count - 1) {
                        for e in (d + 1)..<pool.count {
                            result.append([pool[a], pool[b], pool[c], pool[d], pool[e]].sorted())
                        }
                    }
                }
            }
        }
        return result
    }

    private func printResults(_ results: [SplitResult]) {
        print("\n## COMBINATION-SELECTION-SPLITS")
        print("Split | Gewinner | Val Δ ggü F2 | Hold Δ | F2 Hold Δ")
        for (i, r) in results.enumerated() {
            let v = r.validation.delta - r.baseValidation.delta
            print(String(format: "%2d | %@ | %+.3f | %+.3f | %+.3f", i + 1, r.mode.rawValue, v, r.holdout.delta, r.baseHoldout.delta))
        }
        guard !results.isEmpty else { return }
        let selected = results.reduce(0.0) { $0 + $1.holdout.delta } / Double(results.count)
        let f2 = results.reduce(0.0) { $0 + $1.baseHoldout.delta } / Double(results.count)
        let better = results.filter { $0.holdout.delta > $0.baseHoldout.delta }.count
        let worse = results.filter { $0.holdout.delta < $0.baseHoldout.delta }.count
        let equal = results.count - better - worse
        print("\n## COMBINATION-SELECTION – GESAMT")
        print(String(format: "Gewählte Varianten Hold Δ : %+.3f", selected))
        print(String(format: "F2/50 Hold Δ              : %+.3f", f2))
        print(String(format: "Vorteil ggü. F2           : %+.3f", selected - f2))
        print("Gewählte Variante besser  : \(better)/\(results.count)")
        print("F2 besser                 : \(worse)/\(results.count)")
        print("Gleichstand               : \(equal)/\(results.count)")
    }
}
