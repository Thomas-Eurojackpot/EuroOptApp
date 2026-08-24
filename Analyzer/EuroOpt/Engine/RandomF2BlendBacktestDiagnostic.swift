import Foundation

final class RandomF2BlendBacktestDiagnostic {

    private let warmup = 100
    private let ticketCount = 9
    private let f2Counts = [0, 1, 2, 3]

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > warmup else {
            print("❌ Zufall + F2: zu wenige Ziehungen")
            return
        }

        let evaluatedDraws = draws.count - warmup

        struct Summary {
            var winDraws = 0
            var winTickets = 0
            var classes: [String: Int] = [:]
        }

        var summaries: [Int: Summary] = [:]
        for count in f2Counts {
            summaries[count] = Summary()
        }

        func result(
            _ ticket: Ticket,
            _ draw: EuroJackpotDraw
        ) -> (Int, Int) {

            (
                Set(ticket.numbers).intersection(draw.numbers).count,
                Set(ticket.euroNumbers).intersection(draw.euroNumbers).count
            )
        }

        func isWinning(_ main: Int, _ euro: Int) -> Bool {
            main >= 3 || (main >= 2 && euro >= 1)
        }

        func makeF2Ticket(from training: [EuroJackpotDraw]) -> Ticket {

            let source = Array(training.suffix(50))

            var mainCounts: [Int: Int] = [:]
            var euroCounts: [Int: Int] = [:]

            for draw in source {
                for number in draw.numbers {
                    mainCounts[number, default: 0] += 1
                }

                for number in draw.euroNumbers {
                    euroCounts[number, default: 0] += 1
                }
            }

            let main = Array(1...50)
                .sorted {
                    let left = mainCounts[$0, default: 0]
                    let right = mainCounts[$1, default: 0]
                    return left == right ? $0 < $1 : left > right
                }
                .prefix(5)

            let euro = Array(1...12)
                .sorted {
                    let left = euroCounts[$0, default: 0]
                    let right = euroCounts[$1, default: 0]
                    return left == right ? $0 < $1 : left > right
                }
                .prefix(2)

            return Ticket(
                numbers: Array(main),
                euroNumbers: Array(euro)
            )
        }

        func makeRandomTickets(count: Int) -> [Ticket] {

            var tickets: [Ticket] = []
            tickets.reserveCapacity(count)

            for _ in 0..<count {

                let main = Array(1...50)
                    .shuffled()
                    .prefix(5)
                    .sorted()

                let euro = Array(1...12)
                    .shuffled()
                    .prefix(2)
                    .sorted()

                tickets.append(
                    Ticket(
                        numbers: Array(main),
                        euroNumbers: Array(euro)
                    )
                )
            }

            return tickets
        }

        for index in warmup..<draws.count {

            let training = Array(draws.prefix(index))
            let target = draws[index]

            // One common set of 9 random tickets for every blend level.
            // Only the number of F2 replacements changes.
            let randomTickets = makeRandomTickets(count: ticketCount)
            let f2Ticket = makeF2Ticket(from: training)

            for f2Count in f2Counts {

                var tickets = randomTickets

                if f2Count > 0 {
                    for slot in 0..<f2Count {
                        tickets[slot] = f2Ticket
                    }
                }

                let results = tickets.map {
                    result($0, target)
                }

                let wins = results.filter {
                    isWinning($0.0, $0.1)
                }

                if !wins.isEmpty {
                    summaries[f2Count]!.winDraws += 1
                }

                summaries[f2Count]!.winTickets += wins.count

                for (main, euro) in results {
                    let key = "\(main)+\(euro)"
                    summaries[f2Count]!.classes[key, default: 0] += 1
                }
            }
        }

        print("")
        print("==============================================")
        print("ZUFALL + F2-BEIMISCHUNG")
        print("==============================================")
        print("Ziehungen: \(evaluatedDraws)")
        print("9 Tipps je Ziehung")
        print("F2: häufigste 5+2 Zahlen der letzten 50 Ziehungen")
        print("Gemeinsame Zufallsbasis je Ziehung: JA")
        print("==============================================")
        print("F2-Tipps | Zufall | F2 | Gewinn-Ziehungen | Quote | Gewinn-Tickets")
        print("------------------------------------------------------------------")

        for f2Count in f2Counts {

            let randomCount = ticketCount - f2Count
            let summary = summaries[f2Count]!

            print(
                String(
                    format: "%8d | %6d | %2d | %16d | %5.1f%% | %14d",
                    f2Count,
                    randomCount,
                    f2Count,
                    summary.winDraws,
                    Double(summary.winDraws) /
                        Double(evaluatedDraws) * 100,
                    summary.winTickets
                )
            )
        }

        print("")
        print("GEWINNKLASSEN – AB 2+1")
        print("==============================================")
        print("Gewinnklasse | 9Zufall | 8Z+1F2 | 7Z+2F2 | 6Z+3F2")
        print("----------------------------------------------")

        let labels = [
            "2+1", "2+2",
            "3+0", "3+1", "3+2",
            "4+0", "4+1", "4+2",
            "5+0", "5+1", "5+2"
        ]

        for label in labels {

            let values = f2Counts.map {
                summaries[$0]!.classes[label, default: 0]
            }

            print(
                String(
                    format: "%-11@ | %7d | %7d | %7d | %7d",
                    label,
                    values[0],
                    values[1],
                    values[2],
                    values[3]
                )
            )
        }

        print("==============================================")
    }
}

