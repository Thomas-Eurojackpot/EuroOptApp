//
//  OptimizerViewModel.swift
//  EuroOpt
//
//  Alpha 6.4
//

import Foundation
import Combine

@MainActor
final class OptimizerViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var reports: [OptimizerReport] = []

    @Published var isCalculating = false

    // MARK: - Private Properties

    private let database = DrawDatabase()
    private let optimizer = OptimizerEngine()
    private let generator = TicketGenerator()

    // MARK: - Share Text

    var shareText: String {

        guard !reports.isEmpty else {
            return "Noch keine Empfehlungen vorhanden."
        }

        var text = """
🎯 EuroOpt – Top \(reports.count) Empfehlungen

🍀 Erstellt mit EuroOpt Alpha 6.4

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

    // MARK: - Public Methods

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

}
