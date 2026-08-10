//
//  OptimizerView.swift
//  EuroOpt
//
//  Alpha 7.0
//

import SwiftUI

struct OptimizerView: View {

    @StateObject
    private var viewModel = OptimizerViewModel()

    @StateObject
    private var settingsViewModel = OptimizerSettingsViewModel()

    @State
    private var showSettings = false

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    headerSection

                    actionSection

                    if viewModel.isLearning {

                        GroupBox("🧠 Lernmodus") {

                            HStack {

                                ProgressView()

                                Text(viewModel.learningStatus)

                            }

                        }

                    }

                    if viewModel.isBacktestRunning {

                        GroupBox("🧪 Backtest") {

                            VStack(alignment: .leading, spacing: 12) {

                                ProgressView(
                                    value: viewModel.backtestProgress
                                )

                                Text(viewModel.backtestStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                            }

                        }

                    }

                    if viewModel.lastBacktestStatistics != nil {

                        BacktestDashboardView(
                            statistics: viewModel.lastBacktestStatistics,
                            duration: viewModel.lastBacktestDuration
                        )

                    }

                    if viewModel.reports.isEmpty {

                        ContentUnavailableView(
                            "Noch keine Empfehlungen",
                            systemImage: "list.bullet.rectangle",
                            description: Text(
                                "Klicke auf „Empfehlungen berechnen“."
                            )
                        )

                    } else {

                        recommendationsSection

                    }

                    informationSection

                }

                .padding()

            }

            .navigationTitle("Optimizer")

            .toolbar {

                ToolbarItemGroup(placement: .automatic) {

                    if !viewModel.reports.isEmpty {

                        ShareLink(
                            item: viewModel.shareText
                        ) {

                            Image(systemName: "square.and.arrow.up")

                        }

                    }

                    Button {

                        showSettings = true

                    } label: {

                        Image(systemName: "gearshape")

                    }

                }

            }

            .sheet(isPresented: $showSettings) {

                NavigationStack {

                    OptimizerSettingsView(
                        viewModel: settingsViewModel
                    )

                }

            }

        }

    }

}

// MARK: - Sections

private extension OptimizerView {

    var headerSection: some View {

        VStack(alignment: .leading, spacing: 6) {

            Text("🎯 EuroOpt Optimizer")
                .font(.largeTitle)
                .bold()

            Text(
                "Die \(settingsViewModel.recommendationCount) bestbewerteten Spielsysteme"
            )
            .foregroundStyle(.secondary)

        }

    }

    var actionSection: some View {

        VStack(spacing: 16) {

            Button {

                viewModel.calculateRecommendations(
                    candidateCount: settingsViewModel.candidateCount,
                    recommendationCount: settingsViewModel.recommendationCount
                )

            } label: {

                Label(
                    "Empfehlungen berechnen",
                    systemImage: "sparkles"
                )
                .frame(maxWidth: .infinity)

            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isCalculating)

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
            .disabled(viewModel.isBacktestRunning || viewModel.isLearning)

            Button {

                viewModel.startLearning()

            } label: {

                Label(
                    "🧠 Gewichte lernen",
                    systemImage: "brain"
                )
                .frame(maxWidth: .infinity)

            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLearning || viewModel.isBacktestRunning)

        }

    }

    var recommendationsSection: some View {

        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 20
        ) {

            ForEach(
                Array(viewModel.reports.enumerated()),
                id: \.element.id
            ) { index, report in

                RecommendationCardView(
                    rank: index + 1,
                    report: report
                )

            }

        }

    }

    var informationSection: some View {

        GroupBox("Hinweis") {

            Text("""
Die Vorschläge werden anhand der aktuellen Bewertungsgewichte berechnet.

Über „🧠 Gewichte lernen“ kann EuroOpt die Bewertungsgewichte anhand historischer Backtests optimieren.
""")

        }

    }

}

#Preview {

    OptimizerView()

}
