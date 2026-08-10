//
//  ComponentBacktestEngine.swift
//  EuroOpt
//
//  Alpha 7.4 - EQI component analysis
//

import Foundation

final class ComponentBacktestEngine {

    private struct Model {
        let name: String
        let goal: OptimizationGoal
    }

    private struct Accumulator {
        var hits = 0
        var euroHits = 0
        var tickets = 0
        var tests = 0
    }

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) {

        guard draws.count > 100 else {
            print("❌ Komponententest: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let models = makeModels()
        var totals = Dictionary(uniqueKeysWithValues: models.map {
            ($0.name, Accumulator())
        })

        // Important: every model receives exactly the same candidate pool for
        // a given target draw. Candidate generation is deliberately kept
        // separate from component scoring so this test isolates the EQI
        // selection logic instead of changing the search space per model.
        let generator = TicketGenerator()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 501)

        print("")
        print("===================================")
        print("🧩 EQI KOMPONENTENTEST")
        print("===================================")
        print("Getestete Ziehungen : \(draws.count - 100)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Hill Climbing       : 0")
        print("")

        for index in 100..<draws.count {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            for model in models {
                let optimizer = OptimizerEngine()
                let best = optimizer.bestTickets(
                    from: candidates,
                    draws: trainingDraws,
                    goal: model.goal,
                    limit: recommendationCount
                )

                let hits = best.reduce(0) { partial, candidate in
                    partial + Set(candidate.ticket.numbers).intersection(targetDraw.numbers).count
                }

                let euroHits = best.reduce(0) { partial, candidate in
                    partial + Set(candidate.ticket.euroNumbers).intersection(targetDraw.euroNumbers).count
                }

                totals[model.name, default: Accumulator()].hits += hits
                totals[model.name, default: Accumulator()].euroHits += euroHits
                totals[model.name, default: Accumulator()].tickets += best.count
                totals[model.name, default: Accumulator()].tests += 1
            }

            if (index - 99).isMultiple(of: 100) {
                print("... \(index - 99) von \(draws.count - 100) Ziehungen")
            }
        }

        print("")
        print("-----------------------------------")
        print("ERGEBNIS")
        print("-----------------------------------")
        print("Modell                                      Ø Haupt   Ø Euro   Δ Haupt vs Zufall")
        print("-----------------------------------")

        let randomMain = 0.50
        let randomEuro = 1.0 / 3.0

        for model in models {
            guard let total = totals[model.name], total.tickets > 0 else { continue }

            let averageHits = Double(total.hits) / Double(total.tickets)
            let averageEuroHits = Double(total.euroHits) / Double(total.tickets)
            let delta = averageHits - randomMain

            print(String(
                format: "%-42s %.3f     %.3f     %+.3f",
                model.name,
                averageHits,
                averageEuroHits,
                delta
            ))
        }

        print("-----------------------------------")
        print(String(format: "Zufall theoretisch                         %.3f     %.3f", randomMain, randomEuro))
        print("")
        print("Hinweis: Eurozahlen werden aktuell von keinem EQI-Modul bewertet.")
        print("Der Komponententest misst daher dort bewusst nur die Auswahlwirkung.")
        print("")
        print(String(format: "⏱ Komponententest: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func makeModels() -> [Model] {

        let frequency = OptimizationGoal(
            frequencyWeight: 100,
            pairWeight: 0,
            evenOddWeight: 0,
            highLowWeight: 0,
            sumWeight: 0,
            gapWeight: 0
        )

        let pairs = OptimizationGoal(
            frequencyWeight: 0,
            pairWeight: 100,
            evenOddWeight: 0,
            highLowWeight: 0,
            sumWeight: 0,
            gapWeight: 0
        )

        let evenOdd = OptimizationGoal(
            frequencyWeight: 0,
            pairWeight: 0,
            evenOddWeight: 100,
            highLowWeight: 0,
            sumWeight: 0,
            gapWeight: 0
        )

        let highLow = OptimizationGoal(
            frequencyWeight: 0,
            pairWeight: 0,
            evenOddWeight: 0,
            highLowWeight: 100,
            sumWeight: 0,
            gapWeight: 0
        )

        let sum = OptimizationGoal(
            frequencyWeight: 0,
            pairWeight: 0,
            evenOddWeight: 0,
            highLowWeight: 0,
            sumWeight: 100,
            gapWeight: 0
        )

        let gaps = OptimizationGoal(
            frequencyWeight: 0,
            pairWeight: 0,
            evenOddWeight: 0,
            highLowWeight: 0,
            sumWeight: 0,
            gapWeight: 100
        )

        let frequencyPairs = OptimizationGoal(
            frequencyWeight: 50,
            pairWeight: 50,
            evenOddWeight: 0,
            highLowWeight: 0,
            sumWeight: 0,
            gapWeight: 0
        )

        let frequencyPairsEvenOdd = OptimizationGoal(
            frequencyWeight: 40,
            pairWeight: 35,
            evenOddWeight: 25,
            highLowWeight: 0,
            sumWeight: 0,
            gapWeight: 0
        )

        let frequencyPairsEvenOddHighLow = OptimizationGoal(
            frequencyWeight: 30,
            pairWeight: 25,
            evenOddWeight: 15,
            highLowWeight: 15,
            sumWeight: 0,
            gapWeight: 0
        )

        let alpha74 = OptimizationGoal(
            frequencyWeight: 30,
            pairWeight: 25,
            evenOddWeight: 15,
            highLowWeight: 15,
            sumWeight: 15,
            gapWeight: 0
        )

        return [
            Model(name: "Nur Frequenz", goal: frequency),
            Model(name: "Nur Paare", goal: pairs),
            Model(name: "Nur Gerade/Ungerade", goal: evenOdd),
            Model(name: "Nur Hoch/Niedrig", goal: highLow),
            Model(name: "Nur Summe", goal: sum),
            Model(name: "Nur Abstände", goal: gaps),
            Model(name: "Frequenz + Paare", goal: frequencyPairs),
            Model(name: "+ Gerade/Ungerade", goal: frequencyPairsEvenOdd),
            Model(name: "+ Hoch/Niedrig", goal: frequencyPairsEvenOddHighLow),
            Model(name: "Alpha 7.4", goal: alpha74)
        ]
    }
}
