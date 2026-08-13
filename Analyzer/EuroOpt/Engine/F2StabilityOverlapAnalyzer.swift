import Foundation

/// Descriptive research analyzer for the relationship between F2 stability and pair strength.
/// No ticket selection is changed and no production logic is modified.
final class F2StabilityOverlapAnalyzer {
    private let warmup = 100
    private let f2Window = 50
    private let windows = [50, 100, 200, 400]
    private let topPool = 15
    private let splitCount = 10

    private struct PairKey: Hashable {
        let a: Int
        let b: Int
    }

    private struct PairMetric {
        let pair: PairKey
        let lift: Double
        let phi: Double
    }

    private struct Snapshot {
        let top15: [Int]
        let metricsByWindow: [Int: [PairKey: PairMetric]]
    }

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 20 else {
            print("❌ F2-Overlapanalyse: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let available = draws.count - warmup
        let block = max(1, available / splitCount)
        var snapshots: [Snapshot] = []

        print("\n===================================")
        print("🔗 F2-STABILITÄT ↔ PAARSTÄRKE OVERLAP")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(f2Window) Trainingsziehungen")
        print("Kandidatenpool      : Top \(topPool) nach F2-Frequenz")
        print("Paarstärke          : Lift + Phi")
        print("Fenster             : 50 / 100 / 200 / 400")
        print("Splits              : \(splitCount) zeitliche Snapshots")
        print("Auswahl             : keine")
        print("Produktionsprofil   : unverändert")
        print("Holdout             : nicht verwendet")

        for split in 0..<splitCount {
            let index = min(draws.count - 1, warmup + (split + 1) * block - 1)
            guard index >= warmup else { continue }
            let training = Array(draws[0...index])
            let top15 = f2TopNumbers(from: training)
            var metricsByWindow: [Int: [PairKey: PairMetric]] = [:]
            for window in windows {
                metricsByWindow[window] = pairMetrics(source: Array(training.suffix(window)), pool: top15)
            }
            snapshots.append(Snapshot(top15: top15, metricsByWindow: metricsByWindow))
        }

        guard !snapshots.isEmpty else { return }

        var appearances: [Int: Int] = [:]
        var rankValues: [Int: [Int]] = [:]
        for snapshot in snapshots {
            for (index, number) in snapshot.top15.enumerated() {
                appearances[number, default: 0] += 1
                rankValues[number, default: []].append(index + 1)
            }
        }

        let candidates = Set(snapshots.flatMap(\.top15))
        var stability: [Int: Double] = [:]
        for number in candidates {
            let values = rankValues[number, default: []]
            let appearanceRate = Double(appearances[number, default: 0]) / Double(snapshots.count)
            let meanRank = values.isEmpty ? Double(topPool) : Double(values.reduce(0, +)) / Double(values.count)
            let rankScore = 1.0 - ((meanRank - 1.0) / Double(max(1, topPool - 1)))
            stability[number] = 0.5 * appearanceRate + 0.5 * rankScore
        }

        var pairStrengthValues: [Int: [Double]] = [:]
        var positivePairCounts: [Int: Int] = [:]
        var totalPairCounts: [Int: Int] = [:]

        for snapshot in snapshots {
            for window in windows {
                guard let metrics = snapshot.metricsByWindow[window] else { continue }
                for metric in metrics.values {
                    guard metric.lift > 1.0 && metric.phi > 0 else { continue }
                    let excess = metric.lift - 1.0
                    pairStrengthValues[metric.pair.a, default: []].append(excess)
                    pairStrengthValues[metric.pair.b, default: []].append(excess)
                    positivePairCounts[metric.pair.a, default: 0] += 1
                    positivePairCounts[metric.pair.b, default: 0] += 1
                }
                for pair in metrics.keys {
                    totalPairCounts[pair.a, default: 0] += 1
                    totalPairCounts[pair.b, default: 0] += 1
                }
            }
        }

        var pairStrength: [Int: Double] = [:]
        for number in candidates {
            let values = pairStrengthValues[number, default: []]
            pairStrength[number] = values.isEmpty ? 0.0 : values.reduce(0, +) / Double(values.count)
        }

        let stableOrder = candidates.sorted {
            if stability[$0, default: 0] != stability[$1, default: 0] {
                return stability[$0, default: 0] > stability[$1, default: 0]
            }
            return $0 < $1
        }
        let pairOrder = candidates.sorted {
            if pairStrength[$0, default: 0] != pairStrength[$1, default: 0] {
                return pairStrength[$0, default: 0] > pairStrength[$1, default: 0]
            }
            return $0 < $1
        }

        print("\n## F2-STABILITÄT")
        print("Zahl | F2-Snapshots | Ø Rang | Stabilität")
        for number in stableOrder.prefix(topPool) {
            let ranks = rankValues[number, default: []]
            let meanRank = ranks.isEmpty ? 0.0 : Double(ranks.reduce(0, +)) / Double(ranks.count)
            print(String(format: "%2d | %2d/%d       | %6.2f | %.3f", number, appearances[number, default: 0], snapshots.count, meanRank, stability[number, default: 0]))
        }

        print("\n## PAARSTÄRKE JE F2-ZAHL")
        print("Zahl | Ø positive Lift-Überhöhung | positive Paare | Paarbeobachtungen")
        for number in pairOrder.prefix(topPool) {
            print(String(format: "%2d | %10.3f              | %3d          | %3d", number, pairStrength[number, default: 0], positivePairCounts[number, default: 0], totalPairCounts[number, default: 0]))
        }

        print("\n## OVERLAP")
        for k in [5, 10, 15] {
            let stableSet = Set(stableOrder.prefix(k))
            let pairSet = Set(pairOrder.prefix(k))
            let overlap = stableSet.intersection(pairSet).count
            let expected = Double(k * k) / Double(max(1, candidates.count))
            print(String(format: "Top%-2d F2-Stabilität ∩ Top%-2d Paarstärke : %d | Zufallserwartung %.2f | Δ %+.2f", k, k, overlap, expected, Double(overlap) - expected))
        }

        let rho = spearman(stableOrder, pairOrder, candidates: candidates)
        print(String(format: "\nSpearman ρ F2-Stabilität ↔ Paarstärke : %+.3f", rho))

        let stableTop5 = Set(stableOrder.prefix(5))
        let strongPairEndpoints = Set(pairOrder.prefix(5))
        print("Top-5 F2-Stabilität : \(stableTop5.sorted())")
        print("Top-5 Paarstärke   : \(strongPairEndpoints.sorted())")

        print("\nInterpretation:")
        print("Die Analyse prüft nur, ob F2-Stabilität und Paarstärke strukturell zusammenfallen.")
        print("Ein hoher Overlap oder positives Spearman-ρ bedeutet Zusammenhang, aber noch keinen kausalen Vorteil für F2.")
        print("Es wird kein Auswahlgewicht erzeugt und F2 bleibt unverändert.")
        print(String(format: "⏱ F2-Stabilität ↔ Paarstärke Overlap: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private func f2TopNumbers(from draws: [EuroJackpotDraw]) -> [Int] {
        let source = Array(draws.suffix(f2Window))
        var counts = Array(repeating: 0, count: 51)
        for draw in source {
            for number in draw.numbers where number >= 1 && number <= 50 { counts[number] += 1 }
        }
        return Array((1...50).sorted {
            if counts[$0] != counts[$1] { return counts[$0] > counts[$1] }
            return $0 < $1
        }.prefix(topPool))
    }

    private func pairMetrics(source: [EuroJackpotDraw], pool: [Int]) -> [PairKey: PairMetric] {
        guard !source.isEmpty else { return [:] }
        let poolSet = Set(pool)
        var individual: [Int: Int] = [:]
        var pairCounts: [PairKey: Int] = [:]

        for draw in source {
            let present = Set(draw.numbers).intersection(poolSet)
            for number in present { individual[number, default: 0] += 1 }
            let sorted = present.sorted()
            if sorted.count >= 2 {
                for i in 0..<(sorted.count - 1) {
                    for j in (i + 1)..<sorted.count {
                        let pair = PairKey(a: sorted[i], b: sorted[j])
                        pairCounts[pair, default: 0] += 1
                    }
                }
            }
        }

        let n = Double(source.count)
        var result: [PairKey: PairMetric] = [:]
        if pool.count >= 2 {
            for i in 0..<(pool.count - 1) {
                for j in (i + 1)..<pool.count {
                    let pair = PairKey(a: min(pool[i], pool[j]), b: max(pool[i], pool[j]))
                    let ca = Double(individual[pair.a, default: 0])
                    let cb = Double(individual[pair.b, default: 0])
                    let cab = Double(pairCounts[pair, default: 0])
                    let pA = ca / n
                    let pB = cb / n
                    let pAB = cab / n
                    let expected = pA * pB
                    let lift = expected > 0 ? pAB / expected : 0
                    let n11 = cab
                    let n10 = max(0, ca - cab)
                    let n01 = max(0, cb - cab)
                    let n00 = max(0, n - n11 - n10 - n01)
                    let denominator = sqrt(max(0, (n11 + n10) * (n01 + n00) * (n11 + n01) * (n10 + n00)))
                    let phi = denominator > 0 ? (n11 * n00 - n10 * n01) / denominator : 0
                    result[pair] = PairMetric(pair: pair, lift: lift, phi: phi)
                }
            }
        }
        return result
    }

    private func spearman(_ left: [Int], _ right: [Int], candidates: Set<Int>) -> Double {
        let leftRank = Dictionary(uniqueKeysWithValues: left.enumerated().map { ($1, $0 + 1) })
        let rightRank = Dictionary(uniqueKeysWithValues: right.enumerated().map { ($1, $0 + 1) })
        let values = candidates.sorted()
        guard values.count > 1 else { return 0 }
        let x = values.map { Double(leftRank[$0, default: values.count]) }
        let y = values.map { Double(rightRank[$0, default: values.count]) }
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        var numerator = 0.0
        var denomX = 0.0
        var denomY = 0.0
        for index in x.indices {
            let dx = x[index] - meanX
            let dy = y[index] - meanY
            numerator += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }
        let denominator = sqrt(denomX * denomY)
        return denominator > 0 ? numerator / denominator : 0
    }
}
