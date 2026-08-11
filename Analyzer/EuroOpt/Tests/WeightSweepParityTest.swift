//
//  WeightSweepParityTest.swift
//  EuroOpt
//
//  Alpha 7.5 - parity verification only
//
//  This test does not change Alpha 7.5 production behavior.
//  It is intentionally limited to deterministic inputs supplied by the caller.
//

import Foundation

/// Small verification helper for comparing the existing WeightSweep scoring
/// path with the shared WeightSweepCore using exactly the same candidate data.
///
/// The test deliberately does NOT call TicketGenerator.generate(), because that
/// generator uses Int.random(in:) and therefore cannot provide reproducible
/// candidates without changing production behavior.
final class WeightSweepParityTest {

    struct Result {
        let profilesCompared: Int
        let identicalProfileScores: Bool
        let identicalWinner: Bool
    }

    /// Compares two already-computed profile result arrays.
    ///
    /// This is intentionally a pure comparison layer. Candidate generation,
    /// Alpha 7.5 holdout selection and production ticket generation remain
    /// untouched.
    func compare(
        legacyScores: [(profileID: Int, score: Double)],
        coreScores: [(profileID: Int, score: Double)],
        tolerance: Double = 0.0000001
    ) -> Result {

        guard legacyScores.count == coreScores.count else {
            return Result(
                profilesCompared: min(legacyScores.count, coreScores.count),
                identicalProfileScores: false,
                identicalWinner: false
            )
        }

        let legacy = legacyScores.sorted { $0.profileID < $1.profileID }
        let core = coreScores.sorted { $0.profileID < $1.profileID }

        let identicalScores = zip(legacy, core).allSatisfy { lhs, rhs in
            lhs.profileID == rhs.profileID &&
            abs(lhs.score - rhs.score) <= tolerance
        }

        let legacyWinner = legacy.max { $0.score < $1.score }?.profileID
        let coreWinner = core.max { $0.score < $1.score }?.profileID

        let identicalWinner = legacyWinner == coreWinner

        print("")
        print("===================================")
        print("🧪 WEIGHT SWEEP PARITY TEST")
        print("===================================")
        print("Profile verglichen : \(legacy.count)")
        print("Scores identisch   : \(identicalScores ? "JA" : "NEIN")")
        print("Winner identisch   : \(identicalWinner ? "JA" : "NEIN")")
        print("Legacy Winner      : \(legacyWinner.map(String.init) ?? "-")")
        print("Core Winner        : \(coreWinner.map(String.init) ?? "-")")

        if identicalScores && identicalWinner {
            print("✅ PARITÄT BESTÄTIGT")
        } else {
            print("❌ PARITÄT NICHT BESTÄTIGT")
        }

        print("===================================")

        return Result(
            profilesCompared: legacy.count,
            identicalProfileScores: identicalScores,
            identicalWinner: identicalWinner
        )
    }
}
