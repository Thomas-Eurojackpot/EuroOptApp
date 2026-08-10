//
//  LearningEngine.swift
//  EuroOpt
//
//  Alpha 7.4 Test
//

import Foundation

final class LearningEngine {

    private let generator = TicketGenerator()
    private let optimizer = OptimizerEngine()
    private let mutator = WeightMutator()

    private struct Evaluation {
        let averageHits: Double
        let averageEuroHits: Double
        let reward: Double
    }

    func learn(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        generations: Int
    ) -> OptimizationGoal {

        guard draws.count > 50 else {
            print("❌ Zu wenige Ziehungen für Walk-Forward-Lernen")
            return OptimizationGoalStore.shared.currentGoal
        }

        let start = Date()

        // generations bleibt als API kompatibel erhalten.
        // Im Walk-Forward-Modus bedeutet es die maximale Zahl
        // von Mutationstests pro Ziehung.
        let mutationCount = max(1, min(generations, 8))

        // Das Lernsystem muss deutlich schneller sein als der normale Optimizer.
        let learningCandidateCount = min(candidateCount, 120)
        let learningHillClimbingIterations = min(
            AppSettings.backtestHillClimbingIterations,
            4
        )

        var currentGoal = OptimizationGoalStore.shared.currentGoal

        var testedDraws = 0
        var totalHits = 0
        var totalEuroHits = 0

        var baselineReward = 0.0
        var adaptedReward = 0.0
        var improvedSteps = 0

        print("")
        print("===================================")
        print("🧩 EQI KOMPONENTENTEST")
        print("===================================")
        print("Getestete Ziehungen : \(draws.count - 50)")
        print("Kandidaten je Test  : \(learningCandidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Hill Climbing       : \(learningHillClimbingIterations)")
        print("🧠 Adaptives Lernen : WALK-FORWARD")
        print("===================================")

        // index ist immer die Zielziehung.
        // draws[0..<index] ist die ausschließlich bekannte Historie.
        for index in 50..<draws.count {

            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            // -------------------------------------------------------------
            // 1. VORHER: Empfehlungen ausschließlich aus der Vergangenheit
            // -------------------------------------------------------------
            let candidates = generator.generate(
                count: learningCandidateCount,
                draws: trainingDraws,
                hillClimbingIterations: learningHillClimbingIterations,
                goal: currentGoal
            )

            let baselineTickets = optimizer.bestTickets(
                from: candidates,
                draws: trainingDraws,
                goal: currentGoal,
                limit: recommendationCount
            )

            let baseline = evaluate(
                tickets: baselineTickets,
                target: targetDraw
            )

            // Der Baseline-Wert ist der echte Out-of-Sample-Wert.
            // Er wird VOR jeder Anpassung an die Zielziehung gemessen.
            totalHits += Int((baseline.averageHits * Double(recommendationCount)).rounded())
            totalEuroHits += Int((baseline.averageEuroHits * Double(recommendationCount)).rounded())
            baselineReward += baseline.reward

            var bestGoal = currentGoal
            var bestEvaluation = baseline

            // -------------------------------------------------------------
            // 2. NACHHER: Zielziehung ist jetzt bekannt.
            //    Erst jetzt darf das Lernsystem daraus lernen.
            // -------------------------------------------------------------
            for _ in 0..<mutationCount {

                let candidateGoal = mutator.mutate(goal: currentGoal)

                let candidateTickets = optimizer.bestTickets(
                    from: candidates,
                    draws: trainingDraws,
                    goal: candidateGoal,
                    limit: recommendationCount
                )

                let candidateEvaluation = evaluate(
                    tickets: candidateTickets,
                    target: targetDraw
                )

                if candidateEvaluation.reward > bestEvaluation.reward {
                    bestGoal = candidateGoal
                    bestEvaluation = candidateEvaluation
                }

            }

            if bestEvaluation.reward > baseline.reward {
                currentGoal = bestGoal
                improvedSteps += 1
            }

            adaptedReward += bestEvaluation.reward
            testedDraws += 1

            if testedDraws == 1 || testedDraws % 25 == 0 || testedDraws == draws.count - 50 {
                print(
                    String(
                        format: "🧠 Walk-Forward %3d/%3d | Ø %.3f / %.3f | Verbesserungen %d",
                        testedDraws,
                        draws.count - 50,
                        Double(totalHits) / Double(testedDraws * recommendationCount),
                        Double(totalEuroHits) / Double(testedDraws * recommendationCount),
                        improvedSteps
                    )
                )
            }

        }

        // Erst NACH dem vollständigen Walk-Forward-Lauf wird das finale
        // adaptive Profil übernommen. Keine Zielziehung wurde zur Erstellung
        // ihrer eigenen Empfehlung verwendet.
        OptimizationGoalStore.shared.update(currentGoal)

        let averageHits = Double(totalHits) / Double(testedDraws * recommendationCount)
        let averageEuroHits = Double(totalEuroHits) / Double(testedDraws * recommendationCount)

        let randomMain = 0.5
        let randomEuro = 1.0 / 3.0

        let duration = Date().timeIntervalSince(start)

        print("")
        print("===================================")
        print("🧠 WALK-FORWARD LERNERGEBNIS")
        print("===================================")
        print("Getestete Ziehungen : \(testedDraws)")
        print("Kandidaten je Test  : \(learningCandidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Mutationstests      : \(mutationCount)")
        print("Verbesserte Schritte: \(improvedSteps)")
        print("")
        print(String(format: "Ø Haupttreffer      : %.3f", averageHits))
        print(String(format: "Ø Eurotreffer       : %.3f", averageEuroHits))
        print("")
        print(String(format: "Zufall theoretisch  : %.3f / %.3f", randomMain, randomEuro))
        print(String(format: "Δ Haupt vs Zufall   : %+.3f", averageHits - randomMain))
        print(String(format: "Δ Euro vs Zufall    : %+.3f", averageEuroHits - randomEuro))
        print("")
        print("Gewichte gelernt")
        print(String(format: "Frequency : %.2f", currentGoal.frequencyWeight))
        print(String(format: "Pair      : %.2f", currentGoal.pairWeight))
        print(String(format: "Even/Odd  : %.2f", currentGoal.evenOddWeight))
        print(String(format: "High/Low  : %.2f", currentGoal.highLowWeight))
        print(String(format: "Sum       : %.2f", currentGoal.sumWeight))
        print(String(format: "Gap       : %.2f", currentGoal.gapWeight))
        print("")
        print(String(format: "Baseline Reward      : %.3f", baselineReward))
        print(String(format: "Adapted Reward       : %.3f", adaptedReward))
        print(String(format: "⏱ Walk-Forward       : %.2f Sekunden", duration))
        print("===================================")

        return currentGoal

    }

    private func evaluate(
        tickets: [(ticket: Ticket, score: Double)],
        target: EuroJackpotDraw
    ) -> Evaluation {

        guard !tickets.isEmpty else {
            return Evaluation(
                averageHits: 0,
                averageEuroHits: 0,
                reward: 0
            )
        }

        var totalHits = 0
        var totalEuroHits = 0
        var reward = 0.0

        for candidate in tickets {

            let hits = Set(candidate.ticket.numbers)
                .intersection(target.numbers)
                .count

            let euroHits = Set(candidate.ticket.euroNumbers)
                .intersection(target.euroNumbers)
                .count

            totalHits += hits
            totalEuroHits += euroHits

            // Lernsignal: Hauptzahlen dominieren, Eurozahlen bleiben relevant.
            reward += Double(hits) * 100.0
            reward += Double(euroHits) * 25.0

            if hits == 5 && euroHits == 2 {
                reward += 100_000.0
            } else if hits == 5 && euroHits == 1 {
                reward += 25_000.0
            } else if hits == 5 {
                reward += 8_000.0
            } else if hits == 4 && euroHits == 2 {
                reward += 1_500.0
            }

        }

        let count = Double(tickets.count)

        return Evaluation(
            averageHits: Double(totalHits) / count,
            averageEuroHits: Double(totalEuroHits) / count,
            reward: reward
        )

    }

}
