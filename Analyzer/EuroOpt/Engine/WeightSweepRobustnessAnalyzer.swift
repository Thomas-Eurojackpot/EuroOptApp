//
//  WeightSweepRobustnessAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.5 - robustness analysis
//  Separate analyzer. Does not modify WeightSweepEngine.
//

import Foundation

/// Repeats the Alpha 7.5 validation/holdout split over several temporal windows.
///
/// Important:
/// - Alpha 7.5's WeightSweepEngine remains untouched.
/// - The same warm-up size (100) and 50/50 validation/holdout principle are used.
/// - No profile is preferred in advance; A100 is treated exactly like every other profile.
/// - This component is analysis-only and does not change recommendation generation.
final class WeightSweepRobustnessAnalyzer {

    private struct ProfileResult {
        let profileID: Int
        let label: String
        let score: Double
    }

    private struct SplitResult {
        let split: Int
        let validationStart: Int
        let validationEnd: Int
        let holdoutStart: Int
        let holdoutEnd: Int
        let winner: ProfileResult
    }

    private let warmup = 100
    private let profileCount = 32

    /// Runs a lightweight structural robustness analysis.
    ///
    /// The actual scoring mechanics are intentionally delegated to the existing
    /// WeightSweepEngine in the production path. This first version reports the
    /// temporal split plan only, so no second scoring implementation can silently
    /// diverge from Alpha 7.5.
    func run(draws: [EuroJackpotDraw], splitCount: Int = 5) {
        guard draws.count > warmup + 20 else {
            print("❌ Alpha 7.5 Robustheit: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - warmup
        let requestedSplits = max(1, splitCount)
        let availableWindow = totalTests / requestedSplits

        print("")
        print("===================================")
        print("🧪 ALPHA 7.5 ROBUSTHEITS-ANALYSE")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("Testbereich         : \(totalTests)")
        print("Geplante Splits     : \(requestedSplits)")
        print("Split-Prinzip       : Validation 50 % / Holdout 50 %")
        print("Profile             : \(profileCount)")
        print("Profilwahl          : ausschließlich Validation")
        print("Holdout              : erst nach Profilwahl")
        print("")
        print("⚠️ Diese erste Version verändert WeightSweepEngine nicht.")
        print("⚠️ Die Split-Struktur wird bewusst separat geprüft, bevor eine zweite Scoring-Implementierung entsteht.")
        print("")

        var splits: [SplitResult] = []

        for split in 0..<requestedSplits {
            let validationStart = warmup + split * availableWindow
            let splitEnd = split == requestedSplits - 1
                ? draws.count
                : min(draws.count, warmup + (split + 1) * availableWindow)
            let splitSize = splitEnd - validationStart

            guard splitSize >= 2 else { continue }

            let validationSize = splitSize / 2
            let holdoutStart = validationStart + validationSize
            let holdoutEnd = splitEnd

            let placeholderWinner = ProfileResult(
                profileID: 0,
                label: "noch nicht ausgeführt",
                score: 0
            )

            splits.append(
                SplitResult(
                    split: split + 1,
                    validationStart: validationStart,
                    validationEnd: holdoutStart,
                    holdoutStart: holdoutStart,
                    holdoutEnd: holdoutEnd,
                    winner: placeholderWinner
                )
            )
        }

        print("SPLIT-PLAN")
        print("-----------------------------------")
        for result in splits {
            print(String(format: "Split %d | Validation [%d..<%d] | Holdout [%d..<%d]",
                         result.split,
                         result.validationStart,
                         result.validationEnd,
                         result.holdoutStart,
                         result.holdoutEnd))
        }

        print("")
        print("Nächster Schritt: Diese Splits werden mit exakt derselben WeightSweepEngine-Scoringlogik ausgeführt.")
        print("Kein Profil wird bevorzugt.")
        print("")
        print(String(format: "⏱ Robustheits-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }
}
