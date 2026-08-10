//
//  RecommendationCardView.swift
//  EuroOpt
//
//  Alpha 6.2
//

import SwiftUI

struct RecommendationCardView: View {

    // MARK: - Properties

    let rank: Int
    let report: OptimizerReport

    // MARK: - Body

    var body: some View {

        GroupBox {

            VStack(spacing: 20) {

                // Rang

                HStack {

                    Label(
                        "Empfehlung \(rank)",
                        systemImage: rankSymbol
                    )
                    .font(.headline)

                    Spacer()

                }

                // EQI

                EQIBadgeView(
                    eqi: report.eqi
                )

                Divider()

                // Hauptzahlen

                VStack(spacing: 10) {

                    Text("Hauptzahlen")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(
                        report.ticket.numbers
                            .map(String.init)
                            .joined(separator: " • ")
                    )
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                }

                // Eurozahlen

                VStack(spacing: 8) {

                    Text("Eurozahlen")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(
                        "⭐ " +
                        report.ticket.euroNumbers
                            .map(String.init)
                            .joined(separator: " • ⭐ ")
                    )
                    .font(.headline)

                }

                // Detailanalyse

                if let result = report.scoreResult {

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {

                        Text("Analyse")
                            .font(.headline)

                        ScoreRow(
                            title: "Häufigkeit",
                            value: result.frequencyScore
                        )

                        ScoreRow(
                            title: "Paare",
                            value: result.pairScore
                        )

                        ScoreRow(
                            title: "Gerade / Ungerade",
                            value: result.evenOddScore
                        )

                        ScoreRow(
                            title: "Hoch / Niedrig",
                            value: result.highLowScore
                        )

                    }

                }

                Divider()

                VStack(spacing: 8) {

                    Text("Bewertung")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(report.recommendation)
                        .font(.headline)

                }

            }

            .frame(maxWidth: .infinity)
            .padding()

        }

    }

}

// MARK: - ScoreRow

private struct ScoreRow: View {

    let title: String
    let value: Double

    var body: some View {

        HStack {

            Text(title)

            Spacer()

            ProgressView(value: value, total: 100)
                .frame(width: 120)

            Text(String(format: "%.0f", value))
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()

        }

    }

}

// MARK: - Private

private extension RecommendationCardView {

    var rankSymbol: String {

        switch rank {

        case 1:
            return "trophy.fill"

        case 2:
            return "medal.fill"

        case 3:
            return "rosette"

        default:
            return "star"

        }

    }

}

// MARK: - Preview

#Preview {

    RecommendationCardView(

        rank: 1,

        report: OptimizerReport(

            ticket: Ticket(
                numbers: [4, 8, 17, 31, 45],
                euroNumbers: [2, 10]
            ),

            eqi: EQI(value: 91.4)

        )

    )
    .padding()

}
