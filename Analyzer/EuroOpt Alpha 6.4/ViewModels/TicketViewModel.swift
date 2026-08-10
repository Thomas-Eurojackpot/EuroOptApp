import Foundation
import Combine

final class TicketViewModel: ObservableObject {

    @Published var numbers: [Int] = [
        4,
        8,
        17,
        31,
        45
    ]

    @Published var euroNumbers: [Int] = [
        2,
        10
    ]

    var ticket: Ticket {

        Ticket(
            numbers: numbers.sorted(),
            euroNumbers: euroNumbers.sorted()
        )

    }

    func updateNumber(at index: Int, value: Int) {

        guard index >= 0 && index < numbers.count else {
            return
        }

        numbers[index] = value

    }

    func updateEuroNumber(at index: Int, value: Int) {

        guard index >= 0 && index < euroNumbers.count else {
            return
        }

        euroNumbers[index] = value

    }

}
