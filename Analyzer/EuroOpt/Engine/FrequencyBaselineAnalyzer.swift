//
//  FrequencyBaselineAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.5 - simple frequency baselines F1/F2
//
//  F1: entire training history.
//  F2: last 100 training draws.
//  Tie-break: smaller number first.
//  Validation and holdout use only information available before each target draw.
//

import Foundation

final class FrequencyBaselineAnalyzer {

    private struct Aggregate {
        var hits = 0
        var euroHits = 0
        var tickets = 0
        var expectedEuroHits = 0.0

        var averageMain: Double {
            tickets > 0 ? Double(hits) / Double(tickets) : 0
        }

        var averageEuro: Double {
            tickets > 0 ? Double(euroHits) / Double(tickets) : 0
        }

        var averageExpectedEuro: Double {
            tickets > 0 ? expectedEuroHits / Double(tickets) : 0
        }

        var score: Double {
            (averageMain - 0.50) + (averageEuro - averageExpectedEuro)
        }
    }

    private struct SplitResult {
        let split: Int
        let validation: Aggregate
        let holdout: Aggregate
    }

    private let warmup = WeightSweepCore.warmup
    private let recentWindow = 100

    func run(draws: [EuroJackpotDraw], splitCount: Int = 5) {
        guard draws.count > warmup + 20 else {
            print("❌ Frequenz-Baselines: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - warmup
        let requestedSplits = max(1, splitCount)
        let availableWindow = totalTests / requestedSplits
        var f1Results: [SplitResult] = []
        var f2Results: [SplitResult] = []

        print("")
        print("===================================")
        print("📊 F1 / F2 FREQUENZ-BASIS")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Splits              : \(requestedSplits)")
        print("F1                  : gesamte Trainingshistorie")
        print("F2                  : letzte \(recentWindow) Trainingsziehungen")
        print("Tie-Break           : kleinere Zahl zuerst")
        print("Profilwahl          : keine")
        print("Holdout             : erst nach der jeweiligen Auswahl")
        print("")

        for split in 0..<requestedSplits {
            let validationStart = warmup + split * availableWindow
            let splitEnd = split == requestedSplits - 1
                ? draws.count
                : min(draws.count, warmup + (split + 1) * availableWindow)
            let splitSize = splitEnd - validationStart
            guard splitSize >= 2 else { continue }

            let validationSize = splitSize / 2
            let holdoutStart = validationStart + validationSize

            var f1Validation = Aggregate()
            var f2Validation = Aggregate()
            var f1Holdout = Aggregate()
            var f2Holdout = Aggregate()

            for index in validationStart..<holdoutStart {
                let trainingDraws = Array(draws.prefix(index))
                let target = draws[index]
                let f1 = makeTicket(from: trainingDraws)
                let f2 = makeTicket(from: Array(trainingDraws.suffix(recentWindow)))

                add(ticket: f1, target: target, to: &f1Validation)
                add(ticket: f2, target: target, to: &f2Validation)
            }

            for index in holdoutStart..<splitEnd {
                let trainingDraws = Array(draws.prefix(index))
                let target = draws[index]
                let f1 = makeTicket(from: trainingDraws)
                let f2 = makeTicket(from: Array(trainingDraws.suffix(recentWindow)))

                add(ticket: f1, target: target, to: &f1Holdout)
                add(ticket: f2, target: target, to: &f2Holdout)
            }

            f1Results.append(SplitResult(split: split + 1, validation: f1Validation, holdout: f1Holdout))
            f2Results.append(SplitResult(split: split + 1, validation: f2Validation, holdout: f2Holdout))
        }

        print("-----------------------------------")
        print("SPLIT-ERGEBNISSE")
        print("-----------------------------------")
        for index in 0..<min(f1Results.count, f2Results.count) {
            let f1 = f1Results[index]
            let f2 = f2Results[index]
            print(String(format: "Split %d | F1  Val %+.3f  Hold %+.3f | F2  Val %+.3f  Hold %+.3f",
                         f1.split,
                         f1.validation.score,
                         f1.holdout.score,
                         f2.validation.score,
                         f2.holdout.score))
        }

        print("")
        print("-----------------------------------")
        print("GESAMTVERGLEICH")
        print("-----------------------------------")
        print("Modell    Val Haupt   Val Euro   Val Δ      Hold Haupt   Hold Euro   Hold Δ")
        printRow(name: "F1", results: f1Results)
        printRow(name: "F2", results: f2Results)

        print("")
        print("F1/F2 sind reine Kontrollmodelle: keine Gewichtung, keine Optimierung, keine Holdout-Information bei der Tippbildung.")
        print("Die Euro-Basis wird historisch korrekt über das Datum des jeweiligen Ziel-Los berücksichtigt.")
        print(String(format: "⏱ Frequenz-Baselines: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeTicket(from draws: [EuroJackpotDraw]) -> Ticket {
        let mainCounts = frequencyCounts(draws: draws, keyPath: \.numbers)
        let euroCounts = frequencyCounts(draws: draws, keyPath: \.euroNumbers)

        let numbers = (1...50)
            .sorted { lhs, rhs in
                let left = mainCounts[lhs, default: 0]
                let right = mainCounts[rhs, default: 0]
                return left == right ? lhs < rhs : left > right
            }
            .prefix(5)
            .sorted()

        let euroNumbers = (1...12)
            .sorted { lhs, rhs in
                let left = euroCounts[lhs, default: 0]
                let right = euroCounts[rhs, default: 0]
                return left == right ? lhs < rhs : left > right
            }
            .prefix(2)
            .sorted()

        return Ticket(numbers: Array(numbers), euroNumbers: Array(euroNumbers))
    }

    private func frequencyCounts(draws: [EuroJackpotDraw], keyPath: KeyPath<EuroJackpotDraw, [Int]>) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for draw in draws {
            for number in draw[keyPath: keyPath] {
                counts[number, default: 0] += 1
            }
        }
        return counts
    }

    private func add(ticket: Ticket, target: EuroJackpotDraw, to aggregate: inout Aggregate) {
        aggregate.hits += Set(ticket.numbers).intersection(target.numbers).count
        aggregate.euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
        aggregate.tickets += 1
        aggregate.expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: 1)
    }

    private func printRow(name: String, results: [SplitResult]) {
        let validationTickets = results.reduce(0) { $0 + $1.validation.tickets }
        let holdoutTickets = results.reduce(0) { $0 + $1.holdout.tickets }
        let validationHits = results.reduce(0) { $0 + $1.validation.hits }
        let validationEuro = results.reduce(0) { $0 + $1.validation.euroHits }
        let validationExpectedEuro = results.reduce(0.0) { $0 + $1.validation.expectedEuroHits }
        let holdoutHits = results.reduce(0) { $0 + $1.holdout.hits }
        let holdoutEuro = results.reduce(0) { $0 + $1.holdout.euroHits }
        let holdoutExpectedEuro = results.reduce(0.0) { $0 + $1.holdout.expectedEuroHits }

        let valMain = validationTickets > 0 ? Double(validationHits) / Double(validationTickets) : 0
        let valEuro = validationTickets > 0 ? Double(validationEuro) / Double(validationTickets) : 0
        let valExpected = validationTickets > 0 ? validationExpectedEuro / Double(validationTickets) : 0
        let holdMain = holdoutTickets > 0 ? Double(holdoutHits) / Double(holdoutTickets) : 0
        let holdEuro = holdoutTickets > 0 ? Double(holdoutEuro) / Double(holdoutTickets) : 0
        let holdExpected = holdoutTickets > 0 ? holdoutExpectedEuro / Double(holdoutTickets) : 0

        print(String(format: "%-7@   %.3f       %.3f     %+.3f      %.3f        %.3f      %+.3f",
                     name,
                     valMain,
                     valEuro,
                     (valMain - 0.50) + (valEuro - valExpected),
                     holdMain,
                     holdEuro,
                     (holdMain - 0.50) + (holdEuro - holdExpected)))
    }
}
