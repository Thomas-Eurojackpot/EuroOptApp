//
//  QuickScore.swift
//  EuroOpt
//
//  Alpha 6.4
//

import Foundation

final class QuickScore {

    @inline(__always)
    func calculate(
        ticket: Ticket
    ) -> Double {

        let numbers = ticket.numbers

        var score = 0.0

        var sum = 0
        var even = 0
        var high = 0

        var consecutive = 1
        var maxConsecutive = 1
        var smallGaps = 0

        for index in numbers.indices {

            let value = numbers[index]

            sum += value

            if value.isMultiple(of: 2) {
                even += 1
            }

            if value > 25 {
                high += 1
            }

            guard index > 0 else {
                continue
            }

            let gap = value - numbers[index - 1]

            if gap == 1 {

                consecutive += 1

                if consecutive > maxConsecutive {
                    maxConsecutive = consecutive
                }

            } else {

                consecutive = 1

            }

            if gap <= 2 {
                smallGaps += 1
            }

        }

        if sum >= AppSettings.minimumSum &&
            sum <= AppSettings.maximumSum {

            score += 30

        }

        if even >= AppSettings.minimumEvenNumbers &&
            even <= AppSettings.maximumEvenNumbers {

            score += 20

        }

        if high >= AppSettings.minimumHighNumbers &&
            high <= AppSettings.maximumHighNumbers {

            score += 20

        }

        if maxConsecutive <= AppSettings.maximumConsecutiveNumbers {

            score += 15

        }

        if smallGaps <= AppSettings.maximumSmallGaps {

            score += 15

        }

        return score

    }

}
