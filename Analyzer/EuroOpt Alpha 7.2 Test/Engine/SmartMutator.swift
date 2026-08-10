//
//  SmartMutator.swift
//  EuroOpt
//
//  Alpha 7.3
//

import Foundation

final class SmartMutator {

    @inline(__always)
    func mutate(ticket: Ticket) -> Ticket? {

        let r = Int.random(in: 0..<100)

        switch r {

        case 0..<55:
            return mutateMainNumber(ticket: ticket)

        case 55..<80:
            return mutateTwoMainNumbers(ticket: ticket)

        default:
            return mutateEuroNumber(ticket: ticket)

        }

    }

    // MARK: - Eine Hauptzahl tauschen

    @inline(__always)
    private func mutateMainNumber(
        ticket: Ticket
    ) -> Ticket? {

        var numbers = ticket.numbers

        guard let index = numbers.indices.randomElement() else {
            return nil
        }

        var used = Set(numbers)
        used.remove(numbers[index])

        numbers[index] = randomUnused(
            max: 50,
            used: used
        )

        numbers.sort()

        return Ticket(
            numbers: numbers,
            euroNumbers: ticket.euroNumbers
        )

    }

    // MARK: - Zwei Hauptzahlen tauschen

    @inline(__always)
    private func mutateTwoMainNumbers(
        ticket: Ticket
    ) -> Ticket? {

        var numbers = ticket.numbers

        guard numbers.count >= 2 else {
            return nil
        }

        var indices = Array(numbers.indices)
        indices.shuffle()

        let first = indices[0]
        let second = indices[1]

        var used = Set(numbers)
        used.remove(numbers[first])
        used.remove(numbers[second])

        numbers[first] = randomUnused(
            max: 50,
            used: used
        )

        used.insert(numbers[first])

        numbers[second] = randomUnused(
            max: 50,
            used: used
        )

        numbers.sort()

        return Ticket(
            numbers: numbers,
            euroNumbers: ticket.euroNumbers
        )

    }

    // MARK: - Eurozahlen

    @inline(__always)
    private func mutateEuroNumber(
        ticket: Ticket
    ) -> Ticket? {

        var euroNumbers = ticket.euroNumbers

        guard let index = euroNumbers.indices.randomElement() else {
            return nil
        }

        var used = Set(euroNumbers)
        used.remove(euroNumbers[index])

        euroNumbers[index] = randomUnused(
            max: 12,
            used: used
        )

        euroNumbers.sort()

        return Ticket(
            numbers: ticket.numbers,
            euroNumbers: euroNumbers
        )

    }

    // MARK: - Helper

    @inline(__always)
    private func randomUnused(
        max: Int,
        used: Set<Int>
    ) -> Int {

        while true {

            let value = Int.random(in: 1...max)

            if !used.contains(value) {
                return value
            }

        }

    }

}
