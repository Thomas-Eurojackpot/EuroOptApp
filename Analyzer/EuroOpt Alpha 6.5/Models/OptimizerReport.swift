//
//  OptimizerReport.swift
//  EuroOpt
//
//  Alpha 6.2
//

import Foundation

struct OptimizerReport: Identifiable {

    // MARK: - Properties

    let id = UUID()

    let ticket: Ticket

    let eqi: EQI

    /// Detailergebnis der Bewertungs-Engine
    let scoreResult: ScoreResult?

    // MARK: - Initializer

    init(
        ticket: Ticket,
        eqi: EQI,
        scoreResult: ScoreResult? = nil
    ) {

        self.ticket = ticket
        self.eqi = eqi
        self.scoreResult = scoreResult

    }

    // MARK: - Computed Properties

    var score: Double {
        eqi.value
    }

    var recommendation: String {
        eqi.rating
    }

    var hasDetails: Bool {
        scoreResult != nil
    }

    /// Text zum Teilen (WhatsApp, Mail, Nachrichten usw.)
    var shareText: String {

        """
        🎯 EuroOpt Empfehlung

        Hauptzahlen:
        \(ticket.numbers.map(String.init).joined(separator: " • "))

        Eurozahlen:
        ⭐ \(ticket.euroNumbers.map(String.init).joined(separator: " • ⭐ "))

        EQI:
        \(String(format: "%.1f", eqi.value))

        Bewertung:
        \(recommendation)

        Erstellt mit EuroOpt
        """

    }

}
