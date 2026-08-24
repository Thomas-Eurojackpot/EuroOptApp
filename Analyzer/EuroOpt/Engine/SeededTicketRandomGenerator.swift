//
//  SeededTicketRandomGenerator.swift
//  EuroOpt
//
//  Deterministic random generator used only by backtests.
//

import Foundation

final class SeededTicketRandomGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    @inline(__always)
    func randomInt(_ upperBound: Int) -> Int {

        Int(next() % UInt64(upperBound))
    }

    @inline(__always)
    func randomIndex(_ upperBound: Int) -> Int {

        randomInt(upperBound)
    }

    func makeTicket() -> Ticket {

        var numbers = Set<Int>()

        while numbers.count < 5 {
            numbers.insert(randomInt(50) + 1)
        }

        var euroNumbers = Set<Int>()

        while euroNumbers.count < 2 {
            euroNumbers.insert(randomInt(12) + 1)
        }

        return Ticket(
            numbers: numbers.sorted(),
            euroNumbers: euroNumbers.sorted()
        )
    }

    @inline(__always)
    private func next() -> UInt64 {

        state =
            state &* 6364136223846793005
            &+ 1442695040888963407

        return state
    }
}

