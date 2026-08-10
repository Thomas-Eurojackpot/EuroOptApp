//
//  NormalDistributionBenchmarkEngine.swift
//  EuroOpt
//
//  Paired empirical benchmark for the isolated normal-distribution criterion.
//  Alpha 7.5 remains untouched.
//

import Foundation

final class NormalDistributionBenchmarkEngine {

    private let monteCarloRuns = 50
    private let candidateCountMinimum = 301
    private let theoreticalMean = 127.5
    private let theoreticalSD = 30.9232921921

    private struct TestCase {
        let candidates: [Ticket]
        let normalSelection: [Ticket]
        let target: EuroJackpotDraw
    }

    func run(draws: [EuroJackpotDraw], recommendationCount: Int) {
        guard draws.count > 140 else {
            print("❌ Normal-Benchmark: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let holdoutCount = draws.count - holdoutStart
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)

        print("")
        print("===================================")
        print("📐 NORMALVERTEILUNG – ZUFALLSBENCHMARK")
        print("===================================")
        print("Kriterium           : Summe ~ N(127.5, 30.923²)")
        print("Holdout-Ziehungen   : \(holdoutCount)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Monte-Carlo-Läufe   : \(monteCarloRuns)")
        print("Validation          : NICHT verwendet")
        print("Gewichte / EQI      : nicht verwendet")
        print("Diversitätsregel    : maximal 2 gemeinsame Hauptzahlen")
        print("Euro-Basis          : 10 bis 24.03.2022 / 12 ab 25.03.2022")
        print("")
        print("🔒 Normal-Kriterium ist vorher festgelegt und wird nicht optimiert.")
        print("🔒 Modell und Zufall verwenden für jede Ziehung denselben Kandidatenpool.")
        print("🔒 Der Holdout wird weder zur Auswahl des Kriteriums noch der Kandidaten verwendet.")
        print("")

        let generator = TicketGenerator()
        var cases: [TestCase] = []
        cases.reserveCapacity(holdoutCount)

        for index in holdoutStart..<draws.count {
            let trainingDraws = Array(draws.prefix(index))
            let target = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )
            let normalSelection = selectNormal(candidates: candidates, limit: recommendationCount)
            cases.append(TestCase(candidates: candidates, normalSelection: normalSelection, target: target))

            let current = index - holdoutStart + 1
            if current.isMultiple(of: 50) {
                print("... Kandidaten/Modell \(current) / \(holdoutCount)")
            }
        }

        guard !cases.isEmpty else {
            print("❌ Normal-Benchmark: kein Holdout vorhanden")
            return
        }

        let model = aggregateModel(cases: cases)

        var mainDeltas: [Double] = []
        var euroDeltas: [Double] = []
        var combinedDeltas: [Double] = []
        mainDeltas.reserveCapacity(monteCarloRuns)
        euroDeltas.reserveCapacity(monteCarloRuns)
        combinedDeltas.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {
            let rng = SeededRandomGenerator(seed: 0x4E4F524D_0000_7500 &+ UInt64(run))
            let random = aggregateRandom(cases: cases, recommendationCount: recommendationCount, rng: rng)

            let mainDelta = model.mainAverage - random.mainAverage
            let euroDelta = model.euroAverage - random.euroAverage
            mainDeltas.append(mainDelta)
            euroDeltas.append(euroDelta)
            combinedDeltas.append(mainDelta + euroDelta)

            if (run + 1).isMultiple(of: 5) || run == monteCarloRuns - 1 {
                print("... Monte-Carlo \(run + 1) / \(monteCarloRuns)")
            }
        }

        let mainMean = mean(mainDeltas)
        let euroMean = mean(euroDeltas)
        let combinedMean = mean(combinedDeltas)
        let mainCI = confidenceInterval(mainDeltas)
        let euroCI = confidenceInterval(euroDeltas)
        let combinedCI = confidenceInterval(combinedDeltas)
        let randomMain = model.mainAverage - mainMean
        let randomEuro = model.euroAverage - euroMean
        let euroBasis = weightedHistoricalEuroExpectation(cases: cases)

        print("")
        print("===================================")
        print("🎲 NORMALVERTEILUNG – FIXED HOLDOUT BENCHMARK")
        print("===================================")
        print("Kriterium vorher festgelegt: JA")
        print("Kriterium im Test verändert: NEIN")
        print("")
        print(String(format: "Ø Normal-Modell Haupt : %.4f", model.mainAverage))
        print(String(format: "Ø Zufall Haupt        : %.4f", randomMain))
        print(String(format: "Δ Modell - Zufall     : %+.4f", mainMean))
        print(String(format: "95%% CI Δ Haupt        : ±%.4f", mainCI))
        print("")
        print(String(format: "Ø Normal-Modell Euro  : %.4f", model.euroAverage))
        print(String(format: "Ø Zufall Euro         : %.4f", randomEuro))
        print(String(format: "Δ Modell - Zufall     : %+.4f", euroMean))
        print(String(format: "95%% CI Δ Euro         : ±%.4f", euroCI))
        print("")
        print(String(format: "Δ kombiniert          : %+.4f", combinedMean))
        print(String(format: "95%% CI Δ kombiniert   : ±%.4f", combinedCI))
        print("")
        print(String(format: "Ø Euro-Basis          : %.4f", euroBasis))
        print("")
        print("Statistik:")
        print("- Gepaarter Vergleich über exakt dasselbe Alpha-7.5-Holdout-Zeitfenster.")
        print("- Für jede Ziehung verwenden Modell und Zufall denselben Kandidatenpool.")
        print("- Zufall wählt nur die Empfehlungen zufällig und verwendet kein Normal-Kriterium.")
        print("- Keine EQI-Komponenten, keine Gewichte und keine historischen Treffer zur Auswahl.")
        print("- 95-%-KI basiert auf 50 unabhängigen Monte-Carlo-Replikationen.")
        print("- Ein KI, das 0 nicht einschließt, wäre ein Hinweis auf einen stabilen Unterschied.")
        print("")
        print(String(format: "⏱ Normalverteilungs-Benchmark: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private struct Aggregate {
        var mainHits = 0
        var euroHits = 0
        var tickets = 0

        var mainAverage: Double { tickets > 0 ? Double(mainHits) / Double(tickets) : 0 }
        var euroAverage: Double { tickets > 0 ? Double(euroHits) / Double(tickets) : 0 }
    }

    private func aggregateModel(cases: [TestCase]) -> Aggregate {
        var result = Aggregate()
        for testCase in cases {
            for ticket in testCase.normalSelection {
                result.mainHits += commonHitCount(ticket.numbers, testCase.target.numbers)
                result.euroHits += commonHitCount(ticket.euroNumbers, testCase.target.euroNumbers)
                result.tickets += 1
            }
        }
        return result
    }

    private func aggregateRandom(
        cases: [TestCase],
        recommendationCount: Int,
        rng: SeededRandomGenerator
    ) -> Aggregate {
        var result = Aggregate()
        for testCase in cases {
            let selected = selectRandomDiversified(
                candidates: testCase.candidates,
                limit: recommendationCount,
                rng: rng
            )
            for ticket in selected {
                result.mainHits += commonHitCount(ticket.numbers, testCase.target.numbers)
                result.euroHits += commonHitCount(ticket.euroNumbers, testCase.target.euroNumbers)
                result.tickets += 1
            }
        }
        return result
    }

    private func selectNormal(candidates: [Ticket], limit: Int) -> [Ticket] {
        candidates
            .sorted { normalScore(for: $0) > normalScore(for: $1) }
            .reduce(into: [Ticket]()) { selected, ticket in
                guard selected.count < limit else { return }
                guard selected.allSatisfy({ commonNumbers($0, ticket) < 3 }) else { return }
                selected.append(ticket)
            }
    }

    private func selectRandomDiversified(
        candidates: [Ticket],
        limit: Int,
        rng: SeededRandomGenerator
    ) -> [Ticket] {
        guard !candidates.isEmpty, limit > 0 else { return [] }
        var order = Array(0..<candidates.count)
        var selected: [Ticket] = []
        selected.reserveCapacity(limit)
        var scan = 0

        while scan < order.count && selected.count < limit {
            let remaining = order.count - scan
            let pick = scan + rng.nextInt(upperBound: remaining)
            order.swapAt(scan, pick)
            let candidate = candidates[order[scan]]
            scan += 1

            if selected.allSatisfy({ commonNumbers($0, candidate) < 3 }) {
                selected.append(candidate)
            }
        }
        return selected
    }

    private func normalScore(for ticket: Ticket) -> Double {
        let sum = Double(ticket.numbers.reduce(0, +))
        let z = (sum - theoreticalMean) / theoreticalSD
        return exp(-0.5 * z * z)
    }

    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        commonHitCount(lhs.numbers, rhs.numbers)
    }

    private func commonHitCount(_ lhs: [Int], _ rhs: [Int]) -> Int {
        var count = 0
        for value in lhs where rhs.contains(value) { count += 1 }
        return count
    }

    private func weightedHistoricalEuroExpectation(cases: [TestCase]) -> Double {
        let values = cases.map { $0.target.date < euroFormatCutoverDate() ? 0.400 : (1.0 / 3.0) }
        return values.reduce(0, +) / Double(values.count)
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func confidenceInterval(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let average = mean(values)
        let variance = values.reduce(0.0) { partial, value in
            let delta = value - average
            return partial + delta * delta
        } / Double(values.count - 1)
        let sd = sqrt(variance)
        return 2.0096 * sd / sqrt(Double(values.count))
    }

    private func euroFormatCutoverDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2022, month: 3, day: 25))!
    }
}

private final class SeededRandomGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    @inline(__always)
    func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    @inline(__always)
    func nextInt(upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }
}
