//
//  FrequencyBaselineAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.5 - simple frequency baselines F1/F2/F3/F4/F5
//
//  F1: entire training history.
//  F2: last 50 training draws.
//  F3: last 100 training draws.
//  F4: last 200 training draws.
//  F5: last 400 training draws.
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
    private let windows = [50, 100, 200, 400]

    func run(draws: [EuroJackpotDraw], splitCount: Int = 5) {
        guard draws.count > warmup + 20 else {
            print("❌ Frequenz-Baselines: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - warmup
        let requestedSplits = max(1, splitCount)
        let availableWindow = totalTests / requestedSplits
        var resultsByWindow: [Int: [SplitResult]] = [:]

        print("")
        print("===================================")
        print("📊 FREQUENZ-BASIS: FENSTER-VERGLEICH")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Splits              : \(requestedSplits)")
        print("F1                  : gesamte Trainingshistorie")
        print("F2                  : letzte 50 Trainingsziehungen")
        print("F3                  : letzte 100 Trainingsziehungen")
        print("F4                  : letzte 200 Trainingsziehungen")
        print("F5                  : letzte 400 Trainingsziehungen")
        print("Tie-Break           : kleinere Zahl zuerst")
        print("Profilwahl          : keine")
        print("Holdout             : erst nach der jeweiligen Auswahl")
        print("")

        for window in windows {
            var splitResults: [SplitResult] = []

            for split in 0..<requestedSplits {
                let validationStart = warmup + split * availableWindow
                let splitEnd = split == requestedSplits - 1
                    ? draws.count
                    : min(draws.count, warmup + (split + 1) * availableWindow)
                let splitSize = splitEnd - validationStart
                guard splitSize >= 2 else { continue }

                let validationSize = splitSize / 2
                let holdoutStart = validationStart + validationSize
                var validation = Aggregate()
                var holdout = Aggregate()

                for index in validationStart..<holdoutStart {
                    let trainingDraws = Array(draws.prefix(index))
                    let target = draws[index]
                    let ticket = makeTicket(from: trainingDraws, window: window)
                    add(ticket: ticket, target: target, to: &validation)
                }

                for index in holdoutStart..<splitEnd {
                    let trainingDraws = Array(draws.prefix(index))
                    let target = draws[index]
                    let ticket = makeTicket(from: trainingDraws, window: window)
                    add(ticket: ticket, target: target, to: &holdout)
                }

                splitResults.append(SplitResult(split: split + 1, validation: validation, holdout: holdout))
            }

            resultsByWindow[window] = splitResults
        }

        print("-----------------------------------")
        print("SPLIT-ERGEBNISSE")
        print("-----------------------------------")
        for split in 1...requestedSplits {
            let values = windows.map { window -> String in
                guard let result = resultsByWindow[window]?.first(where: { $0.split == split }) else {
                    return "F\(window): n/a"
                }
                return String(format: "F%d Val %+.3f Hold %+.3f", window == 50 ? 2 : window == 100 ? 3 : window == 200 ? 4 : 5, result.validation.score, result.holdout.score)
            }
            print("Split \(split) | " + values.joined(separator: " | "))
        }

        print("")
        print("-----------------------------------")
        print("GESAMTVERGLEICH")
        print("-----------------------------------")
        print("Modell    Val Haupt   Val Euro   Val Δ      Hold Haupt   Hold Euro   Hold Δ")
        printRow(name: "F1", results: resultsByWindow[50] ?? [])
        printRow(name: "F2", results: resultsByWindow[50] ?? [])
        printRow(name: "F3", results: resultsByWindow[100] ?? [])
        printRow(name: "F4", results: resultsByWindow[200] ?? [])
        printRow(name: "F5", results: resultsByWindow[400] ?? [])

        print("")
        print("F1/F2/F3/F4/F5 sind reine Kontrollmodelle: keine Gewichtung, keine Optimierung, keine Holdout-Information bei der Tippbildung.")
        print("Die Euro-Basis wird historisch korrekt über das Datum des jeweiligen Ziel-Los berücksichtigt.")
        print(String(format: "⏱ Frequenz-Fenstervergleich: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeTicket(from draws: [EuroJackpotDraw], window: Int) -> Ticket {
        let source = Array(draws.suffix(window))
        let mainCounts = frequencyCounts(draws: source, keyPath: \.numbers)
        let euroCounts = frequencyCounts(draws: source, keyPath: \.euroNumbers)

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
