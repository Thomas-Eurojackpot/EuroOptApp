//
//  FrequencyStabilityAnalyzer.swift
//  EuroOpt
//
//  Historical stability comparison for fixed frequency windows.
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

    private struct WindowResult {
        let window: Int
        let validation: Double
        let holdout: Double
        let positiveHoldouts: Int
    }

    private let warmup = WeightSweepCore.warmup
    private let periodCount = 5
    private let frequencyWindows = [25, 50, 75, 100, 150]

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count > warmup + 100 else {
            print("❌ Frequenz-Stabilität: zu wenige Ziehungen")
            return
        }

        let total = draws.count - warmup
        let periodSize = total / periodCount
        let start = Date()

        print("")
        print("===================================")
        print("📊 FREQUENZ-FENSTER – 5-PERIODEN-STABILITÄT")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Fenster             : 25 / 50 / 75 / 100 / 150 Ziehungen")
        print("Perioden            : \(periodCount) zeitlich getrennte Blöcke")
        print("Aufteilung          : je Block Validation / Holdout")
        print("Holdout             : erst nach der Tippbildung")
        print("Profilwahl          : keine")
        print("")

        var windowResults: [WindowResult] = []

        for window in frequencyWindows {
            var validationScores: [Double] = []
            var holdoutScores: [Double] = []
            var positiveHoldouts = 0

            for period in 0..<periodCount {
                let periodStart = warmup + period * periodSize
                let periodEnd = period == periodCount - 1
                    ? draws.count
                    : min(draws.count, warmup + (period + 1) * periodSize)
                let size = periodEnd - periodStart
                guard size >= 2 else { continue }

                let validationEnd = periodStart + size / 2
                var validation = Aggregate()
                var holdout = Aggregate()

                for index in periodStart..<validationEnd {
                    let ticket = makeTicket(from: draws, before: index, window: window)
                    add(ticket: ticket, target: draws[index], to: &validation)
                }

                for index in validationEnd..<periodEnd {
                    let ticket = makeTicket(from: draws, before: index, window: window)
                    add(ticket: ticket, target: draws[index], to: &holdout)
                }

                validationScores.append(validation.score)
                holdoutScores.append(holdout.score)
                if holdout.score > 0 { positiveHoldouts += 1 }
            }

            let averageValidation = validationScores.isEmpty
                ? 0
                : validationScores.reduce(0, +) / Double(validationScores.count)
            let averageHoldout = holdoutScores.isEmpty
                ? 0
                : holdoutScores.reduce(0, +) / Double(holdoutScores.count)

            windowResults.append(WindowResult(
                window: window,
                validation: averageValidation,
                holdout: averageHoldout,
                positiveHoldouts: positiveHoldouts
            ))
        }

        print("-----------------------------------")
        print("GESAMTVERGLEICH")
        print("-----------------------------------")
        print("Fenster   Ø Val Δ    Ø Hold Δ   Pos. Holdouts")
        for result in windowResults {
            print(String(format: "%-7d   %+.3f      %+.3f        %d/%d",
                         result.window,
                         result.validation,
                         result.holdout,
                         result.positiveHoldouts,
                         periodCount))
        }

        if let best = windowResults.max(by: { $0.holdout < $1.holdout }) {
            print("")
            print("Top nach Ø Holdout:")
            print(String(format: "%d Ziehungen: Hold Δ %+.3f | Val Δ %+.3f | positive Holdouts %d/%d",
                         best.window,
                         best.holdout,
                         best.validation,
                         best.positiveHoldouts,
                         periodCount))
        }

        print(String(format: "⏱ Frequenz-Fenster-Stabilität: %.2f Sekunden",
                     Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeTicket(from draws: [EuroJackpotDraw], before index: Int, window: Int) -> Ticket {
        let source = Array(draws.prefix(index).suffix(window))
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
