import Foundation

/// Descriptive feature analysis of the fixed F2/50 baseline.
/// F2 is never changed and no feature is selected for production use here.
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

    private struct Bucket {
        let name: String
        var validation = Aggregate()
        var holdout = Aggregate()
    }

    private let warmup = WeightSweepCore.warmup
    private let window = 50

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 20 else {
            print("❌ F2-Feature-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let total = draws.count - warmup
        let validationEnd = warmup + total / 2

        var sums = makeBuckets(["<100", "100–124", "125–149", "150+"])
        var evens = makeBuckets((0...5).map { "\($0) gerade" })
        var highs = makeBuckets((0...5).map { "\($0) hoch (26–50)" })
        var consecutive = makeBuckets(["0", "1", "2+"])
        var spreads = makeBuckets(["<20", "20–29", "30–39", "40+"])
        var overallValidation = Aggregate()
        var overallHoldout = Aggregate()

        print("\n===================================")
        print("🔎 F2/50 FEATURE-ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(window) Trainingsziehungen")
        print("Validation          : historische erste Hälfte")
        print("Holdout             : historische zweite Hälfte")
        print("Auswahl             : keine")
        print("Produktionsprofil   : unverändert\n")

        for index in warmup..<draws.count {
            let ticket = makeF2Ticket(from: Array(draws.prefix(index)))
            let target = draws[index]
            let validation = index < validationEnd

            if validation {
                overallValidation.add(ticket: ticket, target: target)
            } else {
                overallHoldout.add(ticket: ticket, target: target)
            }

            add(ticket: ticket, target: target, to: &sums, bucket: sumBucket(ticket), validation: validation)
            add(ticket: ticket, target: target, to: &evens, bucket: evenBucket(ticket), validation: validation)
            add(ticket: ticket, target: target, to: &highs, bucket: highBucket(ticket), validation: validation)
            add(ticket: ticket, target: target, to: &consecutive, bucket: consecutiveBucket(ticket), validation: validation)
            add(ticket: ticket, target: target, to: &spreads, bucket: spreadBucket(ticket), validation: validation)
        }

        printOverall(overallValidation, holdout: overallHoldout)
        printFeature("SUMME 5 HAUPTZAHLEN", buckets: sums)
        printFeature("GERADE ZAHLEN", buckets: evens)
        printFeature("HOHE ZAHLEN 26–50", buckets: highs)
        printFeature("BENACHBARTE PAARE", buckets: consecutive)
        printFeature("SPREAD MAX−MIN", buckets: spreads)

        print("\nInterpretation:")
        print("Die Analyse verändert F2 nicht und wählt kein Feature für Alpha aus.")
        print("Interessant ist nur ein Bucket-Unterschied, der in Validation und Holdout in ähnlicher Richtung sichtbar bleibt.")
        print(String(format: "⏱ F2-Feature-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeF2Ticket(from draws: [EuroJackpotDraw]) -> Ticket {
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

        let numbers = (1...50)
            .sorted {
                main[$0, default: 0] == main[$1, default: 0]
                    ? $0 < $1
                    : main[$0, default: 0] > main[$1, default: 0]
            }
            .prefix(5)
            .sorted()

        let euroNumbers = (1...12)
            .sorted {
                euro[$0, default: 0] == euro[$1, default: 0]
                    ? $0 < $1
                    : euro[$0, default: 0] > euro[$1, default: 0]
            }
            .prefix(2)
            .sorted()

        return Ticket(numbers: Array(numbers), euroNumbers: Array(euroNumbers))
    }

    private func makeBuckets(_ names: [String]) -> [Bucket] {
        names.map { Bucket(name: $0) }
    }

    private func add(ticket: Ticket,
                     target: EuroJackpotDraw,
                     to buckets: inout [Bucket],
                     bucket: Int,
                     validation: Bool) {
        guard buckets.indices.contains(bucket) else { return }

        if validation {
            buckets[bucket].validation.add(ticket: ticket, target: target)
        } else {
            buckets[bucket].holdout.add(ticket: ticket, target: target)
        }
    }

    private func sumBucket(_ ticket: Ticket) -> Int {
        switch ticket.numbers.reduce(0, +) {
        case ..<100:
            return 0
        case 100..<125:
            return 1
        case 125..<150:
            return 2
        default:
            return 3
        }
    }

    private func evenBucket(_ ticket: Ticket) -> Int {
        ticket.numbers.filter { $0.isMultiple(of: 2) }.count
    }

    private func highBucket(_ ticket: Ticket) -> Int {
        ticket.numbers.filter { $0 >= 26 }.count
    }

    private func consecutiveBucket(_ ticket: Ticket) -> Int {
        let numbers = ticket.numbers.sorted()
        var pairs = 0

        if numbers.count > 1 {
            for index in 1..<numbers.count where numbers[index] == numbers[index - 1] + 1 {
                pairs += 1
            }
        }

        return pairs == 0 ? 0 : pairs == 1 ? 1 : 2
    }

    private func spreadBucket(_ ticket: Ticket) -> Int {
        guard let minimum = ticket.numbers.min(),
              let maximum = ticket.numbers.max() else {
            return 0
        }

        switch maximum - minimum {
        case ..<20:
            return 0
        case 20..<30:
            return 1
        case 30..<40:
            return 2
        default:
            return 3
        }
    }

    private func printOverall(_ validation: Aggregate, holdout: Aggregate) {
        print("-----------------------------------")
        print("F2 GESAMT")
        print("-----------------------------------")
        print(String(format: "Validation: Haupt %.3f | Euro %.3f | Δ %+.3f", validation.mainRate, validation.euroRate, validation.delta))
        print(String(format: "Holdout   : Haupt %.3f | Euro %.3f | Δ %+.3f", holdout.mainRate, holdout.euroRate, holdout.delta))
    }

    private func printFeature(_ title: String, buckets: [Bucket]) {
        print("\n-----------------------------------")
        print(title)
        print("-----------------------------------")
        print("Bucket                 Val Δ    Hold Δ    n Val/n Hold")

        for bucket in buckets {
            let padded = bucket.name.padding(toLength: 22, withPad: " ", startingAt: 0)
            print(String(format: "%@ %+.3f    %+.3f    %4d/%-4d",
                         padded,
                         bucket.validation.delta,
                         bucket.holdout.delta,
                         bucket.validation.tickets,
                         bucket.holdout.tickets))
        }
    }
}
