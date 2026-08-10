//
//  BacktestResult.swift
//  EuroOpt
//
//  Alpha 6.5
//

import Foundation

struct BacktestResult: Identifiable {

    let id = UUID()

    let drawDate: Date

    let recommendationCount: Int

    // Alle getesteten Empfehlungen

    let ticketResults: [BacktestTicketResult]

    // Beste Empfehlung

    let bestHits: Int

    let bestEuroHits: Int

    // Durchschnitt

    let averageHits: Double

    let averageEuroHits: Double

    let averageEQI: Double

    // Statistik

    let testedTickets: Int

    var prizeClass: String {

        "\(bestHits)+\(bestEuroHits)"

    }

}
