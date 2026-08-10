import Foundation

final class ScoreNormalizer {

    func normalize(_ score: Double) -> Double {

        max(0, min(score, 100))

    }

}
