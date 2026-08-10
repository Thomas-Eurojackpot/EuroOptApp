//
//  OptimizerViewModel.swift
//  EuroOpt
//
//  Alpha 6.5
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

    // MARK: - Private Properties

    private let database = DrawDatabase()
    private let optimizer = OptimizerEngine()
    private let generator = TicketGenerator()
    private let backtest = BacktestEngine()
    private let componentBacktest = ComponentBacktestEngine()

    // MARK: - Share Text

    var shareText: String {

        guard !reports.isEmpty else {
            return "Noch keine Empfehlungen vorhanden."
        }

        var text = """
🎯 EuroOpt – Top \(reports.count) Empfehlungen

🍀 Erstellt mit EuroOpt Alpha 6.5

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

        text += """
🍀 Viel Glück!
"""

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
        print("================================")

        isCalculating = true

        let start = Date()

        let draws = database.allDraws()

        print("📊 Ziehungen geladen: \(draws.count)")

        let candidates = generator.generate(
            count: candidateCount,
            draws: draws
        )

        print("🎲 Erzeugte Spielsysteme: \(candidates.count)")

        let bestTickets = optimizer.bestTickets(
            from: candidates,
            draws: draws,
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

    // MARK: - Backtest

    func runBacktest() {

        let draws = database.allDraws()

        isBacktestRunning = true
        backtestProgress = 0
        backtestStatus = "Backtest läuft..."

        DispatchQueue.global(qos: .userInitiated).async {

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

            self.componentBacktest.run(
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
