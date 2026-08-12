//
//  FrequencyStabilityAnalyzer.swift
//  EuroOpt
//
//  Stability check for the fixed F2 / 50-draw frequency baseline.
//  Uses separated historical blocks and fresh validation/holdout halves.
//

import Foundation

final class FrequencyStabilityAnalyzer {

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
    }

    private struct PeriodResult {
        let name: String
        let validation: Double
        let holdout: Double
        let validationTickets: Int
        let holdoutTickets: Int
    }

    private let warmup = WeightSweepCore.warmup
    private let frequencyWindow = 50

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 100 else {
            print("❌ F2/50-Stabilität: zu wenige Ziehungen")
            return
        }

        let total = draws.count - warmup
        let periodSize = total / 3
        let start = Date()
        var results: [PeriodResult] = []

        print("")
        print("===================================")
        print("📊 F2/50 – HISTORISCHE STABILITÄT")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte 50 Trainingsziehungen")
        print("Perioden            : 3 zeitlich getrennte Blöcke")
        print("Aufteilung          : je Block Validation / Holdout")
        print("Holdout             : erst nach der Tippbildung")
        print("")

        for period in 0..<3 {
            let periodStart = warmup + period * periodSize
            let periodEnd = period == 2 ? draws.count : min(draws.count, warmup + (period + 1) * periodSize)
            let size = periodEnd - periodStart
            guard size >= 2 else { continue }

            let validationEnd = periodStart + size / 2
            var validation = Aggregate()
            var holdout = Aggregate()

            for index in periodStart..<validationEnd {
                let ticket = makeTicket(from: draws, before: index)
                add(ticket: ticket, target: draws[index], to: &validation)
            }

            for index in validationEnd..<periodEnd {
                let ticket = makeTicket(from: draws, before: index)
                add(ticket: ticket, target: draws[index], to: &holdout)
            }

            results.append(PeriodResult(
                name: "Periode \(period + 1)",
                validation: validation.score,
                holdout: holdout.score,
                validationTickets: validation.tickets,
                holdoutTickets: holdout.tickets
            ))
        }

        print("-----------------------------------")
        print("ERGEBNISSE")
        print("-----------------------------------")
        print("Periode      Val Δ       Hold Δ")
        for result in results {
            print(String(format: "%-10@  %+.3f       %+.3f", result.name, result.validation, result.holdout))
        }

        if !results.isEmpty {
            let averageValidation = results.map(\.validation).reduce(0, +) / Double(results.count)
            let averageHoldout = results.map(\.holdout).reduce(0, +) / Double(results.count)
            let positiveHoldouts = results.filter { $0.holdout > 0 }.count

            print("")
            print("GESAMT")
            print(String(format: "Ø Validation Δ     : %+.3f", averageValidation))
            print(String(format: "Ø Holdout Δ        : %+.3f", averageHoldout))
            print("Positive Holdouts  : \(positiveHoldouts)/\(results.count)")
        }

        print(String(format: "⏱ F2/50-Stabilität: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeTicket(from draws: [EuroJackpotDraw], before index: Int) -> Ticket {
        let source = Array(draws.prefix(index).suffix(frequencyWindow))
        var main: [Int: Int] = [:]
        var euro: [Int: Int] = [:]

        for draw in source {
            for number in draw.numbers { main[number, default: 0] += 1 }
            for number in draw.euroNumbers { euro[number, default: 0] += 1 }
        }

        let numbers = (1...50).sorted {
            let lhs = main[$0, default: 0]
            let rhs = main[$1, default: 0]
            return lhs == rhs ? $0 < $1 : lhs > rhs
        }.prefix(5).sorted()

        let euroNumbers = (1...12).sorted {
            let lhs = euro[$0, default: 0]
            let rhs = euro[$1, default: 0]
            return lhs == rhs ? $0 < $1 : lhs > rhs
        }.prefix(2).sorted()

        return Ticket(numbers: Array(numbers), euroNumbers: Array(euroNumbers))
    }

    private func add(ticket: Ticket, target: EuroJackpotDraw, to aggregate: inout Aggregate) {
        aggregate.hits += Set(ticket.numbers).intersection(target.numbers).count
        aggregate.euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
        aggregate.tickets += 1
        aggregate.expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: 1)
    }
}
