//
//  SmartMutator.swift
//  EuroOpt
//
//  Smart Generator 2.1
//  Alpha 6.4
//

import Foundation

final class SmartMutator {

    @inline(__always)
    func mutate(ticket: Ticket) -> Ticket? {

        switch Int.random(in: 0..<3) {

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

        let used = Set(numbers)

        var newNumber: Int

        repeat {
            newNumber = Int.random(in: 1...50)
        } while used.contains(newNumber)

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

        let used = Set(euroNumbers)

        var newNumber: Int

        repeat {
            newNumber = Int.random(in: 1...12)
        } while used.contains(newNumber)

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

        guard numbers.count >= 2 else {
            return nil
        }

        var shuffled = Array(numbers.indices)
        shuffled.shuffle()

        let first = shuffled[0]
        let second = shuffled[1]

        var used = Set(numbers)

        var firstNumber: Int

        repeat {
            firstNumber = Int.random(in: 1...50)
        } while used.contains(firstNumber)

        used.insert(firstNumber)

        var secondNumber: Int

        repeat {
            secondNumber = Int.random(in: 1...50)
        } while used.contains(secondNumber)

        numbers[first] = firstNumber
        numbers[second] = secondNumber

        numbers.sort()

        return Ticket(
            numbers: numbers,
            euroNumbers: ticket.euroNumbers
        )

    }

}
