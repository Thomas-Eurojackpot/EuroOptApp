//
//  OptimizerView.swift
//  EuroOpt
//
//  Alpha 6.2
//

import SwiftUI

struct OptimizerView: View {

    // MARK: - Properties

    @StateObject
    private var viewModel = OptimizerViewModel()

    @StateObject
    private var settingsViewModel = OptimizerSettingsViewModel()

    @State
    private var showSettings = false

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    headerSection

                    actionSection

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
            .disabled(viewModel.isCalculating)

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
Die Vorschläge werden aus zufällig erzeugten gültigen Spielsystemen ausgewählt und anhand der aktuellen Bewertungs-Engine bewertet.

Der EQI (EuroOpt Quality Index) beschreibt die Qualität einer Zahlenkombination anhand definierter Bewertungskriterien.

Er stellt keine Vorhersage zukünftiger Ziehungen oder der Gewinnwahrscheinlichkeit dar.
""")

        }

    }

}

// MARK: - Preview

#Preview {

    OptimizerView()

}
