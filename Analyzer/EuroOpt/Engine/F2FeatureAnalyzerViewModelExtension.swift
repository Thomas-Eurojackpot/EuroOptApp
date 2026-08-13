import Foundation

@MainActor
extension OptimizerViewModel {
    func runF2FeatureAnalysis() {
        guard !isCalculating,
              !isBacktestRunning,
              !isHoldoutRunning,
              !isParityRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isConfirmationRunning,
              !isRobustnessRunning,
              !isLearning else { return }

        let draws = DrawDatabase().allDraws()
        print("===================================")
        print("🔗 F2/50 KORRELATIONS-ANALYSE")
        print("===================================")
        DispatchQueue.global(qos: .userInitiated).async {
            F2CorrelationAnalyzer().run(draws: draws)
        }
    }
}
