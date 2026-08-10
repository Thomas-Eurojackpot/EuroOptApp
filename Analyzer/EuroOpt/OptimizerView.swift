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
                recommendationsSection
                backtestSection
            }
            .padding()
        }
        .navigationTitle("Optimierer")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🎯 Optimierer")
                .font(.largeTitle)
                .bold()

            Text("EuroOpt Alpha 7.5")
                .font(.headline)

            Text("Generiert Kandidaten und bewertet daraus die besten Empfehlungen.")
                .foregroundStyle(.secondary)
        }
    }

    private var settingsSection: some View {
        GroupBox("Optimierung") {
            VStack(alignment: .leading, spacing: 14) {
                Stepper(
                    "Kandidaten: \(settingsViewModel.candidateCount)",
                    value: $settingsViewModel.candidateCount,
                    in: 100...100_000,
                    step: 100
                )

                Stepper(
                    "Empfehlungen: \(settingsViewModel.recommendationCount)",
                    value: $settingsViewModel.recommendationCount,
                    in: 1...20
                )
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
                    ProgressView()
                        .frame(maxWidth: .infinity)
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
                viewModel.isHoldoutRunning
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
                viewModel.isHoldoutRunning
            )

            Button {
                viewModel.runHoldoutTest()
            } label: {
                if viewModel.isHoldoutRunning {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("🧪 Holdout-Test starten", systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.isCalculating ||
                viewModel.isBacktestRunning ||
                viewModel.isLearning ||
                viewModel.isHoldoutRunning
            )
        }
    }

    private var learningSection: some View {
        GroupBox("🧠 Gewichte lernen") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Walk-Forward-Lernen passt die EQI-Gewichte aus der bisherigen Historie an.")
                    .foregroundStyle(.secondary)

                Text("Aktuelles Profil")
                    .font(.subheadline)
                    .bold()

                Text(viewModel.learnedProfileText)
                    .font(.system(.body, design: .monospaced))

                Button {
                    viewModel.startLearning()
                } label: {
                    if viewModel.isLearning {
                        ProgressView()
                            .frame(maxWidth: .infinity)
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
                    viewModel.isHoldoutRunning
                )

                Button("Standardprofil wiederherstellen") {
                    viewModel.resetLearnedWeights()
                }
                .buttonStyle(.bordered)
                .disabled(
                    viewModel.isLearning ||
                    viewModel.isCalculating ||
                    viewModel.isBacktestRunning ||
                    viewModel.isHoldoutRunning
                )

                Text(viewModel.learningStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let result = viewModel.learningResult {
                    Divider()

                    Text("Letzter Lernlauf")
                        .font(.subheadline)
                        .bold()

                    Text(String(format: "Ø Haupttreffer: %.3f   |   Ø Eurotreffer: %.3f", result.averageHits, result.averageEuroHits))
                        .font(.footnote)

                    Text("Getestete Ziehungen: \(result.testedDraws)   |   Profiländerungen: \(result.improvedSteps)")
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

                            Text("EQI: \(String(format: "%.1f", report.eqi.value).replacingOccurrences(of: ".", with: ","))")
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
