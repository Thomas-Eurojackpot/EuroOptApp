//
//  OptimizerView.swift
//  EuroOpt
//
//  Alpha 7.5
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

                    if viewModel.isHoldoutRunning {

                        GroupBox("🧪 Holdout-Test") {

                            HStack {

                                ProgressView()

                                Text(viewModel.holdoutStatus)

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

                    if let holdout = viewModel.lastHoldoutResult {

                        holdoutDashboard(holdout)

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
            .disabled(viewModel.isCalculating || viewModel.isLearning || viewModel.isHoldoutRunning)

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
            .disabled(
                viewModel.isBacktestRunning ||
                viewModel.isLearning ||
                viewModel.isHoldoutRunning
            )

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
            .disabled(
                viewModel.isLearning ||
                viewModel.isBacktestRunning ||
                viewModel.isHoldoutRunning
            )

            Button {

                viewModel.runHoldout()

            } label: {

                Label(
                    "🧪 Holdout-Test starten",
                    systemImage: "checkmark.shield"
                )
                .frame(maxWidth: .infinity)

            }
            .buttonStyle(.bordered)
            .disabled(
                viewModel.isHoldoutRunning ||
                viewModel.isLearning ||
                viewModel.isBacktestRunning
            )

        }

    }

    func holdoutDashboard(
        _ result: HoldoutResult
    ) -> some View {

        GroupBox("🧪 Alpha 7.5 Holdout-Ergebnis") {

            VStack(alignment: .leading, spacing: 10) {

                Text("Training: \(result.trainingDrawCount) Ziehungen")

                Text("Holdout: \(result.holdoutDrawCount) Ziehungen")

                Divider()

                Text(
                    String(
                        format: "Ø Haupttreffer: %.3f  |  Zufall: %.3f  |  Δ: %+.3f",
                        result.averageHits,
                        result.randomMain,
                        result.averageHits - result.randomMain
                    )
                )

                Text(
                    String(
                        format: "Ø Eurotreffer: %.3f  |  Zufall: %.3f  |  Δ: %+.3f",
                        result.averageEuroHits,
                        result.randomEuro,
                        result.averageEuroHits - result.randomEuro
                    )
                )

                Divider()

                Text("Eingefrorene Gewichte")
                    .font(.headline)

                Text(
                    String(
                        format: "F %.0f | P %.0f | G/U %.0f | H/N %.0f | S %.0f | A %.0f",
                        result.learnedGoal.frequencyWeight,
                        result.learnedGoal.pairWeight,
                        result.learnedGoal.evenOddWeight,
                        result.learnedGoal.highLowWeight,
                        result.learnedGoal.sumWeight,
                        result.learnedGoal.gapWeight
                    )
                    .replacingOccurrences(of: ".", with: "")
                )

                Text(
                    String(format: "Laufzeit: %.2f Sekunden", result.duration)
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    "Das Profil wurde nur auf dem Training gelernt und im Holdout nicht verändert."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

            }

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

Der „🧪 Holdout-Test“ lernt zunächst ausschließlich auf den ersten 80 % der Ziehungen. Die letzten 20 % werden anschließend mit dem eingefrorenen Profil getestet.
""")

        }

    }

}

#Preview {

    OptimizerView()

}
