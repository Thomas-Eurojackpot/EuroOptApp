//
//  OptimizerView.swift
//  EuroOpt
//
//  Alpha 7.6
//

import SwiftUI

struct OptimizerView: View {

    @StateObject private var viewModel = OptimizerViewModel()
    @StateObject private var settingsViewModel = OptimizerSettingsViewModel()
    @State private var f2AlphaFilterRunning = false
    @State private var f2AlphaFilterStatus = "Noch kein F2/50 → Alpha Filtertest gestartet"

    private let database = DrawDatabase()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                settingsSection
                actionSection
                learningSection
                holdoutSection
                robustnessSection
                historyWindowSection
                f2AlphaFilterSection
                randomBenchmarkSection
                normalDistributionSection
                confirmationSection
                recommendationsSection
                backtestSection
            }
            .padding()
        }
        .navigationTitle("Optimierer")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🎯 Optimierer").font(.largeTitle).bold()
            Text("EuroOpt Alpha 7.6").font(.headline)
            Text("Generiert Kandidaten und bewertet daraus die besten Empfehlungen.")
                .foregroundStyle(.secondary)
        }
    }

    private var settingsSection: some View {
        GroupBox("Optimierung") {
            VStack(alignment: .leading, spacing: 14) {
                Stepper("Kandidaten: \(settingsViewModel.candidateCount)", value: $settingsViewModel.candidateCount, in: 100...100_000, step: 100)
                Stepper("Empfehlungen: \(settingsViewModel.recommendationCount)", value: $settingsViewModel.recommendationCount, in: 1...20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 16) {

            Button {
                viewModel.calculateRecommendations(
                    candidateCount: settingsViewModel.candidateCount,
                    recommendationCount: settingsViewModel.recommendationCount
                )
            } label: {
                if viewModel.isCalculating {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Empfehlungen berechnen", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.isCalculating ||
                viewModel.isBacktestRunning ||
                viewModel.isLearning ||
                viewModel.isHoldoutRunning ||
                viewModel.isRandomBenchmarkRunning ||
                viewModel.isNormalDistributionRunning ||
                viewModel.isConfirmationRunning ||
                viewModel.isRobustnessRunning ||
                f2AlphaFilterRunning
            )

            Button {
                viewModel.runBacktest()
            } label: {
                Label("🧪 Backtest starten", systemImage: "flask")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(
                viewModel.isCalculating ||
                viewModel.isBacktestRunning ||
                viewModel.isLearning ||
                viewModel.isHoldoutRunning ||
                viewModel.isRandomBenchmarkRunning ||
                viewModel.isNormalDistributionRunning ||
                viewModel.isConfirmationRunning ||
                viewModel.isRobustnessRunning ||
                f2AlphaFilterRunning
            )

            Button {
                viewModel.runAlpha80VsRalfVsRandomBacktest()
            } label: {
                Label(
                    "Alpha 8.0 vs Ralf vs Zufall",
                    systemImage: "chart.bar.xaxis"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.isCalculating ||
                viewModel.isBacktestRunning ||
                viewModel.isLearning ||
                viewModel.isHoldoutRunning ||
                viewModel.isRandomBenchmarkRunning ||
                viewModel.isNormalDistributionRunning ||
                viewModel.isConfirmationRunning ||
                viewModel.isRobustnessRunning ||
                f2AlphaFilterRunning
            )

            Button {
                viewModel.runHoldoutTest()
            } label: {
                if viewModel.isHoldoutRunning {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("🧪 Holdout-Test starten", systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.isCalculating ||
                viewModel.isBacktestRunning ||
                viewModel.isHoldoutRunning ||
                viewModel.isLearning ||
                viewModel.isRandomBenchmarkRunning ||
                viewModel.isNormalDistributionRunning ||
                viewModel.isConfirmationRunning ||
                viewModel.isRobustnessRunning ||
                f2AlphaFilterRunning
            )
        }
    }

    private var learningSection: some View {
        GroupBox("🧠 Gewichte lernen") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Walk-Forward-Lernen passt die EQI-Gewichte aus der bisherigen Historie an.")
                    .foregroundStyle(.secondary)

                Text("Aktuelles Profil").font(.subheadline).bold()
                Text(viewModel.learnedProfileText)
                    .font(.system(.body, design: .monospaced))

                Button {
                    viewModel.startLearning()
                } label: {
                    if viewModel.isLearning {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Gewichte lernen", systemImage: "brain.head.profile")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isLearning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isHoldoutRunning ||
                    viewModel.isRandomBenchmarkRunning ||
                    viewModel.isNormalDistributionRunning ||
                    viewModel.isConfirmationRunning ||
                    viewModel.isRobustnessRunning ||
                    f2AlphaFilterRunning
                )

                Button("Standardprofil wiederherstellen") {
                    viewModel.resetLearnedWeights()
                }
                .buttonStyle(.bordered)
                .disabled(
                    viewModel.isLearning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isHoldoutRunning ||
                    viewModel.isRandomBenchmarkRunning ||
                    viewModel.isNormalDistributionRunning ||
                    viewModel.isConfirmationRunning ||
                    viewModel.isRobustnessRunning ||
                    f2AlphaFilterRunning
                )

                Text(viewModel.learningStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let result = viewModel.learningResult {
                    Divider()
                    Text("Letzter Lernlauf").font(.subheadline).bold()
                    Text(
                        String(
                            format: "Ø Haupttreffer: %.3f   |   Ø Eurotreffer: %.3f",
                            result.averageHits,
                            result.averageEuroHits
                        )
                    )
                    .font(.footnote)
                    Text(
                        "Getestete Ziehungen: \(result.testedDraws)   |   Profiländerungen: \(result.improvedSteps)"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var holdoutSection: some View {
        GroupBox("🧪 Alpha 7.5 Holdout-Test") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Der Weight-Sweep wählt das Profil ausschließlich auf der Validation-Hälfte und prüft es anschließend unverändert auf dem unabhängigen Holdout.")
                    .foregroundStyle(.secondary)
                Text(viewModel.holdoutStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var robustnessSection: some View {
        GroupBox("🧪 Alpha 7.5 Robustheitsanalyse") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Wiederholt die Validation/Holdout-Prüfung über fünf zeitlich getrennte Splits. Das Profil wird je Split ausschließlich aus der Validation gewählt und danach unverändert im Holdout geprüft.")
                    .foregroundStyle(.secondary)
                Text("Der Test ist separat: Der bestehende Produktions-WeightSweepEngine und das gespeicherte Profil werden nicht verändert. A100 wird wie jedes andere Profil behandelt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.runRobustnessAnalysis()
                } label: {
                    if viewModel.isRobustnessRunning {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Robustheitsanalyse starten", systemImage: "waveform.path.ecg")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isRobustnessRunning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isLearning ||
                    viewModel.isHoldoutRunning ||
                    viewModel.isRandomBenchmarkRunning ||
                    viewModel.isNormalDistributionRunning ||
                    viewModel.isConfirmationRunning ||
                    f2AlphaFilterRunning
                )

                Text(viewModel.robustnessStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var historyWindowSection: some View {
        GroupBox("🔬 Alpha 7.6 History-Window-Test") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vergleicht die gesamte Historie mit den letzten 300, 200, 150 und 100 Ziehungen. Der Test läuft ausschließlich als separate Diagnose und verändert den Produktions-Optimizer nicht.")
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.runHistoryWindowTest()
                } label: {
                    if viewModel.isHistoryWindowRunning {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("History-Window-Test starten", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isHistoryWindowRunning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isLearning ||
                    viewModel.isHoldoutRunning ||
                    viewModel.isRandomBenchmarkRunning ||
                    viewModel.isNormalDistributionRunning ||
                    viewModel.isConfirmationRunning ||
                    viewModel.isRobustnessRunning ||
                    f2AlphaFilterRunning
                )

                Text(viewModel.historyWindowStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var f2AlphaFilterSection: some View {
        GroupBox("🛡️ F2/50 → Alpha Kontrollfilter") {
            VStack(alignment: .leading, spacing: 10) {
                Text("F2/50 bleibt immer die Basis. Alpha darf den F2-Tipp nur ersetzen, wenn der Alpha-Vorteil auf der Validation mindestens die geprüfte Schwelle erreicht.")
                    .foregroundStyle(.secondary)
                Text("Geprüfte Schwellen: 0,00 / 0,02 / 0,04 / 0,06 / 0,08 / 0,10 Δ. Der Holdout wird erst nach der jeweiligen Entscheidung ausgewertet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    startF2AlphaFilterAnalysis()
                } label: {
                    if f2AlphaFilterRunning {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("F2/50 → Alpha Filter testen", systemImage: "shield.checkered")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    f2AlphaFilterRunning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isLearning ||
                    viewModel.isHoldoutRunning ||
                    viewModel.isRandomBenchmarkRunning ||
                    viewModel.isNormalDistributionRunning ||
                    viewModel.isConfirmationRunning ||
                    viewModel.isRobustnessRunning
                )

                Text(f2AlphaFilterStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func startF2AlphaFilterAnalysis() {
        guard !f2AlphaFilterRunning else { return }

        let draws = database.allDraws()
        f2AlphaFilterRunning = true
        f2AlphaFilterStatus = "F2/50 → Alpha Filter läuft – Ergebnis in der Xcode-Konsole..."

        DispatchQueue.global(qos: .userInitiated).async {
            F2AlphaFilterAnalyzer().run(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount,
                splitCount: 10
            )

            DispatchQueue.main.async {
                f2AlphaFilterStatus = "F2/50 → Alpha Filter beendet – Ergebnis in der Xcode-Konsole"
                f2AlphaFilterRunning = false
            }
        }
    }

    private var randomBenchmarkSection: some View {
        GroupBox("🎲 Empirischer Zufallsbenchmark") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vergleicht den Holdout mit echten, empirisch erzeugten Zufallstipps – ohne EQI, Gewichte oder historische Auswahlkriterien.")
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.runRandomBenchmark()
                } label: {
                    if viewModel.isRandomBenchmarkRunning {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Zufallsbenchmark starten", systemImage: "dice")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isRandomBenchmarkRunning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isLearning ||
                    viewModel.isHoldoutRunning ||
                    viewModel.isNormalDistributionRunning ||
                    viewModel.isConfirmationRunning ||
                    viewModel.isRobustnessRunning ||
                    f2AlphaFilterRunning
                )

                Text(viewModel.randomBenchmarkStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var normalDistributionSection: some View {
        GroupBox("📐 Normalverteilung – isolierter Test") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prüft separat, ob die Summe der 5 Hauptzahlen als annähernd normalverteilte Größe für die Tippauswahl einen messbaren Effekt liefert.")
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.runNormalDistributionTest()
                } label: {
                    if viewModel.isNormalDistributionRunning {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Normalverteilungstest starten", systemImage: "chart.line.uptrend.xyaxis")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isNormalDistributionRunning ||
                    viewModel.isRandomBenchmarkRunning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isLearning ||
                    viewModel.isHoldoutRunning ||
                    viewModel.isConfirmationRunning ||
                    viewModel.isRobustnessRunning ||
                    f2AlphaFilterRunning
                )

                Text(viewModel.normalDistributionStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var confirmationSection: some View {
        GroupBox("🧪 G/U-Bestätigungstest") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prüft das bereits festgelegte Profil G/U 100 % erneut auf den letzten 100 Ziehungen. Es werden keine Gewichte optimiert oder verändert.")
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.runGUConfirmation()
                } label: {
                    if viewModel.isConfirmationRunning {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("G/U-Bestätigung starten", systemImage: "scope")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isConfirmationRunning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isLearning ||
                    viewModel.isHoldoutRunning ||
                    viewModel.isRandomBenchmarkRunning ||
                    viewModel.isNormalDistributionRunning ||
                    viewModel.isRobustnessRunning ||
                    f2AlphaFilterRunning
                )

                Text(viewModel.confirmationStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recommendationsSection: some View {
        GroupBox("Empfehlungen") {
            if viewModel.reports.isEmpty {
                Text("Noch keine Empfehlungen vorhanden.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(viewModel.reports.enumerated()), id: \.offset) { index, report in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(index + 1). Empfehlung")
                                .font(.headline)
                            Text(report.ticket.numbers.map(String.init).joined(separator: " • "))
                                .font(.title3)
                            Text("Eurozahlen: " + report.ticket.euroNumbers.map(String.init).joined(separator: " • "))
                                .foregroundStyle(.secondary)
                            Text(
                                "EQI: \(String(format: "%.1f", report.eqi.value).replacingOccurrences(of: ".", with: ","))"
                            )
                            .font(.subheadline)

                            if !report.recommendation.isEmpty {
                                Text(report.recommendation)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if index < viewModel.reports.count - 1 {
                            Divider()
                        }
                    }

                    ShareLink(
                        item: viewModel.shareText,
                        preview: SharePreview("EuroOpt Empfehlungen")
                    ) {
                        Label("Empfehlungen teilen", systemImage: "square.and.arrow.up")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var backtestSection: some View {
        GroupBox("Backtest") {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.backtestStatus)
                    .foregroundStyle(.secondary)

                if viewModel.isBacktestRunning || viewModel.backtestProgress > 0 {
                    ProgressView(value: viewModel.backtestProgress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    OptimizerView()
}
