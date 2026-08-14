//
//  FrequencyBaselineAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.5 - simple frequency baselines and window sweep
//
//  F1: entire training history.
//  F2: last 50 training draws.
//  F3: last 100 training draws.
//  F4: last 200 training draws.
//  F5: last 400 training draws.
//  F6: combined rank of 50- and 400-draw frequencies.
//  Sweep: 25, 50, 75, 100, 150, 200, 300, 400 draws.
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

        var averageMain: Double { tickets > 0 ? Double(hits) / Double(tickets) : 0 }
        var averageEuro: Double { tickets > 0 ? Double(euroHits) / Double(tickets) : 0 }
        var averageExpectedEuro: Double { tickets > 0 ? expectedEuroHits / Double(tickets) : 0 }
        var score: Double { (averageMain - 0.50) + (averageEuro - averageExpectedEuro) }
    }

    private struct SplitResult {
        let split: Int
        let validation: Aggregate
        let holdout: Aggregate
        let validationTicket: Ticket
        let holdoutTicket: Ticket
    }

    private struct SweepResult {
        let window: Int
        let validationScore: Double
        let holdoutScore: Double
    }

    private let warmup = WeightSweepCore.warmup
    private let windows: [(name: String, size: Int)] = [
        ("F1", 0), ("F2", 50), ("F3", 100), ("F4", 200), ("F5", 400), ("F6", -1)
    ]
    private let sweepWindows = [25, 50, 75, 100, 150, 200, 300, 400]

    func run(draws: [EuroJackpotDraw], splitCount: Int = 5) {
        guard draws.count > warmup + 20 else {
            print("❌ Frequenz-Baselines: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - warmup
        let requestedSplits = max(1, splitCount)
        let availableWindow = totalTests / requestedSplits
        var resultsByName: [String: [SplitResult]] = [:]

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
        print("F6                  : kombinierter Rang aus 50 + 400")
        print("Tie-Break           : kleinere Zahl zuerst")
        print("Profilwahl          : keine")
        print("Holdout             : erst nach der jeweiligen Auswahl")
        print("")

        for model in windows {
            var splitResults: [SplitResult] = []

            for split in 0..<requestedSplits {
                let validationStart = warmup + split * availableWindow
                let splitEnd = split == requestedSplits - 1 ? draws.count : min(draws.count, warmup + (split + 1) * availableWindow)
                let splitSize = splitEnd - validationStart
                guard splitSize >= 2 else { continue }

                let validationSize = splitSize / 2
                let holdoutStart = validationStart + validationSize
                var validation = Aggregate()
                var holdout = Aggregate()
                var validationTicket: Ticket?
                var holdoutTicket: Ticket?

                for index in validationStart..<holdoutStart {
                    let trainingDraws = Array(draws.prefix(index))
                    let target = draws[index]
                    let ticket = makeTicket(from: trainingDraws, model: model)
                    if validationTicket == nil { validationTicket = ticket }
                    add(ticket: ticket, target: target, to: &validation)
                }

                for index in holdoutStart..<splitEnd {
                    let trainingDraws = Array(draws.prefix(index))
                    let target = draws[index]
                    let ticket = makeTicket(from: trainingDraws, model: model)
                    if holdoutTicket == nil { holdoutTicket = ticket }
                    add(ticket: ticket, target: target, to: &holdout)
                }

                guard let validationTicket, let holdoutTicket else { continue }
                splitResults.append(SplitResult(split: split + 1, validation: validation, holdout: holdout, validationTicket: validationTicket, holdoutTicket: holdoutTicket))
            }
            resultsByName[model.name] = splitResults
        }

        print("-----------------------------------")
        print("SPLIT-ERGEBNISSE")
        print("-----------------------------------")
        for split in 1...requestedSplits {
            let values = windows.map { model -> String in
                guard let result = resultsByName[model.name]?.first(where: { $0.split == split }) else { return "\(model.name): n/a" }
                return String(format: "%@ Val %+.3f Hold %+.3f", model.name, result.validation.score, result.holdout.score)
            }
            print("Split \(split) | " + values.joined(separator: " | "))
        }

        print("")
        print("-----------------------------------")
        print("REPRÄSENTATIVE TICKETS")
        print("-----------------------------------")
        print("Je Split: erster Validation-Tipp und erster Holdout-Tipp")
        for split in 1...requestedSplits {
            print("Split \(split)")
            for modelName in ["F2", "F5", "F6"] {
                guard let result = resultsByName[modelName]?.first(where: { $0.split == split }) else { continue }
                print("  \(modelName) Val: \(format(ticket: result.validationTicket)) | Hold: \(format(ticket: result.holdoutTicket))")
            }
        }

        print("")
        print("-----------------------------------")
        print("GESAMTVERGLEICH")
        print("-----------------------------------")
        print("Modell    Val Haupt   Val Euro   Val Δ      Hold Haupt   Hold Euro   Hold Δ")
        for model in windows { printRow(name: model.name, results: resultsByName[model.name] ?? []) }

        runWindowSweep(draws: draws, splitCount: requestedSplits)

        print("")
        print("F1-F6 sind reine Kontrollmodelle: keine Gewichtung, keine Optimierung, keine Holdout-Information bei der Tippbildung.")
        print("Der Fenster-Sweep prüft feste, vorab definierte Fenster und wählt kein Fenster anhand des Holdouts aus.")
        print("Die Euro-Basis wird historisch korrekt über das Datum des jeweiligen Ziel-Los berücksichtigt.")
        print(String(format: "⏱ Frequenz-Fenstervergleich: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func runWindowSweep(draws: [EuroJackpotDraw], splitCount: Int) {
        var sweepResults: [SweepResult] = []
        let totalTests = draws.count - warmup
        let availableWindow = totalTests / splitCount

        for window in sweepWindows {
            var validationTotal = 0.0
            var holdoutTotal = 0.0
            var splitCountUsed = 0

            for split in 0..<splitCount {
                let validationStart = warmup + split * availableWindow
                let splitEnd = split == splitCount - 1 ? draws.count : min(draws.count, warmup + (split + 1) * availableWindow)
                let splitSize = splitEnd - validationStart
                guard splitSize >= 2 else { continue }

                let validationSize = splitSize / 2
                let holdoutStart = validationStart + validationSize
                var validation = Aggregate()
                var holdout = Aggregate()

                for index in validationStart..<holdoutStart {
                    let target = draws[index]
                    let ticket = makeFrequencyTicket(from: Array(draws.prefix(index)), window: window)
                    add(ticket: ticket, target: target, to: &validation)
                }
                for index in holdoutStart..<splitEnd {
                    let target = draws[index]
                    let ticket = makeFrequencyTicket(from: Array(draws.prefix(index)), window: window)
                    add(ticket: ticket, target: target, to: &holdout)
                }

                validationTotal += validation.score
                holdoutTotal += holdout.score
                splitCountUsed += 1
            }

            if splitCountUsed > 0 {
                sweepResults.append(SweepResult(window: window, validationScore: validationTotal / Double(splitCountUsed), holdoutScore: holdoutTotal / Double(splitCountUsed)))
            }
        }

        print("")
        print("-----------------------------------")
        print("FREQUENZ-FENSTER-SWEEP")
        print("-----------------------------------")
        print("Fenster   Val Δ      Hold Δ")
        for result in sweepResults {
            print(String(format: "%4d     %+.3f      %+.3f", result.window, result.validationScore, result.holdoutScore))
        }

        let sortedByHoldout = sweepResults.sorted {
            if $0.holdoutScore == $1.holdoutScore { return $0.window < $1.window }
            return $0.holdoutScore > $1.holdoutScore
        }
        print("")
        print("Top nach Holdout:")
        for result in sortedByHoldout.prefix(3) {
            print(String(format: "  %d Ziehungen: Hold Δ %+.3f | Val Δ %+.3f", result.window, result.holdoutScore, result.validationScore))
        }
    }

    private func makeTicket(from draws: [EuroJackpotDraw], model: (name: String, size: Int)) -> Ticket {
        if model.name == "F6" { return makeCombinedTicket(from: draws) }
        return makeFrequencyTicket(from: draws, window: model.size)
    }

    private func makeFrequencyTicket(from draws: [EuroJackpotDraw], window: Int) -> Ticket {
        let source = window > 0 ? Array(draws.suffix(window)) : draws
        let mainCounts = frequencyCounts(draws: source, keyPath: \.numbers)
        let euroCounts = frequencyCounts(draws: source, keyPath: \.euroNumbers)
        return makeTicket(mainCounts: mainCounts, euroCounts: euroCounts)
    }

    private func makeCombinedTicket(from draws: [EuroJackpotDraw]) -> Ticket {
        let shortMain = frequencyCounts(draws: Array(draws.suffix(50)), keyPath: \.numbers)
        let longMain = frequencyCounts(draws: Array(draws.suffix(400)), keyPath: \.numbers)
        let shortEuro = frequencyCounts(draws: Array(draws.suffix(50)), keyPath: \.euroNumbers)
        let longEuro = frequencyCounts(draws: Array(draws.suffix(400)), keyPath: \.euroNumbers)
        let numbers = combinedRanks(values: 1...50, shortCounts: shortMain, longCounts: longMain).prefix(5).sorted()
        let euroNumbers = combinedRanks(values: 1...12, shortCounts: shortEuro, longCounts: longEuro).prefix(2).sorted()
        return Ticket(numbers: Array(numbers), euroNumbers: Array(euroNumbers))
    }

    private func combinedRanks(values: ClosedRange<Int>, shortCounts: [Int: Int], longCounts: [Int: Int]) -> [Int] {
        let shortOrder = values.sorted { lhs, rhs in
            let left = shortCounts[lhs, default: 0], right = shortCounts[rhs, default: 0]
            return left == right ? lhs < rhs : left > right
        }
        let longOrder = values.sorted { lhs, rhs in
            let left = longCounts[lhs, default: 0], right = longCounts[rhs, default: 0]
            return left == right ? lhs < rhs : left > right
        }
        var shortRank: [Int: Int] = [:], longRank: [Int: Int] = [:]
        for (index, value) in shortOrder.enumerated() { shortRank[value] = index + 1 }
        for (index, value) in longOrder.enumerated() { longRank[value] = index + 1 }
        return values.sorted { lhs, rhs in
            let left = shortRank[lhs, default: Int.max] + longRank[lhs, default: Int.max]
            let right = shortRank[rhs, default: Int.max] + longRank[rhs, default: Int.max]
            return left == right ? lhs < rhs : left < right
        }
    }

    private func makeTicket(mainCounts: [Int: Int], euroCounts: [Int: Int]) -> Ticket {
        let numbers = (1...50).sorted { lhs, rhs in
            let left = mainCounts[lhs, default: 0], right = mainCounts[rhs, default: 0]
            return left == right ? lhs < rhs : left > right
        }.prefix(5).sorted()
        let euroNumbers = (1...12).sorted { lhs, rhs in
            let left = euroCounts[lhs, default: 0], right = euroCounts[rhs, default: 0]
            return left == right ? lhs < rhs : left > right
        }.prefix(2).sorted()
        return Ticket(numbers: Array(numbers), euroNumbers: Array(euroNumbers))
    }

    private func frequencyCounts(draws: [EuroJackpotDraw], keyPath: KeyPath<EuroJackpotDraw, [Int]>) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for draw in draws { for number in draw[keyPath: keyPath] { counts[number, default: 0] += 1 } }
        return counts
    }

    private func add(ticket: Ticket, target: EuroJackpotDraw, to aggregate: inout Aggregate) {
        aggregate.hits += Set(ticket.numbers).intersection(target.numbers).count
        aggregate.euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
        aggregate.tickets += 1
        aggregate.expectedEuroHits += WeightSweepCore.expectedEuroHits(for: target.date, ticketCount: 1)
    }

    private func format(ticket: Ticket) -> String {
        "\(ticket.numbers.map(String.init).joined(separator: ",")) + \(ticket.euroNumbers.map(String.init).joined(separator: ","))"
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

        print(String(format: "%-7@   %.3f       %.3f     %+.3f      %.3f        %.3f      %+.3f", name, valMain, valEuro, (valMain - 0.50) + (valEuro - valExpected), holdMain, holdEuro, (holdMain - 0.50) + (holdEuro - holdExpected)))
    }
}
