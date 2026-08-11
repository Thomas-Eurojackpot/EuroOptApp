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

    @Published var reports: [OptimizerReport] = []

    @Published var isCalculating = false

    @Published var isBacktestRunning = false
    @Published var backtestProgress: Double = 0
    @Published var backtestStatus = "Bereit"

    @Published var isLearning = false
    @Published var learningStatus = "Bereit"

    @Published var isHoldoutRunning = false
    @Published var holdoutStatus = "Bereit"
    @Published var lastHoldoutResult: HoldoutResult?

    @Published var lastBacktestStatistics: BacktestStatistics?
    @Published var lastBacktestDuration: Double = 0

    private let database = DrawDatabase()
    private let optimizer = OptimizerEngine()
    private let generator = TicketGenerator()
    private let backtest = BacktestEngine()
    private let learningEngine = LearningEngine()

    var shareText: String {

        guard !reports.isEmpty else {
            return "Noch keine Empfehlungen vorhanden."
        }

        var text = """
🎯 EuroOpt – Top \(reports.count) Empfehlungen

🍀 Erstellt mit EuroOpt Alpha 7.0

────────────────────

"""

        let medals = ["🥇","🥈","🥉"]

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

    func calculateRecommendations(
        candidateCount: Int,
        recommendationCount: Int
    ) {

        isCalculating = true

        let draws = database.allDraws()

        let candidates = generator.generate(
            count: candidateCount,
            draws: draws
        )

        let bestTickets = optimizer.bestTickets(
            from: candidates,
            draws: draws,
            limit: recommendationCount
        )

        reports = bestTickets.map {

            OptimizerReport(
                ticket: $0.ticket,
                eqi: EQI(value: $0.score)
            )

        }

        isCalculating = false

    }

    func runBacktest() {

        let draws = database.allDraws()

        isBacktestRunning = true
        backtestProgress = 0
        backtestStatus = "Backtest läuft..."

        lastBacktestStatistics = nil
        lastBacktestDuration = 0

        let start = Date()

        DispatchQueue.global(qos: .userInitiated).async {

            let results = self.backtest.run(
                draws: draws,
                candidateCount: AppSettings.backtestCandidateCount,
                recommendationCount: AppSettings.recommendationCount
            ) { progress, current, total in

                DispatchQueue.main.async {

                    self.backtestProgress = progress
                    self.backtestStatus = "\(current) von \(total)"

                }

            }

            let statistics = BacktestStatistics.calculate(
                from: results
            )

            let duration = Date().timeIntervalSince(start)

            DispatchQueue.main.async {

                self.lastBacktestStatistics = statistics
                self.lastBacktestDuration = duration
                self.backtestProgress = 1
                self.backtestStatus = "Backtest beendet"
                self.isBacktestRunning = false

            }

        }

    }

    func startLearning() {

        let draws = database.allDraws()

        isLearning = true
        learningStatus = "Walk-Forward-Lernen läuft..."

        DispatchQueue.global(qos: .userInitiated).async {

            _ = self.learningEngine.learn(
                draws: draws,
                candidateCount: AppSettings.backtestCandidateCount,
                recommendationCount: AppSettings.recommendationCount,
                generations: 8
            )

            DispatchQueue.main.async {

                self.learningStatus = "Walk-Forward-Lernen beendet"
                self.isLearning = false

            }

        }

    }

    func runHoldout() {

        let draws = database.allDraws()

        isHoldoutRunning = true
        holdoutStatus = "Training auf 80 % der Daten..."
        lastHoldoutResult = nil

        DispatchQueue.global(qos: .userInitiated).async {

            let result = self.learningEngine.runHoldout(
                draws: draws,
                candidateCount: AppSettings.backtestCandidateCount,
                recommendationCount: AppSettings.recommendationCount,
                generations: 8
            )

            DispatchQueue.main.async {

                self.lastHoldoutResult = result
                self.holdoutStatus = result == nil
                    ? "Holdout-Test nicht möglich"
                    : "Holdout-Test beendet"
                self.isHoldoutRunning = false

            }

        }

    }

}
