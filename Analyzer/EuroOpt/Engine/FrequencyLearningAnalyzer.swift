import Foundation

/// Isolierter Walk-Forward-Test für Häufigkeit als zusätzliches Lernsignal.
///
/// Die Analyse verändert F2/50 nicht. Sie vergleicht verschiedene historische
/// Frequenzfenster sowie Hot/Cold/Mix-Varianten und misst ausschließlich auf
/// zeitlich getrennten Holdouts.
final class FrequencyLearningAnalyzer {
    private struct Variant {
        let name: String
        let window: Int?
        let mode: Mode
        let blendWithF2: Double

        enum Mode {
            case frequency
            case hotColdMix
            case cold
        }
    }

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

    private struct SplitResult {
        let split: Int
        let validation: [Double]
        let holdout: [Double]
    }

    private let warmup = WeightSweepCore.warmup
    private let splitCount = 10
    private let windows = [50, 100, 200, 400]
    private let blendWeights = [0.25, 0.50, 0.75]

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + splitCount * 4 else {
            print("❌ Frequenz-Lernanalyse: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let variants = makeVariants()
        let totalTests = draws.count - warmup
        let availableWindow = totalTests / splitCount
        var splitResults: [SplitResult] = []
        var holdoutTotals = variants.map { _ in Aggregate() }
        var validationTotals = variants.map { _ in Aggregate() }

        print("")
        print("===================================")
        print("📊 FREQUENZ-LERNANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Fenster             : \(windows.map(String.init).joined(separator: " / ")) + gesamte Historie")
        print("Varianten            : Häufigkeit / Hot-Cold-Mix / F2-Mischungen")
        print("Splits              : \(splitCount) zeitlich getrennte Blöcke")
        print("Holdout             : erst nach der Validation-Auswahl")
        print("")

        for split in 0..<splitCount {
            let splitStart = warmup + split * availableWindow
            let splitEnd = split == splitCount - 1
                ? draws.count
                : min(draws.count, warmup + (split + 1) * availableWindow)
            let size = splitEnd - splitStart
            guard size >= 4 else { continue }

            let validationEnd = splitStart + size / 2
            var validationByVariant = variants.map { _ in Aggregate() }
            var holdoutByVariant = variants.map { _ in Aggregate() }

            for index in splitStart..<validationEnd {
                let training = Array(draws.prefix(index))
                let target = draws[index]
                for (variantIndex, variant) in variants.enumerated() {
                    let ticket = makeTicket(variant: variant, draws: training)
                    validationByVariant[variantIndex].add(ticket: ticket, target: target)
                }
            }

            guard validationByVariant.indices.max(by: {
                validationByVariant[$0].score < validationByVariant[$1].score
            }) != nil else { continue }

            for index in validationEnd..<splitEnd {
                let training = Array(draws.prefix(index))
                let target = draws[index]
                for (variantIndex, variant) in variants.enumerated() {
                    let ticket = makeTicket(variant: variant, draws: training)
                    holdoutByVariant[variantIndex].add(ticket: ticket, target: target)
                }
            }

            for index in variants.indices {
                validationTotals[index].merge(validationByVariant[index])
                holdoutTotals[index].merge(holdoutByVariant[index])
            }

            splitResults.append(
                SplitResult(
                    split: split + 1,
                    validation: validationByVariant.map(\.score),
                    holdout: holdoutByVariant.map(\.score)
                )
            )

            let winnerIndex = validationByVariant.indices.max(by: {
                validationByVariant[$0].score < validationByVariant[$1].score
            })!
            print(String(format: "Split %2d | Gewinner Validation: %@ | Val Δ %+.3f | Hold Δ %+.3f",
                         split + 1,
                         variants[winnerIndex].name,
                         validationByVariant[winnerIndex].score,
                         holdoutByVariant[winnerIndex].score))
        }

        print("")
        print("===================================")
        print("GESAMTVERGLEICH FREQUENZ-VARIANTEN")
        print("===================================")
        print("Variante | Val Δ | Hold Δ | Pos. Holdouts")

        for index in variants.indices {
            let positive = splitResults.reduce(0) { partial, split in
                partial + (split.holdout[index] > 0 ? 1 : 0)
            }
            print(String(format: "%@ | %+.3f | %+.3f | %d/%d",
                         variants[index].name,
                         validationTotals[index].score,
                         holdoutTotals[index].score,
                         positive,
                         splitResults.count))
        }

        print("")
        print("===================================")
        print("BESTE VARIANTE JE SPLIT")
        print("===================================")
        var winnerCounts = Array(repeating: 0, count: variants.count)
        var winnerHoldout = Array(repeating: 0.0, count: variants.count)

        for split in splitResults {
            guard let winner = split.validation.indices.max(by: {
                split.validation[$0] < split.validation[$1]
            }) else { continue }
            winnerCounts[winner] += 1
            winnerHoldout[winner] += split.holdout[winner]
        }

        for index in variants.indices where winnerCounts[index] > 0 {
            print(String(format: "%@ | Validation-Siege %d/%d | Summe Holdout-Δ %+.3f",
                         variants[index].name,
                         winnerCounts[index],
                         splitResults.count,
                         winnerHoldout[index]))
        }

        print("")
        print("Interpretation:")
        print("Die Auswahl erfolgt ausschließlich aus der Validation.")
        print("Der Holdout wird erst nach der Auswahl bewertet.")
        print("F2/50 bleibt unverändert und dient als Referenz: Frequenzfenster 50.")
        print("Hot/Cold ist nur dann interessant, wenn es außerhalb der Validation stabil besser als F2/50 abschneidet.")
        print("")
        print(String(format: "⏱ Frequenz-Lernanalyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeVariants() -> [Variant] {
        var result: [Variant] = []
        for window in windows {
            result.append(Variant(name: "Freq \(window)", window: window, mode: .frequency, blendWithF2: 0))
        }
        result.append(Variant(name: "Freq gesamt", window: nil, mode: .frequency, blendWithF2: 0))
        for weight in blendWeights {
            result.append(Variant(name: String(format: "F2 + Freq100 %.0f%%", weight * 100), window: 100, mode: .frequency, blendWithF2: weight))
        }
        for weight in blendWeights {
            result.append(Variant(name: String(format: "F2 + Freq400 %.0f%%", weight * 100), window: 400, mode: .frequency, blendWithF2: weight))
        }
        result.append(Variant(name: "Hot/Cold 100", window: 100, mode: .hotColdMix, blendWithF2: 0))
        result.append(Variant(name: "Cold 100", window: 100, mode: .cold, blendWithF2: 0))
        return result
    }

    private func makeTicket(variant: Variant, draws: [EuroJackpotDraw]) -> Ticket {
        let mainF2 = rankedNumbers(in: Array(draws.suffix(50)), range: 1...50, limit: 5)
        let euroF2 = rankedNumbers(in: Array(draws.suffix(50)), range: 1...12, limit: 2, euro: true)

        let source: [EuroJackpotDraw]
        if let window = variant.window {
            source = Array(draws.suffix(window))
        } else {
            source = draws
        }

        switch variant.mode {
        case .frequency:
            let mainFreq = rankedNumbers(in: source, range: 1...50, limit: 50)
            let euroFreq = rankedNumbers(in: source, range: 1...12, limit: 12, euro: true)
            return Ticket(
                numbers: blend(main: mainF2, secondary: Array(mainFreq.prefix(5)), secondaryWeight: variant.blendWithF2),
                euroNumbers: blend(main: euroF2, secondary: Array(euroFreq.prefix(2)), secondaryWeight: variant.blendWithF2)
            )
        case .hotColdMix:
            let hot = rankedNumbers(in: source, range: 1...50, limit: 25)
            let cold = rankedNumbers(in: source, range: 1...50, limit: 25, ascending: true)
            let main = Array(hot.prefix(3)) + Array(cold.prefix(2))
            let hotEuro = rankedNumbers(in: source, range: 1...12, limit: 6, euro: true)
            let coldEuro = rankedNumbers(in: source, range: 1...12, limit: 6, euro: true, ascending: true)
            return Ticket(numbers: uniqueFive(main), euroNumbers: uniqueTwo(Array(hotEuro.prefix(1)) + Array(coldEuro.prefix(1))))
        case .cold:
            let main = rankedNumbers(in: source, range: 1...50, limit: 5, ascending: true)
            let euro = rankedNumbers(in: source, range: 1...12, limit: 2, euro: true, ascending: true)
            return Ticket(numbers: main.sorted(), euroNumbers: euro.sorted())
        }
    }

    private func blend(main: [Int], secondary: [Int], secondaryWeight: Double) -> [Int] {
        if secondaryWeight <= 0 { return Array(main.prefix(5)).sorted() }
        if secondaryWeight >= 1 { return Array(secondary.prefix(main.count)).sorted() }

        var score: [Int: Double] = [:]
        for (rank, value) in main.enumerated() {
            score[value, default: 0] += (1.0 - secondaryWeight) * Double(main.count - rank)
        }
        for (rank, value) in secondary.enumerated() {
            score[value, default: 0] += secondaryWeight * Double(secondary.count - rank)
        }
        return score.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }.prefix(5).map(\.key).sorted()
    }

    private func rankedNumbers(in draws: [EuroJackpotDraw], range: ClosedRange<Int>, limit: Int, euro: Bool = false, ascending: Bool = false) -> [Int] {
        var counts: [Int: Int] = [:]
        for draw in draws {
            let values = euro ? draw.euroNumbers : draw.numbers
            for value in values { counts[value, default: 0] += 1 }
        }
        return Array(range.sorted {
            let left = counts[$0, default: 0]
            let right = counts[$1, default: 0]
            if left == right { return $0 < $1 }
            return ascending ? left < right : left > right
        }.prefix(limit))
    }

    private func uniqueFive(_ values: [Int]) -> [Int] {
        var result: [Int] = []
        for value in values where !result.contains(value) {
            result.append(value)
            if result.count == 5 { break }
        }
        if result.count < 5 {
            for value in 1...50 where !result.contains(value) {
                result.append(value)
                if result.count == 5 { break }
            }
        }
        return result.sorted()
    }

    private func uniqueTwo(_ values: [Int]) -> [Int] {
        var result: [Int] = []
        for value in values where !result.contains(value) {
            result.append(value)
            if result.count == 2 { break }
        }
        if result.count < 2 {
            for value in 1...12 where !result.contains(value) {
                result.append(value)
                if result.count == 2 { break }
            }
        }
        return result.sorted()
    }
}
