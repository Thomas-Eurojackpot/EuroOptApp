//
//  OptimizerViewModel.swift
//  EuroOpt
//
//  Alpha 7.5
//

import Foundation
import Combine

@MainActor
final class OptimizerViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var reports: [OptimizerReport] = []

    @Published var isCalculating = false

    @Published var isBacktestRunning = false
    @Published var backtestProgress: Double = 0
    @Published var backtestStatus = "Bereit"

    @Published var isLearning = false
    @Published var learningStatus = "Noch kein Lernlauf gestartet"
    @Published var learnedGoal = OptimizationGoalStore.shared.currentGoal
    @Published var learningResult: LearningResult?

    // MARK: - Private Properties

    private let database = DrawDatabase()
    private let optimizer = OptimizerEngine()
    private let generator = TicketGenerator()
    private let backtest = BacktestEngine()
    private let learningEngine = LearningEngine()

    // MARK: - Learned Profile

    var learnedProfileText: String {
        let goal = learnedGoal

        return String(
            format: "F %.0f  |  P %.0f  |  G/U %.0f  |  H/N %.0f  |  S %.0f  |  A %.0f",
            goal.frequencyWeight,
            goal.pairWeight,
            goal.evenOddWeight,
            goal.highLowWeight,
            goal.sumWeight,
            goal.gapWeight
        )
    }

    // MARK: - Share Text

    var shareText: String {

        guard !reports.isEmpty else {
            return "Noch keine Empfehlungen vorhanden."
        }

        var text = """
🎯 EuroOpt – Top \(reports.count) Empfehlungen

🍀 Erstellt mit EuroOpt Alpha 7.5

────────────────────

"""

        let medals = ["🥇", "🥈", "🥉"]

        for (index, report) in reports.enumerated() {

            let medal = index < medals.count ? medals[index] : "⭐"

            text += """
\(medal) Empfehlung \(index + 1)

🎲 Hauptzahlen
\(report.ticket.numbers.map(String.init).joined(separator: " • "))

⭐ Eurozahlen
\(report.ticket.euroNumbers.map(String.init).joined(separator: " • "))

📈 EQI: \(String(format: "%.1f", report.eqi.value).replacingOccurrences(of: ".", with: ","))

\(report.recommendation)

────────────────────

"""

        }

        text += "🍀 Viel Glück!"
        return text
    }

    // MARK: - Empfehlungen

    func calculateRecommendations(
        candidateCount: Int,
        recommendationCount: Int
    ) {

        print("================================")
        print("🎯 Gewählte Spielsysteme: \(candidateCount)")
        print("🏆 Gewünschte Empfehlungen: \(recommendationCount)")
        print("🧠 Verwendetes Profil: \(learnedProfileText)")
        print("================================")

        isCalculating = true

        let start = Date()
        let draws = database.allDraws()
        let goal = OptimizationGoalStore.shared.currentGoal

        print("📊 Ziehungen geladen: \(draws.count)")

        let candidates = generator.generate(
            count: candidateCount,
            draws: draws,
            goal: goal
        )

        print("🎲 Erzeugte Spielsysteme: \(candidates.count)")

        let bestTickets = optimizer.bestTickets(
            from: candidates,
            draws: draws,
            goal: goal,
            limit: recommendationCount
        )

        print("🥇 Beste Spielsysteme: \(bestTickets.count)")

        reports = bestTickets.map {
            OptimizerReport(
                ticket: $0.ticket,
                eqi: EQI(value: $0.score)
            )
        }

        let duration = Date().timeIntervalSince(start)

        print("--------------------------------")
        print(String(format: "⏱ Gesamtzeit: %.2f Sekunden", duration))
        print("--------------------------------")

        isCalculating = false
    }

    // MARK: - 🧠 Gewichte lernen

    func startLearning() {
        guard !isLearning, !isCalculating, !isBacktestRunning else { return }

        let draws = database.allDraws()
        let recommendationCount = AppSettings.recommendationCount

        isLearning = true
        learningStatus = "Walk-Forward-Lernen läuft..."
        learningResult = nil

        print("===================================")
        print("🧠 GEWICHTE LERNEN")
        print("===================================")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let result = self.learningEngine.learn(
                draws: draws,
                recommendationCount: recommendationCount,
                candidateCount: max(AppSettings.backtestCandidateCount + 1, 501)
            )

            DispatchQueue.main.async {
                self.learnedGoal = result.goal
                self.learningResult = result
                self.learningStatus = "Lernen beendet – Profil gespeichert"
                self.isLearning = false
            }
        }
    }

    func resetLearnedWeights() {
        guard !isLearning, !isCalculating, !isBacktestRunning else { return }

        OptimizationGoalStore.shared.reset()
        learnedGoal = OptimizationGoalStore.shared.currentGoal
        learningResult = nil
        learningStatus = "Standardprofil wiederhergestellt"
    }

    // MARK: - Backtest

    func runBacktest() {
        guard !isLearning else { return }

        let draws = database.allDraws()

        isBacktestRunning = true
        backtestProgress = 0
        backtestStatus = "Backtest läuft..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            _ = self.backtest.run(
                draws: draws,
                candidateCount: AppSettings.backtestCandidateCount,
                recommendationCount: AppSettings.recommendationCount
            ) { progress, current, total in

                DispatchQueue.main.async {
                    self.backtestProgress = progress
                    self.backtestStatus = "\(current) von \(total) Ziehungen"
                }
            }

            let componentBacktest = ComponentBacktestEngine()
            componentBacktest.run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.backtestProgress = 1.0
                self.backtestStatus = "Backtest + Komponententest beendet"
                self.isBacktestRunning = false
            }
        }
    }
}
