import Foundation

final class EQICalculator {

    private let mainWeight = 0.85
    private let euroWeight = 0.15

    private let frequencyScore = FrequencyScore()
    private let pairScore = PairScore()
    private let evenOddScore = EvenOddScore()
    private let highLowScore = HighLowScore()
    private let sumScore = SumScore()
    private let gapScore = GapScore()
    private let euroFrequencyScore = EuroFrequencyScore()

    func calculate(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> Double {

        let frequency = frequencyScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let pairs = pairScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let evenOdd = evenOddScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let highLow = highLowScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let sum = sumScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let gap = gapScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let euro = euroFrequencyScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let mainAverage =
            (frequency + pairs + evenOdd + highLow + sum + gap) / 6.0

        let eqi =
            mainAverage * mainWeight
            + euro * euroWeight

        return min(100.0, max(0.0, eqi))
    }
}
