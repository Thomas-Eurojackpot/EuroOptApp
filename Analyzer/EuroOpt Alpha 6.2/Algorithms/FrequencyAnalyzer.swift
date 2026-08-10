import Foundation

class FrequencyAnalyzer {

    func frequency(of draws: [EuroJackpotDraw]) -> [Int:Int] {

        var counter: [Int:Int] = [:]

        for number in 1...50 {
            counter[number] = 0
        }

        for draw in draws {
            for number in draw.numbers {
                counter[number, default: 0] += 1
            }
        }

        return counter
    }

    func sortedFrequency(of draws: [EuroJackpotDraw]) -> [(number: Int, count: Int)] {

        let frequencies = frequency(of: draws)

        return frequencies
            .map { (number: $0.key, count: $0.value) }
            .sorted { lhs, rhs in

                if lhs.count == rhs.count {
                    return lhs.number < rhs.number
                }

                return lhs.count > rhs.count
            }

    }

}
