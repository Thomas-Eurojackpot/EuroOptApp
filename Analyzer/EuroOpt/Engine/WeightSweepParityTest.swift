//
//  WeightSweepParityTest.swift
//  EuroOpt
//
//  Test-only parity check for Alpha 7.5 WeightSweepEngine vs WeightSweepCore.
//  The same randomly generated candidate set is evaluated by both paths.
//

import Foundation

struct WeightSweepParitySelection {
    let profileID: Int
    let weights: [Double]
    let tickets: [Ticket]
}

final class WeightSweepParityTest {

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

    func run(draws: [EuroJackpotDraw], recommendationCount: Int) {
        guard draws.count > 140 else {
            print("❌ WeightSweep-Parität: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - WeightSweepCore.warmup
        let validationTests = totalTests / 2
        let validationStart = WeightSweepCore.warmup
        let validationEnd = validationStart + validationTests
        let candidateCount = max(AppSettings.backtestCandidateCount + 1,
                                 WeightSweepCore.candidateCountMinimum)

        let engine = WeightSweepEngine()
        let generator = TicketGenerator()
        let profiles = WeightSweepCore.makeProfiles()

        var engineTotals = Array(repeating: Aggregate(), count: profiles.count)
        var coreTotals = Array(repeating: Aggregate(), count: profiles.count)

        print("")
        print("===================================")
        print("🔬 WEIGHT-SWEEP PARITÄTSTEST")
        print("===================================")
        print("Validation          : \(validationTests)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Profile             : \(profiles.count)")
        print("")
        print("🔒 Beide Pfade erhalten exakt dieselben Kandidaten.")
        print("🔒 TicketGenerator wird pro Ziehung nur einmal aufgerufen.")
        print("🔒 Alpha 7.5 run() wird nicht verändert oder verwendet.")
        print("")

        for index in validationStart..<validationEnd {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            let engineSelections = engine.paritySelections(
                candidates: candidates,
                trainingDraws: trainingDraws,
                recommendationCount: recommendationCount
            )

            let cache = ScoreCache(draws: trainingDraws)
            let coreSelections = profiles.map { profile -> WeightSweepParitySelection in
                let scoreEngine = ScoreEngine(cache: cache, goal: profile.goal)
                let best = WeightSweepCore.bestTickets(
                    candidates: candidates,
                    scoreEngine: scoreEngine,
                    limit: recommendationCount
                )
                return WeightSweepParitySelection(
                    profileID: profile.id,
                    weights: profile.weights,
                    tickets: best
                )
            }

            for profileIndex in profiles.indices {
                let engineTickets = engineSelections[profileIndex].tickets
                let coreTickets = coreSelections[profileIndex].tickets

                add(
                    tickets: engineTickets,
                    target: targetDraw,
                    date: targetDraw.date,
                    to: &engineTotals[profileIndex]
                )

                add(
                    tickets: coreTickets,
                    target: targetDraw,
                    date: targetDraw.date,
                    to: &coreTotals[profileIndex]
                )
            }

            let current = index - validationStart + 1
            if current.isMultiple(of: 25) {
                print("... Parität \(current) / \(validationTests)")
            }
        }

        var mismatchCount = 0
        var maxDifference = 0.0
        var worstProfile = 0

        print("")
        print("-----------------------------------")
        print("PROFILE – ENGINE vs CORE")
        print("-----------------------------------")
        print("Profil    Engine Score    Core Score    Δ")

        for index in profiles.indices {
            let engineScore = engineTotals[index].score
            let coreScore = coreTotals[index].score
            let difference = abs(engineScore - coreScore)
            maxDifference = max(maxDifference, difference)

            if difference > 0.000000001 {
                mismatchCount += 1
                worstProfile = index
            }

            print(String(format: "P%02d       %+.9f   %+.9f   %+.9f",
                         profiles[index].id,
                         engineScore,
                         coreScore,
                         engineScore - coreScore))
        }

        print("")

        let engineWinner = engineTotals.indices.max {
            engineTotals[$0].score < engineTotals[$1].score
        }
        let coreWinner = coreTotals.indices.max {
            coreTotals[$0].score < coreTotals[$1].score
        }

        if let engineWinner, let coreWinner {
            print("Engine-Gewinner     : P\(String(format: "%02d", profiles[engineWinner].id))")
            print("Core-Gewinner       : P\(String(format: "%02d", profiles[coreWinner].id))")
            print("Gewinner identisch  : \(engineWinner == coreWinner ? "JA" : "NEIN")")
        }

        print(String(format: "Max. Score-Abweichung: %.12f", maxDifference))
        print("Score-Parität        : \(mismatchCount == 0 ? "BESTÄTIGT" : "FEHLER")")

        if mismatchCount > 0 {
            print("⚠️ Erstes abweichendes Profil: P\(String(format: "%02d", profiles[worstProfile].id))")
        }

        print("")
        print("Hinweis: Der Test vergleicht exakt dieselben Kandidaten und dieselbe Validation-Zielziehung.")
        print("Der normale Alpha-7.5-Lauf bleibt unverändert.")
        print("")
        print(String(format: "⏱ WeightSweep-Parität: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func add(
        tickets: [Ticket],
        target: EuroJackpotDraw,
        date: Date,
        to aggregate: inout Aggregate
    ) {
        for ticket in tickets {
            aggregate.hits += Set(ticket.numbers).intersection(target.numbers).count
            aggregate.euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
        }

        aggregate.tickets += tickets.count
        aggregate.expectedEuroHits += WeightSweepCore.expectedEuroHits(
            for: date,
            ticketCount: tickets.count
        )
    }
}
