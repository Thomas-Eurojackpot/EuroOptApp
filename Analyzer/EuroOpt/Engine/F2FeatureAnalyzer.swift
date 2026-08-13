import Foundation

/// Isolated F2/50 statistical significance analysis.
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

    private struct Variant { let name: String; let mode: Int }
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
        guard draws.count > warmup + 120 else { print("❌ F2-Significance-Test: zu wenige Ziehungen"); return }
        let start = Date()
        print("\n===================================")
        print("📊 F2/50 SIGNIFICANCE-FREQUENCY ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(window) Trainingsziehungen")
        print("Kandidatenpool      : Top \(candidatePoolSize) nach F2-Frequenz")
        print("Signale             : Frequenz / z-Score / Shrinkage / p-Wert")
        print("Auswahl             : ausschließlich Validation")
        print("Holdout             : erst nach der Auswahl")
        print("Splits              : \(splitCount) zeitlich getrennte Walk-Forward-Splits\n")

        let variants = [
            Variant(name: "F2 (Basis)", mode: 0),
            Variant(name: "F2 + zScore", mode: 1),
            Variant(name: "F2 + Shrinkage", mode: 2),
            Variant(name: "F2 + zScore + Shrinkage", mode: 3),
            Variant(name: "F2 + pValue", mode: 4)
        ]
        var results: [SplitResult] = []
        results.reserveCapacity(splitCount)

        for split in 0..<splitCount {
            let available = draws.count - warmup
            let block = available / splitCount
            let validationStart = warmup + split * block
            let validationEnd = split == splitCount - 1 ? warmup + Int(Double(available) * 0.92) : validationStart + max(8, block * 2 / 3)
            let holdoutEnd = split == splitCount - 1 ? draws.count : validationStart + block
            guard validationStart < validationEnd, validationEnd < holdoutEnd, holdoutEnd <= draws.count else { continue }

            var validation = Array(repeating: Aggregate(), count: variants.count)
            var holdout = Array(repeating: Aggregate(), count: variants.count)
            var baseVal = Aggregate()
            var baseHold = Aggregate()
            print("Split \(split + 1)/\(splitCount) – Validation ...")
            for index in validationStart..<validationEnd {
                let tickets = makeTickets(draws: draws, endIndex: index, variants: variants)
                for i in variants.indices { validation[i].add(ticket: tickets[i], target: draws[index]) }
                baseVal.add(ticket: tickets[0], target: draws[index])
            }
            let selected = select(validation: validation, baseline: baseVal)
            print("Split \(split + 1)/\(splitCount) – Holdout ...")
            for index in validationEnd..<holdoutEnd {
                let tickets = makeTickets(draws: draws, endIndex: index, variants: variants)
                holdout[selected].add(ticket: tickets[selected], target: draws[index])
                baseHold.add(ticket: tickets[0], target: draws[index])
            }
            results.append(SplitResult(variant: variants[selected].name, validation: validation[selected], holdout: holdout[selected], baselineValidation: baseVal, baselineHoldout: baseHold))
        }
        printResults(results)
        print("\nInterpretation:")
        print("F2/50 bleibt unverändert die Referenz.")
        print("Die Signifikanzvarianten verändern nur die Auswahl innerhalb des F2-Kandidatenpools.")
        print("Die Auswahl erfolgt ausschließlich über die Validation.")
        print("Der Holdout wird erst nach der Auswahl ausgewertet.")
        print(String(format: "⏱ F2/50 Significance-Frequency-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private func select(validation: [Aggregate], baseline: Aggregate) -> Int {
        var best = 0
        var score = 0.0
        for i in validation.indices {
            let d = validation[i].delta - baseline.delta
            let s = d - 0.15 * max(0, -d)
            if i == 0 || s > score { score = s; best = i }
        }
        return best
    }

    private func makeTickets(draws: [EuroJackpotDraw], endIndex: Int, variants: [Variant]) -> [Ticket] {
        let start = max(0, endIndex - window)
        let source = Array(draws[start..<endIndex])
        var counts = Array(repeating: 0, count: 51)
        for draw in source { for n in draw.numbers where n >= 1 && n <= 50 { counts[n] += 1 } }
        let ranked = (1...50).sorted { counts[$0] == counts[$1] ? $0 < $1 : counts[$0] > counts[$1] }
        let pool = Array(ranked.prefix(candidatePoolSize))
        let euroCounts = frequency(draws: source, euro: true)
        let euro = (1...12).sorted { euroCounts[$0, default: 0] == euroCounts[$1, default: 0] ? $0 < $1 : euroCounts[$0, default: 0] > euroCounts[$1, default: 0] }
        let euros = Array(euro.prefix(2)).sorted()
        guard pool.count >= 5 else { return variants.map { _ in Ticket(numbers: pool.sorted(), euroNumbers: euros) } }

        var z = Array(repeating: 0.0, count: 51)
        var shrunk = Array(repeating: 0.0, count: 51)
        var p = Array(repeating: 1.0, count: 51)
        let expected = Double(source.count) * 0.1
        let variance = max(1.0, expected * 0.9)
        for n in pool {
            z[n] = (Double(counts[n]) - expected) / sqrt(variance)
            shrunk[n] = (Double(counts[n]) + 10.0 * 0.1) / (Double(source.count) + 10.0)
            p[n] = upperTailPoisson(k: counts[n], lambda: expected)
        }

        var tickets: [Ticket] = []
        for variant in variants {
            let numbers = Array(pool.sorted {
                let a = score(counts: counts, z: z, shrunk: shrunk, p: p, n: $0, mode: variant.mode)
                let b = score(counts: counts, z: z, shrunk: shrunk, p: p, n: $1, mode: variant.mode)
                return a == b ? $0 < $1 : a > b
            }.prefix(5)).sorted()
            tickets.append(Ticket(numbers: numbers, euroNumbers: euros))
        }
        return tickets
    }

    private func score(counts: [Int], z: [Double], shrunk: [Double], p: [Double], n: Int, mode: Int) -> Double {
        switch mode {
        case 1: return Double(counts[n]) + max(0, z[n])
        case 2: return Double(counts[n]) + 5.0 * shrunk[n]
        case 3: return Double(counts[n]) + max(0, z[n]) + 5.0 * shrunk[n]
        case 4: return Double(counts[n]) - min(0.0, log10(max(p[n], 1e-12)))
        default: return Double(counts[n])
        }
    }

    private func frequency(draws: [EuroJackpotDraw], euro: Bool) -> [Int: Int] {
        var r: [Int: Int] = [:]
        for d in draws { for n in (euro ? d.euroNumbers : d.numbers) { r[n, default: 0] += 1 } }
        return r
    }

    private func upperTailPoisson(k: Int, lambda: Double) -> Double {
        if k <= 0 { return 1.0 }
        var term = exp(-lambda)
        var sum = term
        if k == 0 { return 1.0 }
        if k > 1 { for i in 1..<k { term *= lambda / Double(i); sum += term } }
        return min(1.0, max(0.0, 1.0 - sum))
    }

    private func printResults(_ results: [SplitResult]) {
        print("\n## SIGNIFICANCE-FREQUENCY-SPLITS")
        print("Split | Gewinner | Val Δ ggü F2 | Hold Δ | F2 Hold Δ")
        for (i, r) in results.enumerated() {
            let v = r.validation.delta - r.baselineValidation.delta
            print(String(format: "%2d | %@ | %+.3f | %+.3f | %+.3f", i + 1, r.variant, v, r.holdout.delta, r.baselineHoldout.delta))
        }
        let selected = results.reduce(0.0) { $0 + $1.holdout.delta } / Double(results.count)
        let f2 = results.reduce(0.0) { $0 + $1.baselineHoldout.delta } / Double(results.count)
        let better = results.filter { $0.holdout.delta > $0.baselineHoldout.delta }.count
        let worse = results.filter { $0.holdout.delta < $0.baselineHoldout.delta }.count
        print("\n## SIGNIFICANCE-FREQUENCY – GESAMT")
        print(String(format: "Gewählte Varianten Hold Δ : %+.3f", selected))
        print(String(format: "F2/50 Hold Δ              : %+.3f", f2))
        print(String(format: "Vorteil ggü. F2           : %+.3f", selected - f2))
        print("Gewählte Variante besser  : \(better)/\(results.count)")
        print("F2 besser                 : \(worse)/\(results.count)")
    }
}
