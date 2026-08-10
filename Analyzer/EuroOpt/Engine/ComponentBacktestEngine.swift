//
//  ComponentBacktestEngine.swift
//  EuroOpt
//
//  Alpha 7.5 - EQI component analysis + adaptive learner
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

    // MARK: - Walk-forward "Gehirn"
    //
    // The learner is deliberately online:
    // - it starts with equal trust in all components
    // - it selects the next draw using only information known so far
    // - after the target draw is revealed, component performance is fed back
    // - no future draw can influence the current decision
    //
    // This is not a claim that lottery draws are predictable. It is a
    // controlled test of whether component performance shows repeatable
    // walk-forward stability.
    private final class AdaptiveLearner {

        private enum Component: CaseIterable {
            case frequency
            case pair
            case evenOdd
            case highLow
            case sum
            case gap

            var name: String {
                switch self {
                case .frequency: return "Frequenz"
                case .pair: return "Paare"
                case .evenOdd: return "Gerade/Ungerade"
                case .highLow: return "Hoch/Niedrig"
                case .sum: return "Summe"
                case .gap: return "Abstände"
                }
            }
        }

        private var weights: [Component: Double]
        private let learningRate = 2.0
        private let minimumWeight = 0.03

        init() {
            let initial = 1.0 / Double(Component.allCases.count)
            self.weights = Dictionary(
                uniqueKeysWithValues: Component.allCases.map { ($0, initial) }
            )
        }

        var goal: OptimizationGoal {
            OptimizationGoal(
                frequencyWeight: normalized(.frequency),
                pairWeight: normalized(.pair),
                evenOddWeight: normalized(.evenOdd),
                highLowWeight: normalized(.highLow),
                sumWeight: normalized(.sum),
                gapWeight: normalized(.gap)
            )
        }

        func update(
            averageHitsByComponent: [String: Double]
        ) {
            let randomBaseline = 0.50

            for component in Component.allCases {
                let observed = averageHitsByComponent[component.name] ?? randomBaseline
                let delta = max(-0.50, min(0.50, observed - randomBaseline))
                let oldWeight = weights[component] ?? 1.0
                weights[component] = oldWeight * exp(learningRate * delta)
            }

            applyFloorAndNormalize()
        }

        func report() -> [(name: String, percent: Double)] {
            Component.allCases.map {
                ($0.name, normalized($0) * 100.0)
            }
        }

        private func normalized(_ component: Component) -> Double {
            let total = weights.values.reduce(0, +)
            guard total > 0 else { return 1.0 / Double(Component.allCases.count) }
            return (weights[component] ?? 0) / total
        }

        private func applyFloorAndNormalize() {
            for component in Component.allCases {
                weights[component] = max(weights[component] ?? 0, minimumWeight)
            }

            let total = weights.values.reduce(0, +)
            guard total > 0 else { return }

            for component in Component.allCases {
                weights[component] = (weights[component] ?? 0) / total
            }
        }
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

        let learner = AdaptiveLearner()
        var adaptiveHits = 0
        var adaptiveEuroHits = 0
        var adaptiveTickets = 0
        var adaptiveTests = 0

        // Every model receives exactly the same candidate pool for a given
        // target draw. Candidate generation is deliberately kept separate
        // from component scoring so this test isolates EQI selection logic.
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
        print("🧠 Adaptives Lernen : WALK-FORWARD")
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

            // The learner makes its decision BEFORE seeing targetDraw.
            let adaptiveGoal = learner.goal
            let adaptiveOptimizer = OptimizerEngine()
            let adaptiveBest = adaptiveOptimizer.bestTickets(
                from: candidates,
                draws: trainingDraws,
                goal: adaptiveGoal,
                limit: recommendationCount
            )

            let adaptiveMainHits = adaptiveBest.reduce(0) { partial, candidate in
                partial + Set(candidate.ticket.numbers).intersection(targetDraw.numbers).count
            }

            let adaptiveEuros = adaptiveBest.reduce(0) { partial, candidate in
                partial + Set(candidate.ticket.euroNumbers).intersection(targetDraw.euroNumbers).count
            }

            adaptiveHits += adaptiveMainHits
            adaptiveEuroHits += adaptiveEuros
            adaptiveTickets += adaptiveBest.count
            adaptiveTests += 1

            var observedExpertHits: [String: Double] = [:]

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

                let averageHits = best.isEmpty ? 0.50 : Double(hits) / Double(best.count)
                observedExpertHits[model.name] = averageHits

                totals[model.name, default: Accumulator()].hits += hits
                totals[model.name, default: Accumulator()].euroHits += euroHits
                totals[model.name, default: Accumulator()].tickets += best.count
                totals[model.name, default: Accumulator()].tests += 1
            }

            // Only now is the target outcome allowed to update the learner.
            learner.update(averageHitsByComponent: observedExpertHits)

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
            let label = model.name.padding(toLength: 42, withPad: " ", startingAt: 0)

            print(String(
                format: "%@ %.3f     %.3f     %+.3f",
                label,
                averageHits,
                averageEuroHits,
                delta
            ))
        }

        print("-----------------------------------")
        print("🧠 ADAPTIVES LERNHIRN")
        print("-----------------------------------")

        if adaptiveTickets > 0 {
            let adaptiveAverageHits = Double(adaptiveHits) / Double(adaptiveTickets)
            let adaptiveAverageEuroHits = Double(adaptiveEuroHits) / Double(adaptiveTickets)
            let mainDelta = adaptiveAverageHits - randomMain
            let euroDelta = adaptiveAverageEuroHits - randomEuro

            print(String(format: "Ø Haupttreffer : %.3f", adaptiveAverageHits))
            print(String(format: "Ø Eurotreffer  : %.3f", adaptiveAverageEuroHits))
            print(String(format: "Δ Haupt vs Zufall : %+.3f", mainDelta))
            print(String(format: "Δ Euro vs Zufall  : %+.3f", euroDelta))
            print("")
            print("Gelerntes Profil:")

            for item in learner.report() {
                print(String(format: "%-18@ %6.2f %%", item.name, item.percent))
            }

            print("")
            print("Regel: Update erst NACH der jeweiligen Ziehung.")
            print("Damit bleibt der Lernlauf zeitlich sauber und ohne Look-ahead.")
        }

        print("-----------------------------------")
        print(String(format: "Zufall theoretisch                         %.3f     %.3f", randomMain, randomEuro))
        print("")
        print("Hinweis: Eurozahlen werden aktuell von keinem EQI-Modul bewertet.")
        print("Der Komponententest misst dort bewusst nur die Auswahlwirkung.")
        print("")
        print(String(format: "⏱ Komponententest: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")

        // Alpha 7.5: choose weights only on an earlier validation period,
        // then evaluate the frozen winner on a chronological holdout.
        WeightSweepEngine().run(
            draws: draws,
            recommendationCount: recommendationCount
        )
    }

    private func makeModels() -> [Model] {
        let frequency = OptimizationGoal(frequencyWeight: 100, pairWeight: 0, evenOddWeight: 0, highLowWeight: 0, sumWeight: 0, gapWeight: 0)
        let pairs = OptimizationGoal(frequencyWeight: 0, pairWeight: 100, evenOddWeight: 0, highLowWeight: 0, sumWeight: 0, gapWeight: 0)
        let evenOdd = OptimizationGoal(frequencyWeight: 0, pairWeight: 0, evenOddWeight: 100, highLowWeight: 0, sumWeight: 0, gapWeight: 0)
        let highLow = OptimizationGoal(frequencyWeight: 0, pairWeight: 0, evenOddWeight: 0, highLowWeight: 100, sumWeight: 0, gapWeight: 0)
        let sum = OptimizationGoal(frequencyWeight: 0, pairWeight: 0, evenOddWeight: 0, highLowWeight: 0, sumWeight: 100, gapWeight: 0)
        let gaps = OptimizationGoal(frequencyWeight: 0, pairWeight: 0, evenOddWeight: 0, highLowWeight: 0, sumWeight: 0, gapWeight: 100)
        let frequencyPairs = OptimizationGoal(frequencyWeight: 50, pairWeight: 50, evenOddWeight: 0, highLowWeight: 0, sumWeight: 0, gapWeight: 0)
        let frequencyPairsEvenOdd = OptimizationGoal(frequencyWeight: 40, pairWeight: 35, evenOddWeight: 25, highLowWeight: 0, sumWeight: 0, gapWeight: 0)
        let frequencyPairsEvenOddHighLow = OptimizationGoal(frequencyWeight: 30, pairWeight: 25, evenOddWeight: 15, highLowWeight: 15, sumWeight: 0, gapWeight: 0)
        let alpha74 = OptimizationGoal(frequencyWeight: 30, pairWeight: 25, evenOddWeight: 15, highLowWeight: 15, sumWeight: 15, gapWeight: 0)

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
