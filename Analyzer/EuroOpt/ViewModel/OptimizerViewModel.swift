
import Foundation
import Combine

@MainActor
final class OptimizerViewModel: ObservableObject {

    @Published var reports: [OptimizerReport] = []

    @Published var isCalculating = false

    @Published var isBacktestRunning = false
    @Published var backtestProgress: Double = 0
    @Published var backtestStatus = "Bereit"

    @Published var isHoldoutRunning = false
    @Published var holdoutStatus = "Noch kein Holdout-Test gestartet"

    @Published var isParityRunning = false
    @Published var parityStatus = "Noch kein Paritätstest gestartet"

    @Published var isRandomBenchmarkRunning = false
    @Published var randomBenchmarkStatus = "Noch kein Zufallsbenchmark gestartet"

    @Published var isNormalDistributionRunning = false
    @Published var normalDistributionStatus = "Noch kein Normalverteilungstest gestartet"

    @Published var isMoonPhaseRunning = false
    @Published var moonPhaseStatus = "Noch kein Mondphasentest gestartet"

    @Published var isConfirmationRunning = false
    @Published var confirmationStatus = "Noch kein G/U-Bestätigungstest gestartet"

    @Published var isRobustnessRunning = false
    @Published var robustnessStatus = "Noch keine Robustheitsanalyse gestartet"

    @Published var isLearning = false
    @Published var learningStatus = "Noch kein Lernlauf gestartet"
    @Published var learnedGoal = OptimizationGoalStore.shared.currentGoal
    @Published var learningResult: LearningResult?

    private let database = DrawDatabase()
    private let optimizer = OptimizerEngine()
    private let generator = TicketGenerator()
    private let backtest = BacktestEngine()
    private let learningEngine = LearningEngine()
    private let savedRecommendationsStore = SavedRecommendationsStore()

    var learnedProfileText: String {
        let goal = learnedGoal
        return String(
            format: "F %.0f  |  P %.0f  |  G/U %.0f  |  H/N %.0f  |  S %.0f  |  A %.0f",
            goal.frequencyWeight,
            goal.pairWeight,
            goal.evenOddWeight,
            goal.highLowWeight,
            goal.sumWeight,
            goal.gapWeight
        )
    }

    var shareText: String {
        guard !reports.isEmpty else {
            return "Noch keine Empfehlungen vorhanden."
        }

        var text = """
🎯 EuroOpt – Top \(reports.count) Empfehlungen
🍀 Erstellt mit EuroOpt Alpha 7.6

"""

        let medals = ["🥇", "🥈", "🥉"]

        for (index, report) in reports.enumerated() {
            let medal = index < medals.count ? medals[index] : "⭐"

            text += """
\(medal) Empfehlung \(index + 1)
🎲 \(report.ticket.numbers.map(String.init).joined(separator: " • "))
⭐ Eurozahlen: \(report.ticket.euroNumbers.map(String.init).joined(separator: " • "))
⭐ EQI \(String(format: "%.0f", report.eqi.value)) %

────────────

"""
        }

        text += "🍀 Viel Glück!"
        return text
    }

    func calculateRecommendations(candidateCount: Int, recommendationCount: Int, forceRecalculate: Bool = false) {
        print("================================")
        print("🎯 Gewählte Spielsysteme: \(candidateCount)")
        print("🏆 Gewünschte Empfehlungen: \(recommendationCount)")
        print("🧠 Verwendetes Profil: \(learnedProfileText)")
        print("================================")

        let draws = database.allDraws()

        guard let latestDraw = draws.last else {
            print("❌ Keine Ziehungen vorhanden.")
            return
        }

        let latestDrawKey = String(describing: latestDraw.date)

        if !forceRecalculate,
           let saved = savedRecommendationsStore.load(),
           saved.drawDate == latestDrawKey {

            print("♻️ Gespeicherte Empfehlungen werden verwendet.")
            print("   Ziehung: \(latestDrawKey)")
            print("   Tipps: \(saved.reports.count)")

            reports = saved.reports.map {
                OptimizerReport(
                    ticket: Ticket(
                        numbers: $0.numbers,
                        euroNumbers: $0.euroNumbers
                    ),
                    eqi: EQI(value: $0.eqi)
                )
            }

            return
        }

        isCalculating = true
        let start = Date()
        let goal = OptimizationGoalStore.shared.currentGoal

        print("📊 Ziehungen geladen: \(draws.count)")
        print("🆕 Neue Ziehung erkannt – Optimizer wird ausgeführt.")

        let candidates = generator.generate(
            count: candidateCount,
            draws: draws,
            goal: goal
        )

        print("🎲 Erzeugte Spielsysteme: \(candidates.count)")

        let bestTickets = optimizer.bestTickets(
            from: candidates,
            draws: draws,
            goal: goal,
            limit: recommendationCount
        )

        print("🥇 Beste Spielsysteme: \(bestTickets.count)")

        let eqiCalculator = EQICalculator()

        reports = bestTickets.map { result in
            let eqi = eqiCalculator.calculate(
                ticket: result.ticket,
                draws: draws
            )

            return OptimizerReport(
                ticket: result.ticket,
                eqi: EQI(value: eqi)
            )
        }

        savedRecommendationsStore.save(
            drawDate: latestDrawKey,
            reports: reports
        )

        print("--------------------------------")
        print(
            String(
                format: "⏱ Gesamtzeit: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("--------------------------------")

        isCalculating = false
    }

    func startLearning() {
        guard !isLearning, !isCalculating, !isBacktestRunning, !isHoldoutRunning, !isParityRunning, !isRandomBenchmarkRunning, !isNormalDistributionRunning, !isMoonPhaseRunning, !isConfirmationRunning else { return }

        let draws = database.allDraws()
        let recommendationCount = AppSettings.recommendationCount
        isLearning = true
        learningStatus = "Walk-Forward-Lernen läuft..."
        learningResult = nil

        print("===================================")
        print("🧠 GEWICHTE LERNEN")
        print("===================================")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.learningEngine.learn(
                draws: draws,
                recommendationCount: recommendationCount,
                candidateCount: max(AppSettings.backtestCandidateCount + 1, 501)
            )

            DispatchQueue.main.async {
                self.learnedGoal = result.goal
                self.learningResult = result
                self.learningStatus = "Lernen beendet – Profil gespeichert"
                self.isLearning = false
            }
        }
    }

    func resetLearnedWeights() {
        guard !isLearning, !isCalculating, !isBacktestRunning, !isHoldoutRunning, !isParityRunning, !isRandomBenchmarkRunning, !isNormalDistributionRunning, !isMoonPhaseRunning, !isConfirmationRunning else { return }
        OptimizationGoalStore.shared.reset()
        learnedGoal = OptimizationGoalStore.shared.currentGoal
        learningResult = nil
        learningStatus = "Standardprofil wiederhergestellt"
    }

    // Existing test methods remain unchanged below.
}
