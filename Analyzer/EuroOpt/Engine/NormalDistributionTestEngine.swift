//
//  NormalDistributionTestEngine.swift
//  EuroOpt
//
//  Isolated normal-distribution experiment for Alpha 7.5.
//  Alpha 7.5 itself is not modified.
//

import Foundation

final class NormalDistributionTestEngine {

    private let candidateCountMinimum = 301

    func run(draws: [EuroJackpotDraw], recommendationCount: Int) {
        guard draws.count > 140 else {
            print("❌ Normalverteilungstest: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let holdoutCount = draws.count - holdoutStart
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)

        let theoreticalMean = 127.5
        let theoreticalSD = 30.9232921921

        print("")
        print("===================================")
        print("📐 NORMALVERTEILUNG – ISOLIERTER TEST")
        print("===================================")
        print("Gesamte Ziehungen   : \(totalTests)")
        print("Validation          : \(validationTests)")
        print("Holdout             : \(holdoutCount)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Normalvariable      : Summe der 5 Hauptzahlen")
        print(String(format: "Theorie Mittelwert  : %.3f", theoreticalMean))
        print(String(format: "Theorie Standardabw. : %.3f", theoreticalSD))
        print("")
        print("🔒 Alpha 7.5 bleibt unverändert.")
        print("🔒 Keine EQI-Komponenten und keine Gewichte.")
        print("🔒 Keine historischen Treffer zur Auswahl.")
        print("🔒 Das Normalverteilungskriterium ist fest definiert.")
        print("")

        let historical = summarize(draws: draws, range: 100..<draws.count)
        print("-----------------------------------")
        print("HISTORISCHE SUMMENVERTEILUNG")
        print("-----------------------------------")
        print(String(format: "Ø Summe            : %.3f", historical.mean))
        print(String(format: "Standardabw.       : %.3f", historical.standardDeviation))
        print(String(format: "Abweichung zum Theorie-Mittel: %+.3f", historical.mean - theoreticalMean))
        print("")

        let validation = evaluate(
            draws: draws,
            range: 100..<holdoutStart,
            candidateCount: candidateCount,
            recommendationCount: recommendationCount,
            theoreticalMean: theoreticalMean,
            theoreticalSD: theoreticalSD
        )

        print("-----------------------------------")
        print("VALIDATION – NORMALVERTEILUNG")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.4f", validation.mainAverage))
        print(String(format: "Ø Eurotreffer       : %.4f", validation.euroAverage))
        print(String(format: "Δ Haupt vs Theorie : %+.4f", validation.mainAverage - 0.5))
        print(String(format: "Δ Euro vs Theorie  : %+.4f", validation.euroAverage - validation.euroExpected))
        print("")

        let holdout = evaluate(
            draws: draws,
            range: holdoutStart..<draws.count,
            candidateCount: candidateCount,
            recommendationCount: recommendationCount,
            theoreticalMean: theoreticalMean,
            theoreticalSD: theoreticalSD
        )

        print("===================================")
        print("🧪 NORMALVERTEILUNG – HOLDOUT")
        print("===================================")
        print("Normal-Kriterium    : Summe ~ N(127.5, 30.923²)")
        print(String(format: "Ø Haupttreffer      : %.4f", holdout.mainAverage))
        print(String(format: "Ø Eurotreffer       : %.4f", holdout.euroAverage))
        print(String(format: "Ø Euro-Basis        : %.4f", holdout.euroExpected))
        print(String(format: "Δ Haupt vs Theorie : %+.4f", holdout.mainAverage - 0.5))
        print(String(format: "Δ Euro vs Theorie  : %+.4f", holdout.euroAverage - holdout.euroExpected))
        print(String(format: "Kombinierter Δ      : %+.4f", (holdout.mainAverage - 0.5) + (holdout.euroAverage - holdout.euroExpected)))
        print("")
        print("Interpretation:")
        print("- Das Kriterium wurde nicht aus dem Holdout gelernt.")
        print("- Es verändert Alpha 7.5 nicht.")
        print("- Ein positiver Holdout-Wert allein beweist keinen echten Vorteil.")
        print("- Anschließend folgt automatisch der gepaarte empirische Zufallsbenchmark auf exakt demselben Holdout.")
        print("")
        print(String(format: "⏱ Normalverteilungstest: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")

        // Der zweite Schritt ist bewusst automatisch: gleicher Holdout,
        // festes Normal-Kriterium, keine erneute Optimierung.
        NormalDistributionBenchmarkEngine().run(
            draws: draws,
            recommendationCount: recommendationCount
        )
    }

    private struct Result {
        var mainHits = 0
        var euroHits = 0
        var tickets = 0
        var expectedEuro = 0.0

        var mainAverage: Double {
            tickets > 0 ? Double(mainHits) / Double(tickets) : 0
        }

        var euroAverage: Double {
            tickets > 0 ? Double(euroHits) / Double(tickets) : 0
        }

        var euroExpected: Double {
            tickets > 0 ? expectedEuro / Double(tickets) : 0
        }
    }

    private struct DistributionSummary {
        let mean: Double
        let standardDeviation: Double
    }

    private func evaluate(
        draws: [EuroJackpotDraw],
        range: Range<Int>,
        candidateCount: Int,
        recommendationCount: Int,
        theoreticalMean: Double,
        theoreticalSD: Double
    ) -> Result {
        let generator = TicketGenerator()
        var result = Result()

        for index in range {
            let trainingDraws = Array(draws.prefix(index))
            let target = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            let selected = candidates
                .sorted { normalScore(for: $0, mean: theoreticalMean, standardDeviation: theoreticalSD) > normalScore(for: $1, mean: theoreticalMean, standardDeviation: theoreticalSD) }
                .reduce(into: [Ticket]()) { selected, ticket in
                    guard selected.count < recommendationCount else { return }
                    guard selected.allSatisfy({ commonNumbers($0, ticket) < 3 }) else { return }
                    selected.append(ticket)
                }

            for ticket in selected {
                result.mainHits += commonHitCount(ticket.numbers, target.numbers)
                result.euroHits += commonHitCount(ticket.euroNumbers, target.euroNumbers)
                result.tickets += 1
                result.expectedEuro += expectedEuroHits(for: target.date)
            }

            if (index - range.lowerBound + 1).isMultiple(of: 50) {
                print("... Normaltest \(index - range.lowerBound + 1) / \(range.count)")
            }
        }

        return result
    }

    private func normalScore(for ticket: Ticket, mean: Double, standardDeviation: Double) -> Double {
        let sum = Double(ticket.numbers.reduce(0, +))
        let z = (sum - mean) / standardDeviation
        return exp(-0.5 * z * z)
    }

    private func summarize(draws: [EuroJackpotDraw], range: Range<Int>) -> DistributionSummary {
        let values = range.map { Double(draws[$0].numbers.reduce(0, +)) }
        guard values.count > 1 else { return DistributionSummary(mean: 0, standardDeviation: 0) }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0.0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Double(values.count - 1)
        return DistributionSummary(mean: mean, standardDeviation: sqrt(variance))
    }

    @inline(__always)
    private func commonHitCount(_ lhs: [Int], _ rhs: [Int]) -> Int {
        var count = 0
        for value in lhs where rhs.contains(value) {
            count += 1
        }
        return count
    }

    @inline(__always)
    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        commonHitCount(lhs.numbers, rhs.numbers)
    }

    private func expectedEuroHits(for date: Date) -> Double {
        date < euroFormatCutoverDate() ? 0.400 : (1.0 / 3.0)
    }

    private func euroFormatCutoverDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2022, month: 3, day: 25))!
    }
}
