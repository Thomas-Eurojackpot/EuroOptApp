import Foundation

/// Walk-forward research analyzer for combining the fixed F2/50 frequency signal
/// with longer historical frequency windows.
///
/// F2/50 remains the fixed reference. A frequency blend is only selected when
/// it shows support across multiple independent validation segments, reducing
/// the risk of choosing a variant because of one unusually good validation block.
final class FrequencyLearningAnalyzer {

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

        mutating func add(ticket: Ticket, target: EuroJackpotDraw) {
            hits += Set(ticket.numbers).intersection(target.numbers).count
            euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
            tickets += 1
            expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: 1)
        }

        mutating func merge(_ other: Aggregate) {
            hits += other.hits
            euroHits += other.euroHits
            tickets += other.tickets
            expectedEuroHits += other.expectedEuroHits
        }
    }

    private struct Variant: Hashable {
        let window: Int
        let weightPercent: Int
    }

    private struct ValidationEvidence {
        let meanAdvantage: Double
        let positiveSegments: Int
        let segmentCount: Int
        let minimumAdvantage: Double
    }

    private struct SplitResult {
        let split: Int
        let winner: Variant
        let evidence: ValidationEvidence
        let holdout: Aggregate
        let f2Holdout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let baseWindow = 50
    private let windows = [50, 100, 200, 400]
    private let weights = Array(stride(from: 10, through: 90, by: 10))
    private let validationSegments = 3

    func run(draws: [EuroJackpotDraw], splitCount: Int = 10) {
        guard draws.count > warmup + 20 else {
            print("❌ Frequency Blend Sweep: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - warmup
        let requestedSplits = max(1, min(splitCount, totalTests / 2))
        let availableWindow = totalTests / requestedSplits
        let variants = windows.flatMap { window in
            weights.map { Variant(window: window, weightPercent: $0) }
        }
        var results: [SplitResult] = []

        print("")
        print("===================================")
        print("📊 F2/50 → STABILER FREQUENZ-BLEND-SWEEP")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Splits              : \(requestedSplits)")
        print("Basis               : F2/50")
        print("Fenster             : \(windows.map(String.init).joined(separator: " / "))")
        print("Blend               : 10% ... 90% Frequenz")
        print("Validation-Segmente : \(validationSegments)")
        print("Auswahl             : Mittelwert + Stabilität, ausschließlich Validation")
        print("Holdout             : erst nach der Auswahl")
        print("")

        for split in 0..<requestedSplits {
            let splitStart = warmup + split * availableWindow
            let splitEnd = split == requestedSplits - 1
                ? draws.count
                : min(draws.count, warmup + (split + 1) * availableWindow)
            let splitSize = splitEnd - splitStart
            guard splitSize >= validationSegments + 1 else { continue }

            let validationEnd = splitStart + splitSize / 2
            let validationSize = validationEnd - splitStart
            let segmentSize = max(1, validationSize / validationSegments)

            var evidenceByVariant: [Variant: ValidationEvidence] = [:]

            for variant in variants {
                var advantages: [Double] = []

                for segment in 0..<validationSegments {
                    let segmentStart = splitStart + segment * segmentSize
                    let segmentEnd = segment == validationSegments - 1
                        ? validationEnd
                        : min(validationEnd, segmentStart + segmentSize)

                    guard segmentStart < segmentEnd else { continue }

                    var candidateAggregate = Aggregate()
                    var f2Aggregate = Aggregate()

                    for index in segmentStart..<segmentEnd {
                        let trainingDraws = Array(draws.prefix(index))
                        let target = draws[index]

                        candidateAggregate.add(
                            ticket: makeBlendTicket(from: trainingDraws, variant: variant),
                            target: target
                        )
                        f2Aggregate.add(
                            ticket: makeBlendTicket(
                                from: trainingDraws,
                                variant: Variant(window: baseWindow, weightPercent: 0)
                            ),
                            target: target
                        )
                    }

                    advantages.append(candidateAggregate.score - f2Aggregate.score)
                }

                guard !advantages.isEmpty else { continue }

                let mean = advantages.reduce(0, +) / Double(advantages.count)
                let positive = advantages.filter { $0 > 0 }.count
                let minimum = advantages.min() ?? 0

                evidenceByVariant[variant] = ValidationEvidence(
                    meanAdvantage: mean,
                    positiveSegments: positive,
                    segmentCount: advantages.count,
                    minimumAdvantage: minimum
                )
            }

            guard let winner = selectStableWinner(variants: variants, evidence: evidenceByVariant) else {
                continue
            }

            let evidence = evidenceByVariant[winner]!
            var winnerHoldout = Aggregate()
            var f2Holdout = Aggregate()

            for index in validationEnd..<splitEnd {
                let trainingDraws = Array(draws.prefix(index))
                let target = draws[index]

                winnerHoldout.add(
                    ticket: makeBlendTicket(from: trainingDraws, variant: winner),
                    target: target
                )
                f2Holdout.add(
                    ticket: makeBlendTicket(
                        from: trainingDraws,
                        variant: Variant(window: baseWindow, weightPercent: 0)
                    ),
                    target: target
                )
            }

            results.append(
                SplitResult(
                    split: split + 1,
                    winner: winner,
                    evidence: evidence,
                    holdout: winnerHoldout,
                    f2Holdout: f2Holdout
                )
            )

            print(String(
                format: "Split %2d | Gewinner: Freq%03d + %2d%% | Val Δ ggü F2 %+.3f | Pos %d/%d | Min %+.3f | Hold Δ %+.3f | F2 Hold Δ %+.3f",
                split + 1,
                winner.window,
                winner.weightPercent,
                evidence.meanAdvantage,
                evidence.positiveSegments,
                evidence.segmentCount,
                evidence.minimumAdvantage,
                winnerHoldout.score,
                f2Holdout.score
            ))
        }

        guard !results.isEmpty else { return }

        var totalSelected = Aggregate()
        var totalF2 = Aggregate()
        var selectedBetterSplits = 0
        var f2BetterSplits = 0
        var winnerCounts: [Variant: Int] = [:]

        for result in results {
            totalSelected.merge(result.holdout)
            totalF2.merge(result.f2Holdout)
            winnerCounts[result.winner, default: 0] += 1

            if result.holdout.score > result.f2Holdout.score {
                selectedBetterSplits += 1
            } else if result.f2Holdout.score > result.holdout.score {
                f2BetterSplits += 1
            }
        }

        print("")
        print("===================================")
        print("GESAMT: STABILITÄTS-GEWÄHLTER BLEND")
        print("===================================")
        print(String(format: "Gewählter Blend Hold Δ : %+.3f", totalSelected.score))
        print(String(format: "F2/50 Hold Δ           : %+.3f", totalF2.score))
        print(String(format: "Vorteil ggü. F2        : %+.3f", totalSelected.score - totalF2.score))
        print("Blend besser in Splits : \(selectedBetterSplits)/\(results.count)")
        print("F2 besser in Splits    : \(f2BetterSplits)/\(results.count)")
        print("")
        print("GEWÄHLTE VARIANTEN")
        print("-----------------------------------")

        for variant in variants {
            let count = winnerCounts[variant, default: 0]
            if count > 0 {
                print("Freq\(variant.window) + \(variant.weightPercent)% : \(count)/\(results.count)")
            }
        }

        print("")
        print("Interpretation:")
        print("Eine Variante muss in mindestens 2 von 3 Validation-Segmenten gegenüber F2 positiv sein.")
        print("Bei mehreren zulässigen Varianten entscheidet der höchste mittlere Vorteil gegenüber F2.")
        print("Bei Gleichstand entscheidet der höhere minimale Segmentvorteil.")
        print("Der Holdout wird erst nach der Validation-Auswahl ausgewertet.")
        print("F2/50 bleibt unverändert die Referenz.")
        print("")
        print(String(format: "⏱ Stabiler Frequenz-Blend-Sweep: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private func selectStableWinner(
        variants: [Variant],
        evidence: [Variant: ValidationEvidence]
    ) -> Variant? {
        let eligible = variants.filter { variant in
            guard let item = evidence[variant] else { return false }
            return item.positiveSegments >= 2
        }

        let pool = eligible.isEmpty ? variants.filter { evidence[$0] != nil } : eligible

        return pool.max { lhs, rhs in
            let left = evidence[lhs]!
            let right = evidence[rhs]!

            if left.meanAdvantage != right.meanAdvantage {
                return left.meanAdvantage < right.meanAdvantage
            }
            if left.positiveSegments != right.positiveSegments {
                return left.positiveSegments < right.positiveSegments
            }
            if left.minimumAdvantage != right.minimumAdvantage {
                return left.minimumAdvantage < right.minimumAdvantage
            }
            if lhs.weightPercent != rhs.weightPercent {
                return lhs.weightPercent > rhs.weightPercent
            }
            return lhs.window > rhs.window
        }
    }

    private func makeBlendTicket(from draws: [EuroJackpotDraw], variant: Variant) -> Ticket {
        let f2Source = Array(draws.suffix(baseWindow))
        let frequencySource = Array(draws.suffix(variant.window))
        let weight = Double(variant.weightPercent) / 100.0

        let main = blendRankedNumbers(
            baseDraws: f2Source,
            frequencyDraws: frequencySource,
            range: 1...50,
            limit: 5,
            isEuro: false,
            weight: weight
        )
        let euro = blendRankedNumbers(
            baseDraws: f2Source,
            frequencyDraws: frequencySource,
            range: 1...12,
            limit: 2,
            isEuro: true,
            weight: weight
        )

        return Ticket(numbers: main.sorted(), euroNumbers: euro.sorted())
    }

    private func blendRankedNumbers(
        baseDraws: [EuroJackpotDraw],
        frequencyDraws: [EuroJackpotDraw],
        range: ClosedRange<Int>,
        limit: Int,
        isEuro: Bool,
        weight: Double
    ) -> [Int] {
        let baseCounts = counts(in: baseDraws, range: range, isEuro: isEuro)
        let frequencyCounts = counts(in: frequencyDraws, range: range, isEuro: isEuro)

        let baseTotal = Double(max(1, baseDraws.count))
        let frequencyTotal = Double(max(1, frequencyDraws.count))
        let baseExpected = isEuro ? baseTotal * 2.0 / 12.0 : baseTotal * 5.0 / 50.0
        let frequencyExpected = isEuro ? frequencyTotal * 2.0 / 12.0 : frequencyTotal * 5.0 / 50.0

        let scored = range.map { number -> (Int, Double) in
            let baseRate = Double(baseCounts[number, default: 0]) / baseExpected
            let frequencyRate = Double(frequencyCounts[number, default: 0]) / frequencyExpected
            let score = (1.0 - weight) * baseRate + weight * frequencyRate
            return (number, score)
        }
        .sorted {
            if $0.1 == $1.1 { return $0.0 < $1.0 }
            return $0.1 > $1.1
        }

        return Array(scored.prefix(limit).map(\.0))
    }

    private func counts(
        in draws: [EuroJackpotDraw],
        range: ClosedRange<Int>,
        isEuro: Bool
    ) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for draw in draws {
            let values = isEuro ? draw.euroNumbers : draw.numbers
            for value in values where range.contains(value) {
                result[value, default: 0] += 1
            }
        }
        return result
    }
}
