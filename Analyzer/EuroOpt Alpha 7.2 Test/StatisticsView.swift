import SwiftUI
import Charts

struct StatisticsView: View {

    private let database = DrawDatabase()
    private let analyzer = FrequencyAnalyzer()

    var body: some View {

        let draws = database.allDraws()
        let frequencies = analyzer.sortedFrequency(of: draws)

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 25) {

                    Text("📊 Statistik")
                        .font(.largeTitle)
                        .bold()

                    GroupBox("Datenbank") {

                        HStack {

                            Text("Ziehungen")

                            Spacer()

                            Text("\(database.count)")

                        }

                    }

                    GroupBox("Top 10 Häufigste Zahlen") {

                        Chart(frequencies.prefix(10), id: \.number) { item in

                            BarMark(
                                x: .value("Zahl", "\(item.number)"),
                                y: .value("Treffer", item.count)
                            )

                        }
                        .frame(height: 300)

                    }

                }

                .padding()

            }

            .navigationTitle("Statistik")

        }

    }

}

#Preview {

    StatisticsView()

}
