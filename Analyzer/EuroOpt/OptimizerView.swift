//
//  OptimizerView.swift
//  EuroOpt
//
//  Alpha 7.4 - Performance
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
                recommendationsSection
                backtestSection

            }
            .padding()

        }
        .navigationTitle("Optimierer")

    }

    // MARK: - Header

    private var headerSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("🎯 Optimierer")
                .font(.largeTitle)
                .bold()

            Text("EuroOpt Alpha 7.4")
                .font(.headline)

            Text("Generiert Kandidaten und bewertet daraus die besten Empfehlungen.")
                .foregroundStyle(.secondary)

        }

    }

    // MARK: - Settings

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

    // MARK: - Actions

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

                    Label(
                        "Empfehlungen berechnen",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)

                }

            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isCalculating || viewModel.isBacktestRunning)

            Button {

                viewModel.runBacktest()

            } label: {

                Label(
                    "🧪 Backtest starten",
                    systemImage: "flask"
                )
                .frame(maxWidth: .infinity)

            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isCalculating || viewModel.isBacktestRunning)

        }

    }

    // MARK: - Recommendations

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

    // MARK: - Backtest

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
