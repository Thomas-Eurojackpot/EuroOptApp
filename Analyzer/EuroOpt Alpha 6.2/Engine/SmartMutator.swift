//
//  SmartMutator.swift
//  EuroOpt
//
//  Smart Generator 2.0
//

import Foundation

final class SmartMutator {

    func mutate(ticket: Ticket) -> Ticket? {

        switch Int.random(in: 0...2) {

        case 0:
            return mutateMainNumber(ticket: ticket)

        case 1:
            return mutateEuroNumber(ticket: ticket)

        default:
            return mutateTwoMainNumbers(ticket: ticket)

        }

    }

    // MARK: - Eine Hauptzahl tauschen

    private func mutateMainNumber(
        ticket: Ticket
    ) -> Ticket? {

        var numbers = ticket.numbers

        guard let index = numbers.indices.randomElement() else {
            return nil
        }

        var available = Array(1...50)

        available.removeAll {
            numbers.contains($0)
        }

        guard let newNumber = available.randomElement() else {
            return nil
        }

        numbers[index] = newNumber
        numbers.sort()

        return Ticket(
            numbers: numbers,
            euroNumbers: ticket.euroNumbers
        )

    }

    // MARK: - Eine Eurozahl tauschen

    private func mutateEuroNumber(
        ticket: Ticket
    ) -> Ticket? {

        var euroNumbers = ticket.euroNumbers

        guard let index = euroNumbers.indices.randomElement() else {
            return nil
        }

        var available = Array(1...12)

        available.removeAll {
            euroNumbers.contains($0)
        }

        guard let newNumber = available.randomElement() else {
            return nil
        }

        euroNumbers[index] = newNumber
        euroNumbers.sort()

        return Ticket(
            numbers: ticket.numbers,
            euroNumbers: euroNumbers
        )

    }

    // MARK: - Zwei Hauptzahlen tauschen

    private func mutateTwoMainNumbers(
        ticket: Ticket
    ) -> Ticket? {

        var numbers = ticket.numbers

        let indices = Array(numbers.indices).shuffled()

        guard indices.count >= 2 else {
            return nil
        }

        let first = indices[0]
        let second = indices[1]

        var available = Array(1...50)

        available.removeAll {
            numbers.contains($0)
        }

        guard available.count >= 2 else {
            return nil
        }

        available.shuffle()

        numbers[first] = available[0]
        numbers[second] = available[1]

        numbers.sort()

        return Ticket(
            numbers: numbers,
            euroNumbers: ticket.euroNumbers
        )

    }

}
