//
//  Ticket.swift
//  EuroOpt
//
//  Alpha 6.1
//

import Foundation

struct Ticket: Hashable, Identifiable {

    let id = UUID()

    let numbers: [Int]

    let euroNumbers: [Int]

}
