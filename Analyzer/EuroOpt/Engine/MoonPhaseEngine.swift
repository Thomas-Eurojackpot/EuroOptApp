//
//  MoonPhaseEngine.swift
//  EuroOpt
//
//  Isolated moon-phase analysis. Alpha 7.5 remains untouched.
//

import Foundation

final class MoonPhaseEngine {

    private let candidateCountMinimum = 301
    private let monteCarloRuns = 50
    private let frozenPhase: Phase = .newMoon
    private let confirmationCutoff = "2026-08-07"

    private enum Phase: String, CaseIterable {
        case newMoon = "Neumond"
        case waxingCrescent = "Zunehmende Sichel"
        case firstQuarter = "Erstes Viertel"
        case waxingGibbous = "Zunehmender Mond"
        case fullMoon = "Vollmond"
        case waningGibbous = "Abnehmender Mond"
        case lastQuarter = "Letztes Viertel"
        case waningCrescent = "Abnehmende Sichel"
    }

    private struct TestCase {
        let candidates: [Ticket]
        let target: EuroJackpotDraw
        let phase: Phase
    }

    func run(draws: [EuroJackpotDraw], recommendationCount: Int) {
        guard draws.count > 140 else {
            print("❌ Mondphasen-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)

        print("")
        print("===================================")
        print("🌙 MONDPHASEN – ISOLIERTER TEST")
        print("===================================")
        print("Holdout-Ziehungen   : \(draws.count - holdoutStart)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Mondphasen           : 8 astronomische Phasen")
        print("Validation           : verwendet, nur zur Phasen-Auswahl")
        print("Gewichte / EQI       : nicht verwendet")
        print("Diversitätsregel     : maximal 2 gemeinsame Hauptzahlen")
        print("")
        print("🔒 Alpha 7.5 wird nicht verändert.")
        print("🔒 Der Holdout wird nicht zur Auswahl der Mondphase verwendet.")

        let generator = TicketGenerator()
        let validationEnd = holdoutStart
        let validation = draws[100..<validationEnd]
        let selectedPhase = choosePhase(validation: Array(validation))

        print("Ausgewählte Phase    : \(selectedPhase.rawValue)")

        var cases: [TestCase] = []
        cases.reserveCapacity(draws.count - holdoutStart)

        for index in holdoutStart..<draws.count {
            let trainingDraws = Array(draws.prefix(index))
            let target = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )
            cases.append(TestCase(candidates: candidates, target: target, phase: moonPhase(for: target.date)))
        }

        printBenchmark(cases: cases, targetPhase: selectedPhase, recommendationCount: recommendationCount, title: "MONDPHASEN – HOLDOUT BENCHMARK", phaseLocked: false, start: start)
    }

    func runConfirmation(draws: [EuroJackpotDraw], recommendationCount: Int) {
        let start = Date()
        let confirmationDraws = draws.filter { $0.dateString > confirmationCutoff }

        print("")
        print("===================================")
        print("🌙 MONDPHASEN – UNABHÄNGIGER BESTÄTIGUNGSTEST")
        print("===================================")
        print("Fixierte Phase       : \(frozenPhase.rawValue)")
        print("Daten-Cutoff         : \(confirmationCutoff)")
        print("Neue Ziehungen       : \(confirmationDraws.count)")
        print("Gewichte / EQI       : nicht verwendet")
        print("Validation           : nicht verwendet")
        print("Historischer Holdout : nicht wiederverwendet")
        print("")
        print("🔒 Neumond wurde vor diesem Test fest eingefroren.")
        print("🔒 Keine erneute Phasenwahl.")
        print("🔒 Keine Optimierung auf den neuen Daten.")

        guard !confirmationDraws.isEmpty else {
            print("")
            print("⏳ NOCH KEINE NEUEN ZIEHUNGEN VORHANDEN")
            print("Der Bestätigungstest startet automatisch erst, wenn draws.json Ziehungen nach \(confirmationCutoff) enthält.")
            print(String(format: "# ⏱ Mondphasen-Bestätigung: %.2f Sekunden", Date().timeIntervalSince(start)))
            return
        }

        let candidateCount = max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)
        let generator = TicketGenerator()
        var cases: [TestCase] = []
        cases.reserveCapacity(confirmationDraws.count)

        for target in confirmationDraws {
            let priorDraws = draws.filter { $0.dateString < target.dateString }
            let candidates = generator.generate(
                count: candidateCount,
                draws: priorDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )
            cases.append(TestCase(candidates: candidates, target: target, phase: moonPhase(for: target.date)))
        }

        printBenchmark(cases: cases, targetPhase: frozenPhase, recommendationCount: recommendationCount, title: "MONDPHASEN – UNABHÄNGIGER BESTÄTIGUNGSTEST", phaseLocked: true, start: start)
    }

    private func printBenchmark(cases: [TestCase], targetPhase: Phase, recommendationCount: Int, title: String, phaseLocked: Bool, start: Date) {
        guard !cases.isEmpty else { return }

        var model = Aggregate()
        for testCase in cases {
            let selected = selectMoonPhase(candidates: testCase.candidates, phase: testCase.phase, targetPhase: targetPhase, limit: recommendationCount)
            for ticket in selected {
                model.mainHits += commonHitCount(ticket.numbers, testCase.target.numbers)
                model.euroHits += commonHitCount(ticket.euroNumbers, testCase.target.euroNumbers)
                model.tickets += 1
            }
        }

        var mainDeltas: [Double] = []
        var euroDeltas: [Double] = []
        var combinedDeltas: [Double] = []
        mainDeltas.reserveCapacity(monteCarloRuns)
        euroDeltas.reserveCapacity(monteCarloRuns)
        combinedDeltas.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {
            let rng = SeededRandomGenerator(seed: 0x4D4F4F4E_0000_7500 &+ UInt64(run))
            let random = aggregateRandom(cases: cases, limit: recommendationCount, rng: rng)
            let mainDelta = model.mainAverage - random.mainAverage
            let euroDelta = model.euroAverage - random.euroAverage
            mainDeltas.append(mainDelta)
            euroDeltas.append(euroDelta)
            combinedDeltas.append(mainDelta + euroDelta)
            if (run + 1).isMultiple(of: 5) || run == monteCarloRuns - 1 {
                print("... Monte-Carlo \(run + 1) / \(monteCarloRuns)")
            }
        }

        let mainDelta = mean(mainDeltas)
        let euroDelta = mean(euroDeltas)
        let combinedDelta = mean(combinedDeltas)

        print("")
        print("===================================")
        print("🌙 \(title)")
        print("===================================")
        print("Phase festgelegt     : JA")
        print("Phase                : \(targetPhase.rawValue)")
        print("Test-Ziehungen       : \(cases.count)")
        print(String(format: "Ø Modell Haupt        : %.4f", model.mainAverage))
        print(String(format: "Ø Zufall Haupt        : %.4f", model.mainAverage - mainDelta))
        print(String(format: "Δ Modell - Zufall     : %+.4f", mainDelta))
        print(String(format: "95%% CI Δ Haupt        : ±%.4f", confidenceInterval(mainDeltas)))
        print("")
        print(String(format: "Ø Modell Euro         : %.4f", model.euroAverage))
        print(String(format: "Ø Zufall Euro         : %.4f", model.euroAverage - euroDelta))
        print(String(format: "Δ Modell - Zufall     : %+.4f", euroDelta))
        print(String(format: "95%% CI Δ Euro         : ±%.4f", confidenceInterval(euroDeltas)))
        print("")
        print(String(format: "Δ kombiniert          : %+.4f", combinedDelta))
        print(String(format: "95%% CI Δ kombiniert   : ±%.4f", confidenceInterval(combinedDeltas)))
        print("")
        print("Statistik:")
        print("- Gepaarter Vergleich auf einem identischen Test-Zeitfenster.")
        print("- Die Phase wurde vor dem Bestätigungstest festgelegt: \(targetPhase.rawValue).")
        print("- Keine erneute Phasenwahl und keine Gewichtsoptimierung.")
        print("- Zufall verwendet keine EQI-Komponenten, Gewichte oder historischen Treffer.")
        print("- Hauptzahl-Regeln und Diversitätsregel entsprechen dem bisherigen Benchmark.")
        print("- 95-%-KI basiert auf 50 unabhängigen Monte-Carlo-Replikationen.")
        print("- Ein KI, das 0 nicht einschließt, wäre ein Hinweis auf einen stabilen Unterschied.")
        if phaseLocked {
            print("- Dieser Test verwendet ausschließlich Ziehungen nach dem Daten-Cutoff.")
        }
        print(String(format: "# ⏱ Mondphasen-Test: %.2f Sekunden", Date().timeIntervalSince(start)))
    }

    private struct Aggregate {
        var mainHits = 0
        var euroHits = 0
        var tickets = 0
        var mainAverage: Double { tickets > 0 ? Double(mainHits) / Double(tickets) : 0 }
        var euroAverage: Double { tickets > 0 ? Double(euroHits) / Double(tickets) : 0 }
    }

    private func choosePhase(validation: [EuroJackpotDraw]) -> Phase {
        var scores: [Phase: Double] = [:]
        for phase in Phase.allCases { scores[phase] = 0 }
        for draw in validation {
            let phase = moonPhase(for: draw.date)
            let sum = Double(draw.numbers.reduce(0, +))
            let centered = 1.0 - min(abs(sum - 127.5) / 127.5, 1.0)
            scores[phase, default: 0] += centered
        }
        return Phase.allCases.max { (scores[$0] ?? 0) < (scores[$1] ?? 0) } ?? .fullMoon
    }

    private func selectMoonPhase(candidates: [Ticket], phase: Phase, targetPhase: Phase, limit: Int) -> [Ticket] {
        guard phase == targetPhase else { return Array(candidates.prefix(limit)) }
        return candidates
            .sorted { abs(Double($0.numbers.reduce(0, +)) - 127.5) < abs(Double($1.numbers.reduce(0, +)) - 127.5) }
            .reduce(into: [Ticket]()) { selected, ticket in
                guard selected.count < limit else { return }
                guard selected.allSatisfy({ commonNumbers($0, ticket) < 3 }) else { return }
                selected.append(ticket)
            }
    }

    private func aggregateRandom(cases: [TestCase], limit: Int, rng: SeededRandomGenerator) -> Aggregate {
        var result = Aggregate()
        for testCase in cases {
            let selected = randomSelection(candidates: testCase.candidates, limit: limit, rng: rng)
            for ticket in selected {
                result.mainHits += commonHitCount(ticket.numbers, testCase.target.numbers)
                result.euroHits += commonHitCount(ticket.euroNumbers, testCase.target.euroNumbers)
                result.tickets += 1
            }
        }
        return result
    }

    private func randomSelection(candidates: [Ticket], limit: Int, rng: SeededRandomGenerator) -> [Ticket] {
        var order = Array(0..<candidates.count)
        var selected: [Ticket] = []
        var scan = 0
        while scan < order.count && selected.count < limit {
            let remaining = order.count - scan
            let pick = scan + rng.nextInt(upperBound: remaining)
            order.swapAt(scan, pick)
            let ticket = candidates[order[scan]]
            scan += 1
            if selected.allSatisfy({ commonNumbers($0, ticket) < 3 }) { selected.append(ticket) }
        }
        return selected
    }

    private func moonPhase(for date: Date) -> Phase {
        let julianDay = date.timeIntervalSince1970 / 86400.0 + 2440587.5
        let synodicMonth = 29.530588853
        let knownNewMoon = 2451550.09765
        var age = (julianDay - knownNewMoon).truncatingRemainder(dividingBy: synodicMonth)
        if age < 0 { age += synodicMonth }
        let index = Int(floor((age / synodicMonth) * 8.0 + 0.5)) % 8
        return Phase.allCases[index]
    }

    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int { commonHitCount(lhs.numbers, rhs.numbers) }
    private func commonHitCount(_ lhs: [Int], _ rhs: [Int]) -> Int { lhs.reduce(0) { $0 + (rhs.contains($1) ? 1 : 0) } }
    private func mean(_ values: [Double]) -> Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
    private func confidenceInterval(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        let variance = values.reduce(0) { $0 + pow($1 - m, 2) } / Double(values.count - 1)
        return 2.0096 * sqrt(variance) / sqrt(Double(values.count))
    }
}

private final class SeededRandomGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    @inline(__always) func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    @inline(__always) func nextInt(upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }
}

private extension EuroJackpotDraw {
    var dateString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
