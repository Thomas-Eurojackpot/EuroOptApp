//
//  BacktestTicketResult.swift
//  EuroOpt
//
//  Alpha 6.5
//

import Foundation

struct BacktestTicketResult: Identifiable {

    let id = UUID()

    let rank: Int

    let hits: Int

    let euroHits: Int

    let eqi: Double

    var prizeClass: String {

        "\(hits)+\(euroHits)"

    }

}
