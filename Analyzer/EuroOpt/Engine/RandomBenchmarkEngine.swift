//
//  RandomBenchmarkEngine.swift
//  EuroOpt
//
//  Alpha 7.5 - empirical random benchmark for holdout comparison
//

import Foundation

final class RandomBenchmarkEngine {

    private let monteCarloRuns = 50
    private let candidateCountMinimum = 301

    func run(draws: [EuroJackpotDraw], recommendationCount: Int) {
        guard draws.count > 140 else {
            print("❌ Zufallsbenchmark: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let holdoutCount = draws.count - holdoutStart
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)

        var runMainAverages: [Double] = []
        var runEuroAverages: [Double] = []
        runMainAverages.reserveCapacity(monteCarloRuns)
        runEuroAverages.reserveCapacity(monteCarloRuns)

        print("")
        print("===================================")
        print("🎲 EMPIRISCHER ZUFALLSBENCHMARK")
        print("===================================")
        print("Getestete Ziehungen : \(holdoutCount)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Monte-Carlo-Läufe   : \(monteCarloRuns)")
        print("Validation          : nicht verwendet")
        print("Gewichte / EQI      : nicht verwendet")
        print("Diversitätsregel    : maximal 2 gemeinsame Hauptzahlen")
        print("Euro-Basis          : 10 bis 24.03.2022 / 12 ab 25.03.2022")
        print("")
        print("🔒 Benchmark nutzt exakt dasselbe Holdout-Zeitfenster wie Alpha 7.5.")
        print("🔒 Zufallstipps werden nach denselben Hauptzahl-Regeln validiert.")
        print("")

        for run in 0..<monteCarloRuns {
            let rng = SeededRandomGenerator(seed: 0xE7A7_7500 &+ UInt64(run))
            var totalHits = 0
            var totalEuroHits = 0
            var totalTickets = 0

            for index in holdoutStart..<draws.count {
                let targetDraw = draws[index]
                let candidates = generateCandidates(
                    count: candidateCount,
                    euroMaximum: targetDraw.date < euroFormatCutoverDate() ? 10 : 12,
                    rng: rng
                )
                let selected = selectRandomDiversifiedTickets(
                    candidates: candidates,
                    limit: recommendationCount,
                    rng: rng
                )

                for ticket in selected {
                    totalHits += Set(ticket.numbers).intersection(targetDraw.numbers).count
                    totalEuroHits += Set(ticket.euroNumbers).intersection(targetDraw.euroNumbers).count
                    totalTickets += 1
                }
            }

            guard totalTickets > 0 else { continue }
            runMainAverages.append(Double(totalHits) / Double(totalTickets))
            runEuroAverages.append(Double(totalEuroHits) / Double(totalTickets))

            if (run + 1).isMultiple(of: 5) || run == monteCarloRuns - 1 {
                print("... Monte-Carlo \(run + 1) / \(monteCarloRuns)")
            }
        }

        let mainAverage = mean(runMainAverages)
        let euroAverage = mean(runEuroAverages)
        let mainSD = standardDeviation(runMainAverages)
        let euroSD = standardDeviation(runEuroAverages)
        let mainCI = 1.96 * mainSD / sqrt(Double(max(runMainAverages.count, 1)))
        let euroCI = 1.96 * euroSD / sqrt(Double(max(runEuroAverages.count, 1)))

        let theoreticalMain = 0.50
        let theoreticalEuro = weightedHistoricalEuroExpectation(
            draws: Array(draws[holdoutStart..<draws.count])
        )

        print("")
        print("===================================")
        print("🎲 ZUFALLSBENCHMARK – ERGEBNIS")
        print("===================================")
        print(String(format: "Ø Haupttreffer      : %.4f", mainAverage))
        print(String(format: "Ø Eurotreffer       : %.4f", euroAverage))
        print(String(format: "95%% CI Haupt        : ±%.4f", mainCI))
        print(String(format: "95%% CI Euro         : ±%.4f", euroCI))
        print(String(format: "Theorie Haupt       : %.4f", theoreticalMain))
        print(String(format: "Theorie Euro        : %.4f", theoreticalEuro))
        print(String(format: "Δ Haupt vs Theorie  : %+.4f", mainAverage - theoreticalMain))
        print(String(format: "Δ Euro vs Theorie   : %+.4f", euroAverage - theoreticalEuro))
        print("")
        print("Wichtig:")
        print("- Keine EQI-Komponente wird verwendet.")
        print("- Keine historischen Treffer werden zur Tippauswahl verwendet.")
        print("- Kandidatenanzahl, Tippanzahl und Diversitätsregel entsprechen dem Holdout-Test.")
        print("- Die Eurozahlen verwenden das historische 10/12-Format.")
        print("- Die Monte-Carlo-Läufe sind reproduzierbar, aber voneinander unabhängig erzeugt.")
        print("")
        print(String(format: "⏱ Zufallsbenchmark: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func generateCandidates(
        count: Int,
        euroMaximum: Int,
        rng: SeededRandomGenerator
    ) -> [Ticket] {
        var candidates: [Ticket] = []
        candidates.reserveCapacity(count)

        while candidates.count < count {
            let ticket = rng.makeTicket(euroMaximum: euroMaximum)
            if isValid(ticket: ticket) {
                candidates.append(ticket)
            }
        }

        return candidates
    }

    private func selectRandomDiversifiedTickets(
        candidates: [Ticket],
        limit: Int,
        rng: SeededRandomGenerator
    ) -> [Ticket] {
        var shuffled = candidates
        rng.shuffle(&shuffled)

        var result: [Ticket] = []
        result.reserveCapacity(limit)

        for candidate in shuffled {
            var different = true
            for existing in result {
                if commonNumbers(existing, candidate) >= 3 {
                    different = false
                    break
                }
            }

            if different {
                result.append(candidate)
                if result.count == limit {
                    break
                }
            }
        }

        return result
    }

    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        lhs.numbers.reduce(0) { count, number in
            count + (rhs.numbers.contains(number) ? 1 : 0)
        }
    }

    private func isValid(ticket: Ticket) -> Bool {
        let numbers = ticket.numbers
        var even = 0
        var high = 0
        var sum = 0
        var consecutive = 1
        var smallGaps = 0

        for i in numbers.indices {
            let value = numbers[i]
            sum += value

            if value.isMultiple(of: 2) { even += 1 }
            if value > 25 { high += 1 }

            if i > 0 {
                let gap = value - numbers[i - 1]

                if gap == 1 {
                    consecutive += 1
                    if consecutive > AppSettings.maximumConsecutiveNumbers {
                        return false
                    }
                } else {
                    consecutive = 1
                }

                if gap <= 2 { smallGaps += 1 }
            }
        }

        guard even >= AppSettings.minimumEvenNumbers &&
              even <= AppSettings.maximumEvenNumbers else { return false }

        guard high >= AppSettings.minimumHighNumbers &&
              high <= AppSettings.maximumHighNumbers else { return false }

        guard sum >= AppSettings.minimumSum &&
              sum <= AppSettings.maximumSum else { return false }

        guard smallGaps <= AppSettings.maximumSmallGaps else { return false }

        return true
    }

    private func weightedHistoricalEuroExpectation(draws: [EuroJackpotDraw]) -> Double {
        guard !draws.isEmpty else { return 0 }
        let total = draws.reduce(0.0) { partial, draw in
            partial + (draw.date < euroFormatCutoverDate() ? 0.400 : (1.0 / 3.0))
        }
        return total / Double(draws.count)
    }

    private func euroFormatCutoverDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2022, month: 3, day: 25))!
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let average = mean(values)
        let variance = values.reduce(0.0) { partial, value in
            let delta = value - average
            return partial + delta * delta
        } / Double(values.count - 1)
        return sqrt(variance)
    }
}

private final class SeededRandomGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    private func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    private func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }

    func shuffle<T>(_ values: inout [T]) {
        guard values.count > 1 else { return }
        for index in stride(from: values.count - 1, through: 1, by: -1) {
            let swapIndex = nextInt(upperBound: index + 1)
            values.swapAt(index, swapIndex)
        }
    }

    func makeTicket(euroMaximum: Int) -> Ticket {
        var numbers = Array(1...50)
        var euroNumbers = Array(1...euroMaximum)
        shuffle(&numbers)
        shuffle(&euroNumbers)

        return Ticket(
            numbers: Array(numbers.prefix(5)).sorted(),
            euroNumbers: Array(euroNumbers.prefix(2)).sorted()
        )
    }
}
