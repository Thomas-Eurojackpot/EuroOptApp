//
//  DeveloperLabView.swift
//  EuroOpt
//

import SwiftUI

struct DeveloperLabView: View {

    private let database = DrawDatabase()
    private let engine = ScoreEngine()

    var body: some View {

        let ticket = Ticket(
            numbers: [4, 8, 17, 31, 45],
            euroNumbers: [2, 10]
        )

        let draws = database.allDraws()

        let score = engine.score(
            ticket: ticket,
            draws: draws
        )

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                Text("Developer Lab")
                    .font(.largeTitle)
                    .bold()

                Divider()

                Text("Testticket")

                Text(
                    ticket.numbers
                        .map(String.init)
                        .joined(separator: " • ")
                )
                .font(.title2)

                Text(
                    "⭐ " +
                    ticket.euroNumbers
                        .map(String.init)
                        .joined(separator: " • ⭐ ")
                )

                Divider()

                Text("EQI")

                Text(
                    String(format: "%.2f", score)
                )
                .font(.system(size: 48, weight: .bold))

            }

            .padding()

        }

    }

}

#Preview {

    DeveloperLabView()

}
