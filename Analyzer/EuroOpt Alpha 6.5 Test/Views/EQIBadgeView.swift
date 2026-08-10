//
//  EQIBadgeView.swift
//  EuroOpt
//
//  Alpha 2.2
//

import SwiftUI

struct EQIBadgeView: View {

    // MARK: - Properties

    let eqi: EQI

    private var progress: Double {
        max(0, min(eqi.value / 100.0, 1.0))
    }

    private var badgeColor: Color {

        switch eqi.value {

        case 90...100:
            return .green

        case 80..<90:
            return .mint

        case 70..<80:
            return .yellow

        case 60..<70:
            return .orange

        default:
            return .red

        }

    }

    // MARK: - Body

    var body: some View {

        VStack(spacing: 16) {

            ZStack {

                Circle()
                    .stroke(
                        Color.gray.opacity(0.15),
                        lineWidth: 12
                    )

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        badgeColor,
                        style: StrokeStyle(
                            lineWidth: 12,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {

                    Text("EQI")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(
                        String(
                            format: "%.1f",
                            eqi.value
                        )
                    )
                    .font(.system(size: 28, weight: .bold))

                }

            }
            .frame(width: 120, height: 120)

            Text(eqi.rating)
                .font(.headline)

            ProgressView(value: progress)
                .tint(badgeColor)
                .frame(width: 180)

        }

        .padding(.vertical, 8)

    }

}

#Preview {

    VStack(spacing: 25) {

        EQIBadgeView(
            eqi: EQI(value: 94.8)
        )

        EQIBadgeView(
            eqi: EQI(value: 82.1)
        )

        EQIBadgeView(
            eqi: EQI(value: 67.5)
        )

    }
    .padding()

}
