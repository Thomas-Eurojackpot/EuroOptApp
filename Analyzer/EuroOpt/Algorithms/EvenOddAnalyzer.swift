import Foundation

final class EvenOddAnalyzer {

    func distribution(in draws: [EuroJackpotDraw]) -> [String:Int] {

        var result: [String:Int] = [:]

        for draw in draws {

            let even = draw.numbers.filter { $0.isMultiple(of: 2) }.count
            let odd = 5 - even

            let key = "\(even):\(odd)"

            result[key, default: 0] += 1

        }

        return result

    }

}
