import Foundation

/// Walk-forward research analyzer for robust frequency signals.
///
/// F2/50 remains the fixed reference. Instead of selecting one frequency
/// window, this analyzer tests whether a number's frequency signal is stable
/// across several windows and whether that consensus adds information to F2.
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

    private enum Signal: String, CaseIterable {
        case meanRate = "MW-Rate"
        case rankConsensus = "MW-Rank"
        case persistence = "MW-Persist"
    }

    private struct Variant: Hashable {
        let signal: Signal
        let blendPercent: Int
    }

    private struct Evidence {
        let meanAdvantage: Double
        let positiveSegments: Int
        let segmentCount: Int
        let minimumAdvantage: Double
    }

    private struct SplitResult {
        let split: Int
        let winner: Variant
        let evidence: Evidence
        let holdout: Aggregate
        let f2Holdout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let baseWindow = 50
    private let windows = [50, 100, 200, 400]
    private let blendPercents = [25, 50, 75]
    private let validationSegments = 3

    func run(draws: [EuroJackpotDraw], splitCount: Int = 10) {
        guard draws.count > warmup + 20 else {
            print("❌ Frequency Consensus: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - warmup
        let requestedSplits = max(1, min(splitCount, totalTests / 2))
        let availableWindow = totalTests / requestedSplits
        let variants = Signal.allCases.flatMap { signal in
            blendPercents.map { Variant(signal: signal, blendPercent: $0) }
        }
        var results: [SplitResult] = []

        print("")
        print("===================================")
        print("📊 F2/50 → MULTI-WINDOW FREQUENCY CONSENSUS")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Splits              : \(requestedSplits)")
        print("Basis               : F2/50")
        print("Fenster             : 50 / 100 / 200 / 400")
        print("Signale             : Rate / Rang-Konsens / Persistenz")
        print("F2-Blends            : 25% / 50% / 75%")
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
            var evidenceByVariant: [Variant: Evidence] = [:]

            for variant in variants {
                var advantages: [Double] = []

                for segment in 0..<validationSegments {
                    let segmentStart = splitStart + segment * segmentSize
                    let segmentEnd = segment == validationSegments - 1
                        ? validationEnd
                        : min(validationEnd, segmentStart + segmentSize)
                    guard segmentStart < segmentEnd else { continue }

                    var candidate = Aggregate()
                    var f2 = Aggregate()

                    for index in segmentStart..<segmentEnd {
                        let training = Array(draws.prefix(index))
                        let target = draws[index]
                        candidate.add(ticket: makeTicket(from: training, variant: variant), target: target)
                        f2.add(ticket: makeF2Ticket(from: training), target: target)
                    }

                    advantages.append(candidate.score - f2.score)
                }

                guard !advantages.isEmpty else { continue }
                evidenceByVariant[variant] = Evidence(
                    meanAdvantage: advantages.reduce(0, +) / Double(advantages.count),
                    positiveSegments: advantages.filter { $0 > 0 }.count,
                    segmentCount: advantages.count,
                    minimumAdvantage: advantages.min() ?? 0
                )
            }

            guard let winner = selectWinner(variants: variants, evidence: evidenceByVariant) else { continue }
            let evidence = evidenceByVariant[winner]!
            var holdout = Aggregate()
            var f2Holdout = Aggregate()

            for index in validationEnd..<splitEnd {
                let training = Array(draws.prefix(index))
                let target = draws[index]
                holdout.add(ticket: makeTicket(from: training, variant: winner), target: target)
                f2Holdout.add(ticket: makeF2Ticket(from: training), target: target)
            }

            results.append(SplitResult(split: split + 1, winner: winner, evidence: evidence, holdout: holdout, f2Holdout: f2Holdout))

            print(String(
                format: "Split %2d | Gewinner: %@ + %2d%% | Val Δ ggü F2 %+.3f | Pos %d/%d | Min %+.3f | Hold Δ %+.3f | F2 Hold Δ %+.3f",
                split + 1,
                winner.signal.rawValue,
                winner.blendPercent,
                evidence.meanAdvantage,
                evidence.positiveSegments,
                evidence.segmentCount,
                evidence.minimumAdvantage,
                holdout.score,
                f2Holdout.score
            ))
        }

        guard !results.isEmpty else { return }

        var selected = Aggregate()
        var f2 = Aggregate()
        var selectedBetter = 0
        var f2Better = 0
        var counts: [Variant: Int] = [:]

        for result in results {
            selected.merge(result.holdout)
            f2.merge(result.f2Holdout)
            counts[result.winner, default: 0] += 1
            if result.holdout.score > result.f2Holdout.score { selectedBetter += 1 }
            if result.f2Holdout.score > result.holdout.score { f2Better += 1 }
        }

        print("")
        print("===================================")
        print("GESAMT: MULTI-WINDOW KONSENSUS")
        print("===================================")
        print(String(format: "Konsens-Blend Hold Δ   : %+.3f", selected.score))
        print(String(format: "F2/50 Hold Δ           : %+.3f", f2.score))
        print(String(format: "Vorteil ggü. F2        : %+.3f", selected.score - f2.score))
        print("Konsens besser Splits  : \(selectedBetter)/\(results.count)")
        print("F2 besser Splits       : \(f2Better)/\(results.count)")
        print("")
        print("GEWÄHLTE VARIANTEN")
        print("-----------------------------------")
        for variant in variants where counts[variant, default: 0] > 0 {
            print("\(variant.signal.rawValue) + \(variant.blendPercent)% : \(counts[variant, default: 0])/\(results.count)")
        }
        print("")
        print("Die Frequenz wird nicht mehr aus einem einzelnen Fenster bestimmt.")
        print("MW-Rate: gemittelte normierte Häufigkeit über 50/100/200/400.")
        print("MW-Rank: Konsens des Häufigkeitsrangs über alle vier Fenster.")
        print("MW-Persist: Anteil der Fenster, in denen die Zahl über Erwartung liegt.")
        print("Der Holdout wird erst nach der Validation-Auswahl ausgewertet.")
        print("F2/50 bleibt unverändert die Referenz.")
        print("")
        print(String(format: "⏱ Multi-Window Frequency Consensus: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private func selectWinner(variants: [Variant], evidence: [Variant: Evidence]) -> Variant? {
        let eligible = variants.filter { variant in
            guard let e = evidence[variant] else { return false }
            return e.positiveSegments >= 2
        }
        let pool = eligible.isEmpty ? variants.filter { evidence[$0] != nil } : eligible

        return pool.max { lhs, rhs in
            let a = evidence[lhs]!
            let b = evidence[rhs]!
            if a.meanAdvantage != b.meanAdvantage { return a.meanAdvantage < b.meanAdvantage }
            if a.positiveSegments != b.positiveSegments { return a.positiveSegments < b.positiveSegments }
            if a.minimumAdvantage != b.minimumAdvantage { return a.minimumAdvantage < b.minimumAdvantage }
            return lhs.blendPercent > rhs.blendPercent
        }
    }

    private func makeF2Ticket(from draws: [EuroJackpotDraw]) -> Ticket {
        return makeTicket(from: draws, variant: Variant(signal: .meanRate, blendPercent: 0))
    }

    private func makeTicket(from draws: [EuroJackpotDraw], variant: Variant) -> Ticket {
        let f2Source = Array(draws.suffix(baseWindow))
        let weight = Double(variant.blendPercent) / 100.0
        let main = rankNumbers(range: 1...50, limit: 5, baseDraws: f2Source, trainingDraws: draws, signal: variant.signal, weight: weight, isEuro: false)
        let euro = rankNumbers(range: 1...12, limit: 2, baseDraws: f2Source, trainingDraws: draws, signal: variant.signal, weight: weight, isEuro: true)
        return Ticket(numbers: main.sorted(), euroNumbers: euro.sorted())
    }

    private func rankNumbers(
        range: ClosedRange<Int>,
        limit: Int,
        baseDraws: [EuroJackpotDraw],
        trainingDraws: [EuroJackpotDraw],
        signal: Signal,
        weight: Double,
        isEuro: Bool
    ) -> [Int] {
        let baseScores = normalizedRates(in: baseDraws, range: range, isEuro: isEuro)
        let windowsScores = windows.map { normalizedRates(in: Array(trainingDraws.suffix($0)), range: range, isEuro: isEuro) }

        let scored = range.map { number -> (Int, Double) in
            let f2 = baseScores[number, default: 1.0]
            let values = windowsScores.map { $0[number, default: 1.0] }
            let frequency: Double

            switch signal {
            case .meanRate:
                frequency = values.reduce(0, +) / Double(values.count)
            case .rankConsensus:
                let ranks = windowsScores.map { scores -> Double in
                    let ordered = range.sorted {
                        let l = scores[$0, default: 1.0]
                        let r = scores[$1, default: 1.0]
                        if l == r { return $0 < $1 }
                        return l > r
                    }
                    return Double(ordered.firstIndex(of: number) ?? ordered.count) / Double(max(1, ordered.count - 1))
                }
                let meanRank = ranks.reduce(0, +) / Double(ranks.count)
                frequency = 1.0 + (0.5 - meanRank)
            case .persistence:
                let positive = values.filter { $0 > 1.0 }.count
                frequency = Double(positive) / Double(values.count)
            }

            let score = (1.0 - weight) * f2 + weight * frequency
            return (number, score)
        }
        .sorted {
            if $0.1 == $1.1 { return $0.0 < $1.0 }
            return $0.1 > $1.1
        }

        return Array(scored.prefix(limit).map(\.0))
    }

    private func normalizedRates(
        in draws: [EuroJackpotDraw],
        range: ClosedRange<Int>,
        isEuro: Bool
    ) -> [Int: Double] {
        guard !draws.isEmpty else { return [:] }
        var counts: [Int: Int] = [:]
        for draw in draws {
            let values = isEuro ? draw.euroNumbers : draw.numbers
            for value in values where range.contains(value) {
                counts[value, default: 0] += 1
            }
        }

        let total = Double(draws.count)
        let expected = isEuro ? total * 2.0 / 12.0 : total * 5.0 / 50.0
        return Dictionary(uniqueKeysWithValues: range.map { number in
            (number, Double(counts[number, default: 0]) / max(expected, 1.0))
        })
    }
}
