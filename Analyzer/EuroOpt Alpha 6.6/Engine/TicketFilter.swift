import Foundation

final class TicketFilter {

    func filter(_ tickets: [Ticket]) -> [Ticket] {

        tickets.filter { ticket in

            let even = ticket.numbers.filter { $0.isMultiple(of: 2) }.count
            guard even == 2 || even == 3 else {
                return false
            }

            let high = ticket.numbers.filter { $0 > 25 }.count
            guard high == 2 || high == 3 else {
                return false
            }

            let sum = ticket.numbers.reduce(0, +)
            guard (90...180).contains(sum) else {
                return false
            }

            return true

        }

    }

}
