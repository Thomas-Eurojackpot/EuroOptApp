//
//  OptimizerView.swift
//  EuroOpt
//
//  Alpha 7.5
//

import SwiftUI

struct OptimizerView: View {

    @StateObject private var viewModel = OptimizerViewModel()
    @StateObject private var settingsViewModel = OptimizerSettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                settingsSection
                actionSection
                learningSection
                holdoutSection
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
            Text("EuroOpt Alpha 7.5").font(.headline)
            Text("Generiert Kandidaten und bewertet daraus die besten Empfehlungen.").foregroundStyle(.secondary)
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
                viewModel.calculateRecommendations(candidateCount: settingsViewModel.candidateCount, recommendationCount: settingsViewModel.recommendationCount)
            } label: {
                if viewModel.isCalculating { ProgressView().frame(maxWidth: .infinity) }
                else { Label("Empfehlungen berechnen", systemImage: "sparkles").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isLearning || viewModel.isHoldoutRunning || viewModel.isParityRunning || viewModel.isRandomBenchmarkRunning || viewModel.isNormalDistributionRunning || viewModel.isConfirmationRunning)

            Button { viewModel.runBacktest() } label: {
                Label("🧪 Backtest starten", systemImage: "flask").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isLearning || viewModel.isHoldoutRunning || viewModel.isParityRunning || viewModel.isRandomBenchmarkRunning || viewModel.isNormalDistributionRunning || viewModel.isConfirmationRunning)

            Button { viewModel.runHoldoutTest() } label: {
                if viewModel.isHoldoutRunning { ProgressView().frame(maxWidth: .infinity) }
                else { Label("🧪 Holdout-Test starten", systemImage: "checkmark.shield").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isLearning || viewModel.isHoldoutRunning || viewModel.isParityRunning || viewModel.isRandomBenchmarkRunning || viewModel.isNormalDistributionRunning || viewModel.isConfirmationRunning)
        }
    }

    private var learningSection: some View {
        GroupBox("🧠 Gewichte lernen") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Walk-Forward-Lernen passt die EQI-Gewichte aus der bisherigen Historie an.").foregroundStyle(.secondary)
                Text("Aktuelles Profil").font(.subheadline).bold()
                Text(viewModel.learnedProfileText).font(.system(.body, design: .monospaced))
                Button { viewModel.startLearning() } label: {
                    if viewModel.isLearning { ProgressView().frame(maxWidth: .infinity) }
                    else { Label("Gewichte lernen", systemImage: "brain.head.profile").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLearning || viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isHoldoutRunning || viewModel.isParityRunning || viewModel.isRandomBenchmarkRunning || viewModel.isNormalDistributionRunning || viewModel.isConfirmationRunning)
                Button("Standardprofil wiederherstellen") { viewModel.resetLearnedWeights() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLearning || viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isHoldoutRunning || viewModel.isParityRunning || viewModel.isRandomBenchmarkRunning || viewModel.isNormalDistributionRunning || viewModel.isConfirmationRunning)
                Text(viewModel.learningStatus).font(.footnote).foregroundStyle(.secondary)
                if let result = viewModel.learningResult {
                    Divider()
                    Text("Letzter Lernlauf").font(.subheadline).bold()
                    Text(String(format: "Ø Haupttreffer: %.3f   |   Ø Eurotreffer: %.3f", result.averageHits, result.averageEuroHits)).font(.footnote)
                    Text("Getestete Ziehungen: \(result.testedDraws)   |   Profiländerungen: \(result.improvedSteps)").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var holdoutSection: some View {
        GroupBox("🧪 Alpha 7.5 Holdout-Test") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Der Weight-Sweep wählt das Profil ausschließlich auf der Validation-Hälfte und prüft es anschließend unverändert auf dem unabhängigen Holdout.").foregroundStyle(.secondary)
                Text(viewModel.holdoutStatus).font(.footnote).foregroundStyle(.secondary)

                Divider()
                Text("🔬 Paritätstest").font(.subheadline).bold()
                Text("Vergleicht den bestehenden WeightSweepEngine-Berechnungspfad mit WeightSweepCore. Beide erhalten exakt dieselben zufällig erzeugten Kandidaten; Alpha 7.5 run() wird dabei nicht ausgeführt.").font(.footnote).foregroundStyle(.secondary)
                Button { viewModel.runWeightSweepParityTest() } label: {
                    if viewModel.isParityRunning { ProgressView().frame(maxWidth: .infinity) }
                    else { Label("Weight-Sweep-Parität testen", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isParityRunning || viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isLearning || viewModel.isHoldoutRunning || viewModel.isRandomBenchmarkRunning || viewModel.isNormalDistributionRunning || viewModel.isConfirmationRunning)
                Text(viewModel.parityStatus).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var randomBenchmarkSection: some View {
        GroupBox("🎲 Empirischer Zufallsbenchmark") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vergleicht den Holdout mit echten, empirisch erzeugten Zufallstipps – ohne EQI, Gewichte oder historische Auswahlkriterien.").foregroundStyle(.secondary)
                Text("Kandidatenanzahl, Tippanzahl, Hauptzahl-Validierung und Diversitätsregel entsprechen dem Holdout-Test. Die Eurozahlen berücksichtigen das historische 10/12-Format.").font(.footnote).foregroundStyle(.secondary)
                Button { viewModel.runRandomBenchmark() } label: {
                    if viewModel.isRandomBenchmarkRunning { ProgressView().frame(maxWidth: .infinity) }
                    else { Label("Zufallsbenchmark starten", systemImage: "dice").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRandomBenchmarkRunning || viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isLearning || viewModel.isHoldoutRunning || viewModel.isParityRunning || viewModel.isNormalDistributionRunning || viewModel.isConfirmationRunning)
                Text(viewModel.randomBenchmarkStatus).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var normalDistributionSection: some View {
        GroupBox("📐 Normalverteilung – isolierter Test") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prüft separat, ob die Summe der 5 Hauptzahlen als annähernd normalverteilte Größe für die Tippauswahl einen messbaren Effekt liefert.").foregroundStyle(.secondary)
                Text("Feste theoretische Verteilung: Mittelwert 127,5 und Standardabweichung 30,923. Keine Gewichte, kein EQI und keine Anpassung an den Holdout.").font(.footnote).foregroundStyle(.secondary)
                Button { viewModel.runNormalDistributionTest() } label: {
                    if viewModel.isNormalDistributionRunning { ProgressView().frame(maxWidth: .infinity) }
                    else { Label("Normalverteilungstest starten", systemImage: "chart.line.uptrend.xyaxis").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isNormalDistributionRunning || viewModel.isRandomBenchmarkRunning || viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isLearning || viewModel.isHoldoutRunning || viewModel.isParityRunning || viewModel.isConfirmationRunning)
                Text(viewModel.normalDistributionStatus).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var confirmationSection: some View {
        GroupBox("🧪 G/U-Bestätigungstest") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prüft das bereits festgelegte Profil G/U 100 % erneut auf den letzten 100 Ziehungen. Es werden keine Gewichte optimiert oder verändert.").foregroundStyle(.secondary)
                Text("Hinweis: Die letzten 100 Ziehungen waren bereits Teil des bisherigen Holdouts. Deshalb ist dies eine Bestätigungsscheibe und kein statistisch unabhängiges zweites Experiment.").font(.footnote).foregroundStyle(.secondary)
                Button { viewModel.runGUConfirmation() } label: {
                    if viewModel.isConfirmationRunning { ProgressView().frame(maxWidth: .infinity) }
                    else { Label("G/U-Bestätigung starten", systemImage: "scope").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isConfirmationRunning || viewModel.isCalculating || viewModel.isBacktestRunning || viewModel.isLearning || viewModel.isHoldoutRunning || viewModel.isParityRunning || viewModel.isRandomBenchmarkRunning || viewModel.isNormalDistributionRunning)
                Text(viewModel.confirmationStatus).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recommendationsSection: some View {
        GroupBox("Empfehlungen") {
            if viewModel.reports.isEmpty { Text("Noch keine Empfehlungen vorhanden.").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(viewModel.reports.enumerated()), id: \.offset) { index, report in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(index + 1). Empfehlung").font(.headline)
                            Text(report.ticket.numbers.map(String.init).joined(separator: " • ")).font(.title3)
                            Text("Eurozahlen: " + report.ticket.euroNumbers.map(String.init).joined(separator: " • ")).foregroundStyle(.secondary)
                            Text("EQI: \(String(format: "%.1f", report.eqi.value).replacingOccurrences(of: ".", with: ","))").font(.subheadline)
                            if !report.recommendation.isEmpty { Text(report.recommendation).font(.footnote).foregroundStyle(.secondary) }
                        }
                        if index < viewModel.reports.count - 1 { Divider() }
                    }
                    ShareLink(item: viewModel.shareText, preview: SharePreview("EuroOpt Empfehlungen")) {
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
                Text(viewModel.backtestStatus).foregroundStyle(.secondary)
                if viewModel.isBacktestRunning || viewModel.backtestProgress > 0 { ProgressView(value: viewModel.backtestProgress) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview { OptimizerView() }
