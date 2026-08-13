import Foundation

/// Descriptive research analyzer for the structure behind F2/50.
/// No ticket selection is changed and no production logic is modified.
final class F2CorrelationAnalyzer {
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
        let coOccurrences: Int
    }

    private struct Snapshot {
        let top15: [Int]
        let metricsByWindow: [Int: [PairKey: PairMetric]]
    }

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 20 else {
            print("❌ F2-Korrelationsanalyse: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let available = draws.count - warmup
        let block = max(1, available / splitCount)
        var snapshots: [Snapshot] = []

        print("\n===================================")
        print("🔗 F2/50 KORRELATIONS-ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(f2Window) Trainingsziehungen")
        print("Kandidatenpool      : Top \(topPool) nach F2-Frequenz")
        print("Korrelationsmaß     : Phi + Lift")
        print("Fenster             : 50 / 100 / 200 / 400")
        print("Splits              : \(splitCount) zeitliche Snapshots")
        print("Auswahl             : keine")
        print("Produktionsprofil   : unverändert")
        print("Holdout             : nicht zur Auswahl verwendet")

        for split in 0..<splitCount {
            let index = min(draws.count - 1, warmup + (split + 1) * block - 1)
            guard index >= warmup else { continue }

            let training = Array(draws[0...index])
            let top15 = f2TopNumbers(from: training)
            var metricsByWindow: [Int: [PairKey: PairMetric]] = [:]

            for window in windows {
                metricsByWindow[window] = pairMetrics(
                    source: Array(training.suffix(window)),
                    pool: top15
                )
            }

            snapshots.append(
                Snapshot(top15: top15, metricsByWindow: metricsByWindow)
            )
            print("Split \(split + 1)/\(splitCount) | Top15: \(top15.sorted())")
        }

        guard !snapshots.isEmpty else { return }

        print("\n## F2-TOP15 – HÄUFIGKEIT DER ZAHLEN")
        var appearances: [Int: Int] = [:]
        var ranks: [Int: [Int]] = [:]

        for snapshot in snapshots {
            for index in snapshot.top15.indices {
                let number = snapshot.top15[index]
                appearances[number, default: 0] += 1
                ranks[number, default: []].append(index + 1)
            }
        }

        let orderedNumbers = appearances.keys.sorted {
            let left = appearances[$0, default: 0]
            let right = appearances[$1, default: 0]
            if left != right { return left > right }
            return $0 < $1
        }

        for number in orderedNumbers {
            let values = ranks[number, default: []]
            let meanRank = values.isEmpty
                ? 0.0
                : Double(values.reduce(0, +)) / Double(values.count)
            print(
                String(
                    format: "%2d | in %2d/%d Snapshots | Ø Rang %.1f",
                    number,
                    appearances[number, default: 0],
                    snapshots.count,
                    meanRank
                )
            )
        }

        var summaries: [(PairKey, Double, Double, Int, Int)] = []
        var pairSet = Set<PairKey>()

        for snapshot in snapshots {
            for window in windows {
                if let keys = snapshot.metricsByWindow[window]?.keys {
                    for key in keys {
                        pairSet.insert(key)
                    }
                }
            }
        }

        for pair in pairSet {
            var lifts: [Double] = []
            var phis: [Double] = []
            var positive = 0
            var totalCo = 0

            for snapshot in snapshots {
                for window in windows {
                    guard let metric = snapshot.metricsByWindow[window]?[pair] else {
                        continue
                    }
                    lifts.append(metric.lift)
                    phis.append(metric.phi)
                    totalCo += metric.coOccurrences
                    if metric.lift > 1.0 {
                        positive += 1
                    }
                }
            }

            guard !lifts.isEmpty else { continue }
            let meanLift = lifts.reduce(0, +) / Double(lifts.count)
            let meanPhi = phis.reduce(0, +) / Double(phis.count)
            summaries.append((pair, meanLift, meanPhi, positive, totalCo))
        }

        let strongest = summaries.sorted {
            let leftDistance = abs($0.1 - 1.0)
            let rightDistance = abs($1.1 - 1.0)
            if leftDistance != rightDistance {
                return leftDistance > rightDistance
            }
            return $0.2 > $1.2
        }

        print("\n## STÄRKSTE F2-PAARZUSAMMENHÄNGE")
        print("Paar    | Ø Lift | Ø Phi  | Lift>1 | Beobachtete gemeinsame Treffer")
        for item in strongest.prefix(20) {
            print(
                String(
                    format: "%2d-%2d | %6.3f | %+.3f | %2d     | %d",
                    item.0.a,
                    item.0.b,
                    item.1,
                    item.2,
                    item.3,
                    item.4
                )
            )
        }

        let positivePairs = summaries.filter {
            $0.1 > 1.05 && $0.2 > 0.05
        }
        let negativePairs = summaries.filter {
            $0.1 < 0.95 && $0.2 < -0.05
        }

        print("\n## STABILITÄT")
        print("Positive Paare (Ø Lift > 1.05 und Ø Phi > +0.05): \(positivePairs.count)")
        print("Negative Paare (Ø Lift < 0.95 und Ø Phi < -0.05): \(negativePairs.count)")

        print("\n## TOP15-PAARSTABILITÄT JE SNAPSHOT")
        for index in snapshots.indices {
            let snapshot = snapshots[index]
            let metrics = snapshot.metricsByWindow[f2Window] ?? [:]
            let stable = metrics.values
                .filter { $0.lift > 1.05 && $0.phi > 0.05 }
                .sorted { $0.lift > $1.lift }
                .prefix(5)
                .map {
                    "\($0.pair.a)-\($0.pair.b) (L \(String(format: \"%.2f\", $0.lift)))"
                }
                .joined(separator: ", ")

            let text = stable.isEmpty
                ? "keine stabil positive Paarbeziehung im F2/50-Fenster"
                : stable
            print("Split \(index + 1): \(text)")
        }

        print("\nInterpretation:")
        print("Die Analyse verändert F2 nicht.")
        print("Lift > 1 bedeutet gemeinsames Auftreten häufiger als unter Unabhängigkeit erwartet.")
        print("Phi > 0 bedeutet positive Abhängigkeit der beiden Zahlen.")
        print("Ein Muster gilt erst dann als interessant, wenn es über mehrere Fenster und zeitliche Snapshots stabil bleibt.")
        print("Diese Analyse erzeugt noch kein neues Auswahlgewicht.")
        print(String(format: "⏱ F2/50 Korrelationsanalyse: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private func f2TopNumbers(from draws: [EuroJackpotDraw]) -> [Int] {
        let source = Array(draws.suffix(f2Window))
        var counts = Array(repeating: 0, count: 51)

        for draw in source {
            for number in draw.numbers where number >= 1 && number <= 50 {
                counts[number] += 1
            }
        }

        return Array(
            (1...50).sorted {
                if counts[$0] != counts[$1] {
                    return counts[$0] > counts[$1]
                }
                return $0 < $1
            }.prefix(topPool)
        )
    }

    private func pairMetrics(
        source: [EuroJackpotDraw],
        pool: [Int]
    ) -> [PairKey: PairMetric] {
        guard !source.isEmpty else { return [:] }

        let poolSet = Set(pool)
        var individual: [Int: Int] = [:]
        var pairCounts: [PairKey: Int] = [:]

        for draw in source {
            let present = Set(draw.numbers).intersection(poolSet)
            for number in present {
                individual[number, default: 0] += 1
            }

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
                    let a = pool[i]
                    let b = pool[j]
                    let pair = PairKey(a: min(a, b), b: max(a, b))

                    let ca = Double(individual[a, default: 0])
                    let cb = Double(individual[b, default: 0])
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
                    let denominator = sqrt(
                        max(
                            0,
                            (n11 + n10) *
                            (n01 + n00) *
                            (n11 + n01) *
                            (n10 + n00)
                        )
                    )
                    let phi = denominator > 0
                        ? (n11 * n00 - n10 * n01) / denominator
                        : 0

                    result[pair] = PairMetric(
                        pair: pair,
                        lift: lift,
                        phi: phi,
                        coOccurrences: Int(cab)
                    )
                }
            }
        }

        return result
    }
}
