import Foundation

struct ScoreGapDiagnostic {

    func run(
        draws: [EuroJackpotDraw],
        candidateCount: Int = 301
    ) {
        guard draws.count > 140 else {
            print("❌ Score-Gap: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let firstIndex = 100
        let generator = TicketGenerator()
        let optimizer = OptimizerEngine()

        var gap1to9 = 0.0
        var gap9to10 = 0.0
        var gap10to36 = 0.0
        var samples = 0

        print("")
        print("===================================")
        print("🔬 ALPHA 7.6 SCORE-ABSTAND")
        print("===================================")
        print("Kandidaten je Test : \(candidateCount)")
        print("Auswertung          : Rang 1–36")
        print("")

        for index in firstIndex..<draws.count {
            let trainingDraws = Array(draws.prefix(index))

            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            let ranked = optimizer.rankedTicketsForDiagnostic(
                from: candidates,
                draws: trainingDraws
            )

            guard ranked.count >= 36 else { continue }

            gap1to9 += ranked[0].score - ranked[8].score
            gap9to10 += ranked[8].score - ranked[9].score
            gap10to36 += ranked[9].score - ranked[35].score
            samples += 1
        }

        guard samples > 0 else {
            print("❌ Keine verwertbaren Tests")
            return
        }

        print("-----------------------------------")
        print("Ø SCORE-ABSTÄNDE")
        print("-----------------------------------")
        print(String(format: "P01 → P09 : %.6f", gap1to9 / Double(samples)))
        print(String(format: "P09 → P10 : %.6f", gap9to10 / Double(samples)))
        print(String(format: "P10 → P36 : %.6f", gap10to36 / Double(samples)))
        print("-----------------------------------")
        print(String(format: "Tests     : %d", samples))
        print(String(format: "⏱ Score-Gap: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }
}
