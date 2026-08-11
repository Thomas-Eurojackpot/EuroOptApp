//
//  LearningEngine.swift
//  EuroOpt
//
//  Alpha 7.5
//

import Foundation

struct HoldoutResult {
    let trainingDrawCount: Int
    let holdoutDrawCount: Int
    let learnedGoal: OptimizationGoal
    let averageHits: Double
    let averageEuroHits: Double
    let randomMain: Double
    let randomEuro: Double
    let duration: Double
}

final class LearningEngine {

    private let generator = TicketGenerator()
    private let optimizer = OptimizerEngine()
    private let mutator = WeightMutator()

    private struct Evaluation {
        let totalHits: Int
        let totalEuroHits: Int
        let ticketCount: Int
        let averageHits: Double
        let averageEuroHits: Double
        let reward: Double
    }

    func learn(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        generations: Int,
        initialGoal: OptimizationGoal? = nil,
        persist: Bool = true
    ) -> OptimizationGoal {

        guard draws.count > 50 else {
            print("❌ Zu wenige Ziehungen für Walk-Forward-Lernen")
            return initialGoal ?? OptimizationGoalStore.shared.currentGoal
        }

        let start = Date()
        let mutationCount = max(1, min(generations, 8))

        let learningCandidateCount = min(candidateCount, 120)
        let learningHillClimbingIterations = min(
            AppSettings.backtestHillClimbingIterations,
            4
        )

        var currentGoal = initialGoal ?? OptimizationGoalStore.shared.currentGoal

        var testedDraws = 0
        var totalHits = 0
        var totalEuroHits = 0
        var totalTickets = 0

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

            // Der Kandidatenpool bleibt unabhängig von der Zielziehung.
            // Das EQI-Ziel wird nur für die Bewertung/Hill-Climbing verwendet.
            let candidates = generator.generate(
                count: learningCandidateCount,
                draws: trainingDraws,
                hillClimbingIterations: learningHillClimbingIterations,
                goal: currentGoal
            )

            // -------------------------------------------------------------
            // 1. VORHER: echte Out-of-Sample-Empfehlung
            // -------------------------------------------------------------
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

            totalHits += baseline.totalHits
            totalEuroHits += baseline.totalEuroHits
            totalTickets += baseline.ticketCount
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

            // Gewichte werden erst NACH der Zielziehung aktualisiert.
            if bestEvaluation.reward > baseline.reward {
                currentGoal = bestGoal
                improvedSteps += 1
            }

            adaptedReward += bestEvaluation.reward
            testedDraws += 1

            if testedDraws == 1 || testedDraws % 25 == 0 || testedDraws == draws.count - 50 {
                let avgHits = totalTickets > 0
                    ? Double(totalHits) / Double(totalTickets)
                    : 0

                let avgEuroHits = totalTickets > 0
                    ? Double(totalEuroHits) / Double(totalTickets)
                    : 0

                print(
                    String(
                        format: "🧠 Walk-Forward %3d/%3d | Ø %.3f / %.3f | Verbesserungen %d",
                        testedDraws,
                        draws.count - 50,
                        avgHits,
                        avgEuroHits,
                        improvedSteps
                    )
                )
            }

        }

        // Beim Holdout-Test darf das Trainingsergebnis nicht automatisch
        // gespeichert werden. Nur der normale Lernlauf übernimmt das Profil.
        if persist {
            OptimizationGoalStore.shared.update(currentGoal)
        }

        let averageHits = totalTickets > 0
            ? Double(totalHits) / Double(totalTickets)
            : 0

        let averageEuroHits = totalTickets > 0
            ? Double(totalEuroHits) / Double(totalTickets)
            : 0

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
        print(String(format: "Baseline Reward : %.3f", baselineReward))
        print(String(format: "Adapted Reward  : %.3f", adaptedReward))
        print(String(format: "⏱ Walk-Forward  : %.2f Sekunden", duration))
        print("===================================")

        return currentGoal

    }

    func runHoldout(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        generations: Int
    ) -> HoldoutResult? {

        guard draws.count >= 100 else {
            print("❌ Zu wenige Ziehungen für einen Holdout-Test")
            return nil
        }

        let start = Date()

        // Die letzten 20 % bleiben bis zum eigentlichen Test vollständig
        // außerhalb des Lernens.
        let splitIndex = max(
            50,
            min(
                draws.count - 50,
                Int(Double(draws.count) * 0.80)
            )
        )

        let trainingDraws = Array(draws.prefix(splitIndex))
        let holdoutDraws = Array(draws.dropFirst(splitIndex))

        print("")
        print("===================================")
        print("🧪 ALPHA 7.5 HOLDOUT-TEST")
        print("===================================")
        print("Gesamtziehungen    : \(draws.count)")
        print("Training           : \(trainingDraws.count)")
        print("Holdout            : \(holdoutDraws.count)")
        print("Holdout-Anteil     : 20 %")
        print("Profil              : TRAINING → danach eingefroren")
        print("===================================")

        // Wichtig: Das Training startet immer beim unveränderten Standardprofil.
        // Das verhindert, dass ein bereits zuvor gelerntes Profil in den
        // Holdout-Test hineinleakt.
        let learnedGoal = learn(
            draws: trainingDraws,
            candidateCount: candidateCount,
            recommendationCount: recommendationCount,
            generations: generations,
            initialGoal: OptimizationGoal(),
            persist: false
        )

        var totalHits = 0
        var totalEuroHits = 0
        var totalTickets = 0

        let testCandidateCount = min(
            candidateCount,
            AppSettings.backtestCandidateCount
        )

        let testHillClimbingIterations = AppSettings.backtestHillClimbingIterations

        // Das Profil bleibt über den kompletten Holdout unverändert.
        // Für jede Zielziehung dürfen aber nur die bis dahin bekannten
        // Ziehungen zur Kandidatenerzeugung und Bewertung verwendet werden.
        for (offset, targetDraw) in holdoutDraws.enumerated() {

            let historyEnd = splitIndex + offset
            let history = Array(draws.prefix(historyEnd))

            let candidates = generator.generate(
                count: testCandidateCount,
                draws: history,
                hillClimbingIterations: testHillClimbingIterations,
                goal: learnedGoal
            )

            let tickets = optimizer.bestTickets(
                from: candidates,
                draws: history,
                goal: learnedGoal,
                limit: recommendationCount
            )

            let evaluation = evaluate(
                tickets: tickets,
                target: targetDraw
            )

            totalHits += evaluation.totalHits
            totalEuroHits += evaluation.totalEuroHits
            totalTickets += evaluation.ticketCount

            let current = offset + 1

            if current == 1 || current % 10 == 0 || current == holdoutDraws.count {
                let avgHits = totalTickets > 0
                    ? Double(totalHits) / Double(totalTickets)
                    : 0

                let avgEuroHits = totalTickets > 0
                    ? Double(totalEuroHits) / Double(totalTickets)
                    : 0

                print(
                    String(
                        format: "🧪 Holdout %3d/%3d | Ø %.3f / %.3f",
                        current,
                        holdoutDraws.count,
                        avgHits,
                        avgEuroHits
                    )
                )
            }

        }

        let averageHits = totalTickets > 0
            ? Double(totalHits) / Double(totalTickets)
            : 0

        let averageEuroHits = totalTickets > 0
            ? Double(totalEuroHits) / Double(totalTickets)
            : 0

        let randomMain = 0.5
        let randomEuro = 1.0 / 3.0
        let duration = Date().timeIntervalSince(start)

        print("")
        print("===================================")
        print("🧪 ALPHA 7.5 HOLDOUT-ERGEBNIS")
        print("===================================")
        print("Trainingziehungen   : \(trainingDraws.count)")
        print("Holdoutziehungen    : \(holdoutDraws.count)")
        print(String(format: "Ø Haupttreffer       : %.3f", averageHits))
        print(String(format: "Ø Eurotreffer        : %.3f", averageEuroHits))
        print(String(format: "Zufall theoretisch   : %.3f / %.3f", randomMain, randomEuro))
        print(String(format: "Δ Haupt vs Zufall    : %+.3f", averageHits - randomMain))
        print(String(format: "Δ Euro vs Zufall     : %+.3f", averageEuroHits - randomEuro))
        print("")
        print("Eingefrorene Gewichte")
        print(String(format: "Frequency : %.0f", learnedGoal.frequencyWeight))
        print(String(format: "Pair      : %.0f", learnedGoal.pairWeight))
        print(String(format: "Even/Odd  : %.0f", learnedGoal.evenOddWeight))
        print(String(format: "High/Low  : %.0f", learnedGoal.highLowWeight))
        print(String(format: "Sum       : %.0f", learnedGoal.sumWeight))
        print(String(format: "Gap       : %.0f", learnedGoal.gapWeight))
        print("")
        print("Interpretation: Das Profil wurde ausschließlich auf dem Training gelernt.")
        print("Der Holdout wurde danach nicht mehr zum Lernen verwendet.")
        print(String(format: "⏱ Holdout-Test     : %.2f Sekunden", duration))
        print("===================================")

        return HoldoutResult(
            trainingDrawCount: trainingDraws.count,
            holdoutDrawCount: holdoutDraws.count,
            learnedGoal: learnedGoal,
            averageHits: averageHits,
            averageEuroHits: averageEuroHits,
            randomMain: randomMain,
            randomEuro: randomEuro,
            duration: duration
        )

    }

    private func evaluate(
        tickets: [(ticket: Ticket, score: Double)],
        target: EuroJackpotDraw
    ) -> Evaluation {

        guard !tickets.isEmpty else {
            return Evaluation(
                totalHits: 0,
                totalEuroHits: 0,
                ticketCount: 0,
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
            totalHits: totalHits,
            totalEuroHits: totalEuroHits,
            ticketCount: tickets.count,
            averageHits: Double(totalHits) / count,
            averageEuroHits: Double(totalEuroHits) / count,
            reward: reward
        )

    }

}
