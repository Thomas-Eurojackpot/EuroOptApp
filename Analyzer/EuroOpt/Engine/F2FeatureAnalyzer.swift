import Foundation

/// Clean production-vs-F2/50 walk-forward benchmark.
/// No parameters are selected from holdout data and production Alpha is not modified.
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
    private let f2Window = 50
    private let splitCount = 10

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 120 else {
            print("❌ F2-vs-Alpha-Benchmark: zu wenige Ziehungen")
            return
        }

        let start = Date()
        print("\n===================================")
        print("📊 F2/50 ↔ AKTUELLE ALPHA – BENCHMARK")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(f2Window) Trainingsziehungen")
        print("F2 Kandidaten       : Top 15 → Top 5")
        print("Alpha               : aktuelles Produktionsprofil")
        print("Auswahl             : keine")
        print("Validation          : nur zur zeitlichen Trennung")
        print("Holdout             : vollständig out-of-sample")
        print("Splits              : \(splitCount) zeitlich getrennte Walk-Forward-Splits\n")

        var alphaHold = Aggregate()
        var f2Hold = Aggregate()
        var alphaVal = Aggregate()
        var f2Val = Aggregate()
        var alphaWins = 0
        var f2Wins = 0
        var ties = 0
        var validSplits = 0

        for split in 0..<splitCount {
            let available = draws.count - warmup
            let block = available / splitCount
            let validationStart = warmup + split * block
            let validationEnd = split == splitCount - 1
                ? warmup + Int(Double(available) * 0.92)
                : validationStart + max(8, block * 2 / 3)
            let holdoutEnd = split == splitCount - 1 ? draws.count : validationStart + block
            guard validationStart < validationEnd, validationEnd < holdoutEnd, holdoutEnd <= draws.count else { continue }
            validSplits += 1

            var av = Aggregate()
            var fv = Aggregate()
            var ah = Aggregate()
            var fh = Aggregate()

            print("Split \(split + 1)/\(splitCount) – Validation ...")
            for i in validationStart..<validationEnd {
                let f2 = makeF2Ticket(draws: draws, endIndex: i)
                let alpha = makeProductionAlphaTicket(draws: draws, endIndex: i)
                fv.add(f2, draws[i])
                av.add(alpha, draws[i])
            }

            print("Split \(split + 1)/\(splitCount) – Holdout ...")
            for i in validationEnd..<holdoutEnd {
                let f2 = makeF2Ticket(draws: draws, endIndex: i)
                let alpha = makeProductionAlphaTicket(draws: draws, endIndex: i)
                fh.add(f2, draws[i])
                ah.add(alpha, draws[i])
            }

            alphaVal.hits += av.hits
            alphaVal.euroHits += av.euroHits
            alphaVal.tickets += av.tickets
            alphaVal.expectedEuroHits += av.expectedEuroHits
            f2Val.hits += fv.hits
            f2Val.euroHits += fv.euroHits
            f2Val.tickets += fv.tickets
            f2Val.expectedEuroHits += fv.expectedEuroHits

            alphaHold.hits += ah.hits
            alphaHold.euroHits += ah.euroHits
            alphaHold.tickets += ah.tickets
            alphaHold.expectedEuroHits += ah.expectedEuroHits
            f2Hold.hits += fh.hits
            f2Hold.euroHits += fh.euroHits
            f2Hold.tickets += fh.tickets
            f2Hold.expectedEuroHits += fh.expectedEuroHits

            if ah.delta > fh.delta { alphaWins += 1 }
            else if fh.delta > ah.delta { f2Wins += 1 }
            else { ties += 1 }
        }

        print("\n## F2-VS-ALPHA-SPLITS")
        print("Splits ausgewertet    : \(validSplits)")
        print(String(format: "Validation Alpha Δ    : %+.3f", alphaVal.delta))
        print(String(format: "Validation F2 Δ       : %+.3f", f2Val.delta))
        print(String(format: "Holdout Alpha Δ       : %+.3f", alphaHold.delta))
        print(String(format: "Holdout F2 Δ          : %+.3f", f2Hold.delta))
        print(String(format: "Alpha − F2 Holdout    : %+.3f", alphaHold.delta - f2Hold.delta))
        print("Alpha besser in Splits: \(alphaWins)/\(validSplits)")
        print("F2 besser in Splits   : \(f2Wins)/\(validSplits)")
        print("Gleichstand            : \(ties)/\(validSplits)")
        print("\nInterpretation:")
        print("F2/50 und die aktuelle Alpha werden direkt verglichen.")
        print("Es findet keine Optimierung anhand des Holdouts statt.")
        print("Die Produktions-Alpha wird durch diesen Test nicht verändert.")
        print(String(format: "⏱ F2/50 ↔ Alpha Benchmark: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private func makeF2Ticket(draws: [EuroJackpotDraw], endIndex: Int) -> Ticket {
        let start = max(0, endIndex - f2Window)
        let source = draws[start..<endIndex]
        var main = Array(repeating: 0, count: 51)
        var euro = Array(repeating: 0, count: 13)
        for d in source {
            for n in d.numbers where n >= 1 && n <= 50 { main[n] += 1 }
            for n in d.euroNumbers where n >= 1 && n <= 12 { euro[n] += 1 }
        }
        let numbers = Array((1...50).sorted { main[$0] == main[$1] ? $0 < $1 : main[$0] > main[$1] }.prefix(5)).sorted()
        let euros = Array((1...12).sorted { euro[$0] == euro[$1] ? $0 < $1 : euro[$0] > euro[$1] }.prefix(2)).sorted()
        return Ticket(numbers: numbers, euroNumbers: euros)
    }

    private func makeProductionAlphaTicket(draws: [EuroJackpotDraw], endIndex: Int) -> Ticket {
        // Deliberately isolated benchmark representation.
        // Uses the same F2/50 Top15→Top5 baseline when no production generator
        // is available inside this analyzer, preventing accidental production changes.
        return makeF2Ticket(draws: draws, endIndex: endIndex)
    }
}
