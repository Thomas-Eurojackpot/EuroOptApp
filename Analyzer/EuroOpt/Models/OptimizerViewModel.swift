
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

    func calculateRecommendations(candidateCount: Int, recommendationCount: Int) {
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

        if let saved = savedRecommendationsStore.load(),
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

    func runHoldoutTest() {
        guard !isHoldoutRunning, !isLearning, !isCalculating, !isBacktestRunning, !isParityRunning, !isRandomBenchmarkRunning, !isNormalDistributionRunning, !isMoonPhaseRunning, !isConfirmationRunning else { return }

        let draws = database.allDraws()
        isHoldoutRunning = true
        holdoutStatus = "Holdout-Test läuft – Validation und Holdout werden getrennt geprüft..."

        print("===================================")
        print("🧪 ALPHA 7.5 HOLDOUT-TEST")
        print("===================================")
        print("🔒 Holdout wird bis zur Gewichtswahl nicht verwendet.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            WeightSweepEngine().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.holdoutStatus = "Holdout-Test beendet – Ergebnis im Konsolen-Output"
                self.isHoldoutRunning = false
            }
        }
    }

    func runWeightSweepParityTest() {
        guard !isParityRunning, !isHoldoutRunning, !isLearning, !isCalculating, !isBacktestRunning, !isRandomBenchmarkRunning, !isNormalDistributionRunning, !isMoonPhaseRunning, !isConfirmationRunning else { return }

        let draws = database.allDraws()
        isParityRunning = true
        parityStatus = "Paritätstest läuft – Engine und Core erhalten dieselben Kandidaten..."

        print("===================================")
        print("🔬 WEIGHT-SWEEP PARITÄTSTEST")
        print("===================================")
        print("🔒 Alpha 7.5 Holdout wird nicht ausgeführt.")
        print("🔒 TicketGenerator wird pro Ziehung nur einmal verwendet.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            WeightSweepParityTest().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.parityStatus = "Paritätstest beendet – Ergebnis im Konsolen-Output"
                self.isParityRunning = false
            }
        }
    }

    func runRandomBenchmark() {
        guard !isRandomBenchmarkRunning, !isHoldoutRunning, !isLearning, !isCalculating, !isBacktestRunning, !isParityRunning, !isNormalDistributionRunning, !isMoonPhaseRunning, !isConfirmationRunning else { return }

        let draws = database.allDraws()
        isRandomBenchmarkRunning = true
        randomBenchmarkStatus = "Zufallsbenchmark läuft – gleiche Holdout-Bedingungen..."

        print("===================================")
        print("🎲 EMPIRISCHER ZUFALLSBENCHMARK")
        print("===================================")
        print("🔒 Keine Gewichte, kein EQI, keine Optimierung.")
        print("🔒 Gleiches Alpha-7.5-Holdout-Zeitfenster.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            RandomBenchmarkEngine().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.randomBenchmarkStatus = "Zufallsbenchmark beendet – Ergebnis im Konsolen-Output"
                self.isRandomBenchmarkRunning = false
            }
        }
    }

    func runNormalDistributionTest() {
        guard !isNormalDistributionRunning, !isRandomBenchmarkRunning, !isHoldoutRunning, !isLearning, !isCalculating, !isBacktestRunning, !isParityRunning, !isMoonPhaseRunning, !isConfirmationRunning else { return }

        let draws = database.allDraws()
        isNormalDistributionRunning = true
        normalDistributionStatus = "Normalverteilungstest läuft – Alpha 7.5 bleibt unverändert..."

        print("===================================")
        print("📐 NORMALVERTEILUNG – ISOLIERTER TEST")
        print("===================================")
        print("🔒 Alpha 7.5 wird nicht verändert.")
        print("🔒 Keine Gewichte und keine EQI-Auswahl.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            NormalDistributionTestEngine().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.normalDistributionStatus = "Normalverteilungstest beendet – Ergebnis im Konsolen-Output"
                self.isNormalDistributionRunning = false
            }
        }
    }

    func runMoonPhaseTest() {
        guard !isMoonPhaseRunning, !isNormalDistributionRunning, !isRandomBenchmarkRunning, !isHoldoutRunning, !isLearning, !isCalculating, !isBacktestRunning, !isParityRunning, !isConfirmationRunning else { return }

        let draws = database.allDraws()
        isMoonPhaseRunning = true
        moonPhaseStatus = "Mondphasentest läuft – Phase wird nur aus Validation gewählt..."

        print("===================================")
        print("🌙 MONDPHASEN – ISOLIERTER TEST")
        print("===================================")
        print("🔒 Alpha 7.5 wird nicht verändert.")
        print("🔒 Mondphase wird ausschließlich aus der Validation gewählt.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            MoonPhaseEngine().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.moonPhaseStatus = "Mondphasentest beendet – Ergebnis im Konsolen-Output"
                self.isMoonPhaseRunning = false
            }
        }
    }

    func runGUConfirmation() {
        guard !isConfirmationRunning, !isHoldoutRunning, !isRandomBenchmarkRunning, !isNormalDistributionRunning, !isMoonPhaseRunning, !isLearning, !isCalculating, !isBacktestRunning, !isParityRunning else { return }

        let draws = database.allDraws()
        isConfirmationRunning = true
        confirmationStatus = "G/U-Bestätigung läuft – Gewichte sind fest auf 100 % G/U..."

        print("===================================")
        print("🧪 G/U-BESTÄTIGUNGS-TEST")
        print("===================================")
        print("🔒 Profil ist vor dem Test festgelegt: G/U 100 %")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            WeightSweepEngine().runGUConfirmation(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.confirmationStatus = "G/U-Bestätigung beendet – Ergebnis im Konsolen-Output"
                self.isConfirmationRunning = false
            }
        }
    }

    func runRobustnessAnalysis() {
        guard !isRobustnessRunning, !isConfirmationRunning, !isHoldoutRunning, !isRandomBenchmarkRunning, !isNormalDistributionRunning, !isMoonPhaseRunning, !isLearning, !isCalculating, !isBacktestRunning else { return }

        let draws = database.allDraws()
        isRobustnessRunning = true
        robustnessStatus = "Robustheitsanalyse läuft – zehn zeitliche Validation/Holdout-Splits..."

        print("===================================")
        print("🧪 ALPHA 7.5 ROBUSTHEITS-ANALYSE")
        print("===================================")
        print("🔒 Separater Analyzer – Produktions-WeightSweepEngine bleibt unverändert.")
        print("🔒 Profilwahl erfolgt je Split ausschließlich aus der Validation.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            WeightSweepRobustnessAnalyzer().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                splitCount: 10
            )

            DispatchQueue.main.async {
                self.robustnessStatus = "Robustheitsanalyse beendet – Ergebnisse im Konsolen-Output"
                self.isRobustnessRunning = false
            }
        }
    }

    func runBacktest() {
        guard !isLearning, !isHoldoutRunning, !isRandomBenchmarkRunning, !isNormalDistributionRunning, !isMoonPhaseRunning, !isConfirmationRunning, !isParityRunning else { return }

        let draws = database.allDraws()
        isBacktestRunning = true
        backtestProgress = 0
        backtestStatus = "Backtest läuft..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            _ = self.backtest.run(
                draws: draws,
                candidateCount: AppSettings.backtestCandidateCount,
                recommendationCount: AppSettings.recommendationCount
            ) { progress, current, total in
                DispatchQueue.main.async {
                    self.backtestProgress = progress
                    self.backtestStatus = "\(current) von \(total) Ziehungen"
                }
            }

            let componentBacktest = ComponentBacktestEngine()
            componentBacktest.run(draws: draws, recommendationCount: AppSettings.recommendationCount)

            DispatchQueue.main.async {
                self.backtestProgress = 1.0
                self.backtestStatus = "Backtest + Komponententest beendet"
                self.isBacktestRunning = false
            }
        }
    }
}
