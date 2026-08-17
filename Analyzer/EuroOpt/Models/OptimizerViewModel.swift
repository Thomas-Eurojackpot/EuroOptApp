
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
    @Published var isHistoryWindowRunning = false
    @Published var historyWindowStatus = "Noch kein History-Window-Test gestartet"

    @Published var isHistoryWindowRobustnessRunning = false
    @Published var historyWindowRobustnessStatus = "Noch kein History-Window-Robustheitstest gestartet"

    @Published var isHistoryWindowPairRunning = false
    @Published var historyWindowPairStatus = "Noch kein W150/W300-Paarvergleich gestartet"

    @Published var isHistoryWindowFullPairRunning = false
    @Published var historyWindowFullPairStatus = "Noch kein FULL/W300-Paarvergleich gestartet"

    @Published var isConcentrationWeightDiagnosticRunning = false
    @Published var concentrationWeightDiagnosticStatus = "Noch kein Alpha/Konzentration-Ablationstest gestartet"

    @Published var isConcentrationPairRunning = false
    @Published var concentrationPairStatus = "Noch kein A70C30/A60C40-Paarvergleich gestartet"

    @Published var isRecommendationStabilityRunning = false
    @Published var recommendationStabilityStatus = "Noch kein Empfehlungs-Stabilitätstest gestartet"

    @Published var isNumberFrequencyRunning = false
    @Published var numberFrequencyStatus = "Noch kein Zahlen-Frequenz-Test gestartet"

    @Published var isNumberComponentAblationRunning = false
    @Published var numberComponentAblationStatus = "Noch keine Score-Komponenten-Ablation gestartet"

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

    func runHistoryWindowTest() {
        guard !isHistoryWindowRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isHistoryWindowRunning = true
        historyWindowStatus = "History-Window-Test läuft..."

        print("===================================")
        print("🔬 ALPHA 7.6 HISTORY-WINDOW TEST")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            HistoryWindowDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.historyWindowStatus = "History-Window-Test beendet – Ergebnisse im Konsolen-Output"
                self.isHistoryWindowRunning = false
            }
        }
    }

    func runHistoryWindowRobustnessTest() {
        guard !isHistoryWindowRobustnessRunning,
              !isHistoryWindowRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isHistoryWindowRobustnessRunning = true
        historyWindowRobustnessStatus = "History-Window-Robustheit läuft..."

        print("===================================")
        print("🧪 HISTORY-WINDOW ROBUSTHEIT")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            HistoryWindowRobustnessDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                splitCount: 5
            )

            DispatchQueue.main.async {
                self.historyWindowRobustnessStatus = "History-Window-Robustheit beendet – Ergebnisse im Konsolen-Output"
                self.isHistoryWindowRobustnessRunning = false
            }
        }
    }

    func runHistoryWindowPairTest() {
        guard !isHistoryWindowPairRunning,
              !isHistoryWindowRobustnessRunning,
              !isHistoryWindowRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isHistoryWindowPairRunning = true
        historyWindowPairStatus = "W150/W300-Paarvergleich läuft..."

        print("===================================")
        print("🧪 W150 vs. W300 – PAARVERGLEICH")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            HistoryWindowPairDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                splitCount: 10
            )

            DispatchQueue.main.async {
                self.historyWindowPairStatus = "W150/W300-Paarvergleich beendet – Ergebnisse im Konsolen-Output"
                self.isHistoryWindowPairRunning = false
            }
        }
    }

    func runHistoryWindowFullPairTest() {
        guard !isHistoryWindowFullPairRunning,
              !isHistoryWindowPairRunning,
              !isHistoryWindowRobustnessRunning,
              !isHistoryWindowRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isHistoryWindowFullPairRunning = true
        historyWindowFullPairStatus = "FULL/W300-Paarvergleich läuft..."

        print("===================================")
        print("🧪 FULL vs. W300 – PAARVERGLEICH")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            HistoryWindowFullPairDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                splitCount: 10
            )

            DispatchQueue.main.async {
                self.historyWindowFullPairStatus = "FULL/W300-Paarvergleich beendet – Ergebnisse im Konsolen-Output"
                self.isHistoryWindowFullPairRunning = false
            }
        }
    }

    func runConcentrationWeightDiagnostic() {
        guard !isConcentrationWeightDiagnosticRunning,
              !isHistoryWindowFullPairRunning,
              !isHistoryWindowPairRunning,
              !isHistoryWindowRobustnessRunning,
              !isHistoryWindowRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isConcentrationWeightDiagnosticRunning = true
        concentrationWeightDiagnosticStatus = "Alpha/Konzentration-Ablation läuft..."

        print("===================================")
        print("🧪 ALPHA / KONZENTRATION – ABLATION")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            ConcentrationWeightDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                splitCount: 10
            )

            DispatchQueue.main.async {
                self.concentrationWeightDiagnosticStatus = "Alpha/Konzentration-Ablation beendet – Ergebnisse im Konsolen-Output"
                self.isConcentrationWeightDiagnosticRunning = false
            }
        }
    }

    func runConcentrationPairTest() {
        guard !isConcentrationPairRunning,
              !isConcentrationWeightDiagnosticRunning,
              !isHistoryWindowFullPairRunning,
              !isHistoryWindowPairRunning,
              !isHistoryWindowRobustnessRunning,
              !isHistoryWindowRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isConcentrationPairRunning = true
        concentrationPairStatus = "A70C30/A60C40-Paarvergleich läuft..."

        print("===================================")
        print("🧪 A70C30 vs. A60C40")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            ConcentrationPairDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                splitCount: 10
            )

            DispatchQueue.main.async {
                self.concentrationPairStatus = "A70C30/A60C40-Paarvergleich beendet – Ergebnisse im Konsolen-Output"
                self.isConcentrationPairRunning = false
            }
        }
    }

    func runRecommendationStabilityTest() {
        guard !isRecommendationStabilityRunning,
              !isConcentrationPairRunning,
              !isHistoryWindowFullPairRunning,
              !isHistoryWindowPairRunning,
              !isHistoryWindowRobustnessRunning,
              !isHistoryWindowRunning,
              !isConcentrationWeightDiagnosticRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isRecommendationStabilityRunning = true
        recommendationStabilityStatus = "Empfehlungs-Stabilitätstest läuft..."

        print("===================================")
        print("🔬 ALPHA 7.6 EMPFEHLUNGS-STABILITÄT")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            RecommendationStabilityDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                runCount: 10
            )

            DispatchQueue.main.async {
                self.recommendationStabilityStatus = "Empfehlungs-Stabilitätstest beendet – Ergebnisse im Konsolen-Output"
                self.isRecommendationStabilityRunning = false
            }
        }
    }

    func runNumberFrequencyTest() {
        guard !isNumberFrequencyRunning,
              !isRecommendationStabilityRunning,
              !isConcentrationPairRunning,
              !isConcentrationWeightDiagnosticRunning,
              !isHistoryWindowFullPairRunning,
              !isHistoryWindowPairRunning,
              !isHistoryWindowRobustnessRunning,
              !isHistoryWindowRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isNumberFrequencyRunning = true
        numberFrequencyStatus = "Zahlen-Frequenz-Test läuft..."

        print("===================================")
        print("🔬 ALPHA 7.6 ZAHLEN-FREQUENZ-KONTROLLE")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            NumberFrequencyDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                runCount: 10
            )

            DispatchQueue.main.async {
                self.numberFrequencyStatus = "Zahlen-Frequenz-Test beendet – Ergebnisse im Konsolen-Output"
                self.isNumberFrequencyRunning = false
            }
        }
    }

    func runNumberComponentAblationTest() {
        guard !isNumberComponentAblationRunning,
              !isNumberFrequencyRunning,
              !isRecommendationStabilityRunning,
              !isConcentrationPairRunning,
              !isConcentrationWeightDiagnosticRunning,
              !isHistoryWindowFullPairRunning,
              !isHistoryWindowPairRunning,
              !isHistoryWindowRobustnessRunning,
              !isHistoryWindowRunning,
              !isRobustnessRunning,
              !isConfirmationRunning,
              !isHoldoutRunning,
              !isRandomBenchmarkRunning,
              !isNormalDistributionRunning,
              !isMoonPhaseRunning,
              !isLearning,
              !isCalculating,
              !isBacktestRunning else { return }

        let draws = database.allDraws()

        isNumberComponentAblationRunning = true
        numberComponentAblationStatus = "Score-Komponenten-Ablation läuft..."

        print("===================================")
        print("🔬 ALPHA 7.6 SCORE-KOMPONENTEN-ABLATION")
        print("===================================")
        print("🔒 Separater Diagnostic-Test.")
        print("🔒 Produktions-Optimizer bleibt unverändert.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            NumberComponentAblationDiagnostic().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                runCount: 10
            )

            DispatchQueue.main.async {
                self.numberComponentAblationStatus =
                    "Score-Komponenten-Ablation beendet – Ergebnisse im Konsolen-Output"
                self.isNumberComponentAblationRunning = false
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
