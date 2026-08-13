import Foundation

/// F2/50 Euro-number analysis. Production Alpha/F2 is never modified.
final class F2FeatureAnalyzer {
    private struct Aggregate {
        var hits = 0
        var euroHits = 0
        var tickets = 0
        var expectedEuroHits = 0.0
        var delta: Double {
            guard tickets > 0 else { return 0 }
            return (Double(hits) / Double(tickets) - 0.50) +
                   (Double(euroHits) / Double(tickets) - expectedEuroHits / Double(tickets))
        }
        mutating func add(_ ticket: Ticket, _ target: EuroJackpotDraw) {
            hits += Set(ticket.numbers).intersection(Set(target.numbers)).count
            euroHits += Set(ticket.euroNumbers).intersection(Set(target.euroNumbers)).count
            tickets += 1
            expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: 1)
        }
    }

    private let warmup = 100
    private let mainWindow = 50
    private let splitCount = 10
    private let euroWindows = [25, 50, 100, 200, 400]

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 120 else {
            print("❌ F2-Euro-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        print("\n===================================")
        print("💶 F2/50 EUROZAHLEN-ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Hauptzahlen F2      : letzte \(mainWindow) Trainingsziehungen")
        print("Euro-Fenster        : 25 / 50 / 100 / 200 / 400")
        print("Hauptzahlen         : F2/50 unverändert")
        print("Auswahl             : ausschließlich Validation")
        print("Holdout             : erst nach der Auswahl")
        print("Splits              : \(splitCount) zeitlich getrennte Walk-Forward-Splits\n")

        var results: [(window: Int, val: Aggregate, hold: Aggregate, baseVal: Aggregate, baseHold: Aggregate)] = []
        results.reserveCapacity(splitCount)

        for split in 0..<splitCount {
            let available = draws.count - warmup
            let block = available / splitCount
            let validationStart = warmup + split * block
            let validationEnd = split == splitCount - 1
                ? warmup + Int(Double(available) * 0.92)
                : validationStart + max(8, block * 2 / 3)
            let holdoutEnd = split == splitCount - 1 ? draws.count : validationStart + block
            guard validationStart < validationEnd, validationEnd < holdoutEnd, holdoutEnd <= draws.count else { continue }

            var val = Array(repeating: Aggregate(), count: euroWindows.count)
            var baseVal = Aggregate()

            print("Split \(split + 1)/\(splitCount) – Validation ...")
            for i in validationStart..<validationEnd {
                let tickets = makeTickets(draws: draws, endIndex: i)
                for w in euroWindows.indices { val[w].add(tickets[w], draws[i]) }
                baseVal.add(tickets[1], draws[i]) // Euro 50 is the F2/50 reference.
            }

            let selected = select(validation: val, baseline: baseVal)
            var hold = Aggregate()
            var baseHold = Aggregate()

            print("Split \(split + 1)/\(splitCount) – Holdout ...")
            for i in validationEnd..<holdoutEnd {
                let tickets = makeTickets(draws: draws, endIndex: i)
                hold.add(tickets[selected], draws[i])
                baseHold.add(tickets[1], draws[i])
            }

            results.append((euroWindows[selected], val[selected], hold, baseVal, baseHold))
        }

        printResults(results)
        print(String(format: "\n⏱ F2/50 Eurozahlen-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private func select(validation: [Aggregate], baseline: Aggregate) -> Int {
        var best = 1 // F2/50 is the tie-preferred reference.
        var bestScore = -Double.infinity
        for i in validation.indices {
            let d = validation[i].delta - baseline.delta
            let tiePenalty = i == 1 ? 0.0 : 0.0001
            let score = d - tiePenalty
            if score > bestScore {
                bestScore = score
                best = i
            }
        }
        return best
    }

    private func makeTickets(draws: [EuroJackpotDraw], endIndex: Int) -> [Ticket] {
        let mainStart = max(0, endIndex - mainWindow)
        let mainSource = Array(draws[mainStart..<endIndex])
        var mainCounts = Array(repeating: 0, count: 51)
        for draw in mainSource {
            for n in draw.numbers where n >= 1 && n <= 50 { mainCounts[n] += 1 }
        }
        let rankedMain = (1...50).sorted {
            mainCounts[$0] == mainCounts[$1] ? $0 < $1 : mainCounts[$0] > mainCounts[$1]
        }
        let mainNumbers = Array(rankedMain.prefix(5)).sorted()

        return euroWindows.map { window in
            let start = max(0, endIndex - window)
            let source = Array(draws[start..<endIndex])
            var counts = Array(repeating: 0, count: 13)
            for draw in source {
                for n in draw.euroNumbers where n >= 1 && n <= 12 { counts[n] += 1 }
            }
            let ranked = (1...12).sorted {
                counts[$0] == counts[$1] ? $0 < $1 : counts[$0] > counts[$1]
            }
            return Ticket(numbers: mainNumbers, euroNumbers: Array(ranked.prefix(2)).sorted())
        }
    }

    private func printResults(_ results: [(window: Int, val: Aggregate, hold: Aggregate, baseVal: Aggregate, baseHold: Aggregate)]) {
        print("\n## F2-EURO-SPLITS")
        print("Split | Gewinner | Val Δ ggü F2/50 | Hold Δ | F2/50 Hold Δ")
        for (i, r) in results.enumerated() {
            let valDelta = r.val.delta - r.baseVal.delta
            print(String(format: "%2d | Euro%-3d | %+.3f | %+.3f | %+.3f", i + 1, r.window, valDelta, r.hold.delta, r.baseHold.delta))
        }

        guard !results.isEmpty else { return }
        let selectedHold = results.map(\.hold.delta).reduce(0, +) / Double(results.count)
        let f2Hold = results.map(\.baseHold.delta).reduce(0, +) / Double(results.count)
        let advantage = selectedHold - f2Hold
        let better = results.filter { $0.hold.delta > $0.baseHold.delta }.count
        let worse = results.filter { $0.hold.delta < $0.baseHold.delta }.count
        let equal = results.count - better - worse

        var counts: [Int: Int] = [:]
        for r in results { counts[r.window, default: 0] += 1 }

        print("\n## F2-EURO – GESAMT")
        print(String(format: "Gewählte Varianten Hold Δ : %+.3f", selectedHold))
        print(String(format: "F2/50 Hold Δ              : %+.3f", f2Hold))
        print(String(format: "Vorteil ggü. F2/50        : %+.3f", advantage))
        print("Gewählte Variante besser  : \(better)/\(results.count)")
        print("F2/50 besser              : \(worse)/\(results.count)")
        print("Gleichstand               : \(equal)/\(results.count)")
        print("\n## GEWÄHLTE EURO-FENSTER")
        for window in euroWindows {
            print("Euro\(window) : \(counts[window, default: 0])/\(results.count)")
        }
    }
}
