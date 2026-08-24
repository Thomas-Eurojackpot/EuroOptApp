import Foundation

final class Alpha80PortfolioDiagnostic_ControlABC {

    private let warmup = 100

    private enum Strategy: String, CaseIterable {

        case alpha78 = "7.8-Auswahl"

        case maxOne = "Max 1 gleiche Hauptzahl"

        case maxThree = "Max 3 gleiche Hauptzahlen"

        case portfolio = "Portfolio"

    }

    func run(

        draws: [EuroJackpotDraw],

        candidateCount: Int,

        recommendationCount: Int

    ) {

        guard draws.count > warmup else {

            print("❌ Zu wenige Ziehungen")

            return

        }

        let ticketCount = recommendationCount

        let totalDraws = min(580, draws.count)

        let evaluatedDraws = totalDraws - warmup

        var results: [Strategy: [[Int]]] = [:]

        for strategy in Strategy.allCases {

            results[strategy] = Array(

                repeating: Array(repeating: 0, count: 3),

                count: 6

            )

        }

        let randomGenerator = SeededRandomGenerator(

            seed: 0x80_20_26_01

        )

        var atLeast21Alpha78 = 0

        var atLeast21MaxOne = 0

        var atLeast21MaxThree = 0

        var atLeast21Portfolio = 0

        var atLeast21Random = 0

        // MARK: - A/B/C Kontrolltest

        // A = Score-Top-9 direkt

        // B = Portfolio mit DiversityBonus 0.00

        // C = Portfolio mit DiversityBonus 0.15

        var controlAHas21 = 0

        var controlBHas21 = 0

        var controlCHas21 = 0

        var controlATickets = 0

        var controlBTickets = 0

        var controlCTickets = 0

        var controlAExact21 = 0

        var controlBExact21 = 0

        var controlCExact21 = 0

        var controlAThreePlus = 0

        var controlBThreePlus = 0

        var controlCThreePlus = 0

        var random = Array(

            repeating: Array(repeating: 0, count: 3),

            count: 6

        )

        // MARK: - Score-Diagnose

        var scoreTop9WinningTickets = 0

        var scoreRestWinningTickets = 0

        var scoreRankingSystemHits: [Int: Int] = [

            9: 0,

            12: 0,

            15: 0,

            18: 0,

            21: 0,

            24: 0,

            27: 0

        ]

        var scoreTop9Exact21Tickets = 0

        var scoreTop9ThreePlusTickets = 0

        var scoreRestExact21Tickets = 0

        var scoreRestThreePlusTickets = 0

        var scoreTop9PairOverlapTotal = 0

        var scoreTop9PairCount = 0

        var scoreTop9MaxOverlap = 0

        var scoreTop9StrongPairs = 0

        // MARK: - Auswahl-Rang-Diagnose

        // Diagnose der bestehenden Portfolio-Auswahl im ursprünglichen Score-Ranking.

        let selectionRankThresholds = [9, 18, 27, 36, 45, 60, 90]

        var selectionRankCounts: [Int: Int] = [:]

        var selectionRankTotal = 0

        var selectionRankSum = 0

        var selectionRankBest = Int.max

        var selectionRankWorst = 0

        let scoreTop9Count = ticketCount

        // MARK: - Start

        print("==============================================")

        print("ALPHA 8.0 – PORTFOLIO-DIAGNOSTIK")

        print("==============================================")

        print("Ausgewertete Ziehungen : \\(evaluatedDraws)")

        print("Tickets je Variante    : \\(ticketCount)")

        print("Kandidaten je Ziehung  : \\(candidateCount)")

        print("==============================================")

        for index in warmup..<totalDraws {

            let target = draws[index]

            let training = Array(draws.prefix(index))

            let candidates = TicketGenerator().generate(

                count: candidateCount,

                draws: training,

                goal: OptimizationGoal(),

                hillClimbingIterations: 0

            )

            let scoreEngine = ScoreEngine(

                cache: ScoreCache(draws: training),

                goal: OptimizationGoal()

            )

            let scored = candidates

                .map { ($0, scoreEngine.score(ticket: $0)) }

                .sorted { $0.1 > $1.1 }

            // MARK: - Score-Diagnose

            let actualTop9Count = min(

                scoreTop9Count,

                scored.count

            )

            let top9 = Array(

                scored.prefix(actualTop9Count)

            )

            // MARK: - Score-Ranking-Diagnose

            // Breitere Score-Pools werden jeweils auf 9 Tipps reduziert.

            // Test: Top-9, 12, 15, 18, 21, 24 und 27.

            func hasSystemHit(_ tickets: [Ticket], target: EuroJackpotDraw) -> Bool {

                for ticket in tickets {

                    let main = Set(ticket.numbers)

                        .intersection(target.numbers)

                        .count

                    let euro = Set(ticket.euroNumbers)

                        .intersection(target.euroNumbers)

                        .count

                    if (main >= 2 && euro >= 1) || main >= 3 {

                        return true

                    }

                }

                return false

            }

            for poolSize in [9, 12, 15, 18, 21, 24, 27] {

                let pool = Array(scored.prefix(min(poolSize, scored.count)))

                let reduced: [Ticket]

                if poolSize == 9 {

                    reduced = pool.map { $0.0 }

                } else {

                    reduced = selectPortfolio(

                        scored: pool,

                        limit: min(ticketCount, pool.count)

                    )

                }

                if hasSystemHit(reduced, target: target) {

                    scoreRankingSystemHits[poolSize, default: 0] += 1

                }

            }





            // MARK: - Top-9-Überschneidungsdiagnose

            if top9.count >= 2 {

                for i in 0..<(top9.count - 1) {

                    for j in (i + 1)..<top9.count {

                        let overlap = commonNumbers(

                            top9[i].0,

                            top9[j].0

                        )

                        scoreTop9PairOverlapTotal += overlap

                        scoreTop9PairCount += 1

                        scoreTop9MaxOverlap = max(

                            scoreTop9MaxOverlap,

                            overlap

                        )

                        if overlap >= 4 {

                            scoreTop9StrongPairs += 1

                        }

                    }

                }

            }

            let rest = Array(

                scored.dropFirst(actualTop9Count)

            )

            var top9Has21 = false

            for item in top9 {

                let ticket = item.0

                let main = Set(ticket.numbers)

                    .intersection(target.numbers)

                    .count

                let euro = Set(ticket.euroNumbers)

                    .intersection(target.euroNumbers)

                    .count

                if main == 2 && euro == 1 {

                    scoreTop9Exact21Tickets += 1

                }

                if main >= 3 {

                    scoreTop9ThreePlusTickets += 1

                }

                if (main >= 2 && euro >= 1) || main >= 3 {

                    scoreTop9WinningTickets += 1

                    top9Has21 = true

                }

            }

            for item in rest {

                let ticket = item.0

                let main = Set(ticket.numbers)

                    .intersection(target.numbers)

                    .count

                let euro = Set(ticket.euroNumbers)

                    .intersection(target.euroNumbers)

                    .count

                if main == 2 && euro == 1 {

                    scoreRestExact21Tickets += 1

                }

                if main >= 3 {

                    scoreRestThreePlusTickets += 1

                }

                if (main >= 2 && euro >= 1) || main >= 3 {

                    scoreRestWinningTickets += 1

                }

            }

            // MARK: - A/B/C Kontrolltest

            // Exakt derselbe Kandidatenpool und derselbe Score.

            let controlA = Array(scored.prefix(min(ticketCount, scored.count)))

                .map { $0.0 }

            let controlB = selectPortfolio(

                scored: scored,

                limit: ticketCount,

                diversityBonusMultiplier: 0.0

            )

            let controlC = selectPortfolio(

                scored: scored,

                limit: ticketCount,

                diversityBonusMultiplier: 0.15

            )

            func evaluateControl(

                _ tickets: [Ticket],

                has21: inout Int,

                exact21: inout Int,

                threePlus: inout Int,

                ticketTotal: inout Int

            ) {

                var systemHas21 = false

                for ticket in tickets {

                    let main = Set(ticket.numbers).intersection(target.numbers).count

                    let euro = Set(ticket.euroNumbers).intersection(target.euroNumbers).count

                    ticketTotal += 1

                    if main == 2 && euro == 1 { exact21 += 1 }

                    if main >= 3 { threePlus += 1 }

                    if (main >= 2 && euro >= 1) || main >= 3 { systemHas21 = true }

                }

                if systemHas21 { has21 += 1 }

            }

            evaluateControl(controlA, has21: &controlAHas21, exact21: &controlAExact21, threePlus: &controlAThreePlus, ticketTotal: &controlATickets)

            evaluateControl(controlB, has21: &controlBHas21, exact21: &controlBExact21, threePlus: &controlBThreePlus, ticketTotal: &controlBTickets)

            evaluateControl(controlC, has21: &controlCHas21, exact21: &controlCExact21, threePlus: &controlCThreePlus, ticketTotal: &controlCTickets)

            // MARK: - Strategien

            for strategy in Strategy.allCases {

                let selected: [Ticket]

                switch strategy {

                case .alpha78:

                    selected = select(

                        scored: scored,

                        limit: ticketCount,

                        maximumCommonNumbers: 2

                    )

                case .maxOne:

                    selected = select(

                        scored: scored,

                        limit: ticketCount,

                        maximumCommonNumbers: 1

                    )

                case .maxThree:

                    selected = select(

                        scored: scored,

                        limit: ticketCount,

                        maximumCommonNumbers: 3

                    )

                case .portfolio:

                    selected = selectPortfolio(

                        scored: Array(scored.prefix(min(27, scored.count))),

                        limit: ticketCount

                    )

                }

                // MARK: - Auswahl-Rang-Diagnose

                // Nur Diagnose; die bestehende Auswahl wird nicht verändert.

                if strategy == .portfolio {

                    for ticket in selected {

                        if let rankIndex = scored.firstIndex(where: {

                            $0.0.numbers == ticket.numbers &&

                            $0.0.euroNumbers == ticket.euroNumbers

                        }) {

                            let rank = rankIndex + 1

                            selectionRankTotal += 1

                            selectionRankSum += rank

                            selectionRankBest = min(selectionRankBest, rank)

                            selectionRankWorst = max(selectionRankWorst, rank)

                            for threshold in selectionRankThresholds where rank <= threshold {

                                selectionRankCounts[threshold, default: 0] += 1

                            }

                        }

                    }

                }

                var systemHas21 = false

                for ticket in selected {

                    let main = Set(ticket.numbers)

                        .intersection(target.numbers)

                        .count

                    let euro = Set(ticket.euroNumbers)

                        .intersection(target.euroNumbers)

                        .count

                    results[strategy]![main][euro] += 1

                    if (main >= 2 && euro >= 1) || main >= 3 {

                        systemHas21 = true

                    }

                }

                if systemHas21 {

                    switch strategy {

                    case .alpha78:

                        atLeast21Alpha78 += 1

                    case .maxOne:

                        atLeast21MaxOne += 1

                    case .maxThree:

                        atLeast21MaxThree += 1

                    case .portfolio:

                        atLeast21Portfolio += 1

                    }

                }

            }

            // MARK: - Zufall

            // Gepaarter Zufall:

            // dieselben 9 Zufallstipps werden für

            // Gewinnklassen und Systemwertung verwendet.

            var randomTickets: [Ticket] = []

            randomTickets.reserveCapacity(ticketCount)

            for _ in 0..<ticketCount {

                randomTickets.append(

                    randomGenerator.makeTicket()

                )

            }

            var randomSystemHas21 = false

            for ticket in randomTickets {

                let main = Set(ticket.numbers)

                    .intersection(target.numbers)

                    .count

                let euro = Set(ticket.euroNumbers)

                    .intersection(target.euroNumbers)

                    .count

                random[main][euro] += 1

                if (main >= 2 && euro >= 1) || main >= 3 {

                    randomSystemHas21 = true

                }

            }

            if randomSystemHas21 {

                atLeast21Random += 1

            }

            let current = index - warmup + 1

            print(

                String(

                    format: "\rZiehung %d / %d",

                    current,

                    evaluatedDraws

                ),

                terminator: ""

            )

            fflush(stdout)

        }

        print("")

        print("")

        // MARK: - Gewinnklassen

        print("==============================================")

        print("GEWINNKLASSEN")

        print("==============================================")

        print(

            "Gewinnklasse | 7.8 | Max1 | Max3 | Portfolio | Zufall"

        )

        print("---------------------------------------------------------------")

        let winningClasses: [(Int, Int)] = [

            (2, 1),

            (2, 2),

            (3, 0),

            (3, 1),

            (3, 2),

            (4, 0),

            (4, 1),

            (4, 2),

            (5, 0),

            (5, 1),

            (5, 2)

        ]

        let totalTickets = evaluatedDraws * ticketCount

        for (main, euro) in winningClasses {

            func percentage(_ count: Int) -> Double {

                Double(count)

                    / Double(totalTickets)

                    * 100.0

            }

            let a = results[.alpha78]![main][euro]

            let b = results[.maxOne]![main][euro]

            let c = results[.maxThree]![main][euro]

            let d = results[.portfolio]![main][euro]

            let r = random[main][euro]

            print(

                String(

                    format:

                        "%d+%d | %4d / %.1f%% | %4d / %.1f%% | %4d / %.1f%% | %4d / %.1f%% | %4d / %.1f%%",

                    main,

                    euro,

                    a, percentage(a),

                    b, percentage(b),

                    c, percentage(c),

                    d, percentage(d),

                    r, percentage(r)

                )

            )

        }

        // MARK: - Mindestens 2+1

        print("==============================================")

        print("MINDESTENS 2+1 PRO 9-TIPP-SYSTEM")

        print("==============================================")

        print("System       | Ziehungen | Wahrscheinlichkeit")

        print("------------------------------------------------")

        let evaluated = Double(evaluatedDraws)

        let alpha78Percent =

            Double(atLeast21Alpha78)

            / evaluated

            * 100.0

        let maxOnePercent =

            Double(atLeast21MaxOne)

            / evaluated

            * 100.0

        let maxThreePercent =

            Double(atLeast21MaxThree)

            / evaluated

            * 100.0

        let portfolioPercent =

            Double(atLeast21Portfolio)

            / evaluated

            * 100.0

        let randomPercent =

            Double(atLeast21Random)

            / evaluated

            * 100.0

        print(

            String(

                format: "7.8          | %9d | %.1f%%",

                atLeast21Alpha78,

                alpha78Percent

            )

        )

        print(

            String(

                format: "Max1         | %9d | %.1f%%",

                atLeast21MaxOne,

                maxOnePercent

            )

        )

        print(

            String(

                format: "Max3         | %9d | %.1f%%",

                atLeast21MaxThree,

                maxThreePercent

            )

        )

        print(

            String(

                format: "Portfolio     | %9d | %.1f%%",

                atLeast21Portfolio,

                portfolioPercent

            )

        )

        print(

            String(

                format: "Zufall       | %9d | %.1f%%",

                atLeast21Random,

                randomPercent

            )

        )

        // MARK: - Systemvergleich

        print("")

        print("==============================================")

        print("SYSTEMVERGLEICH")

        print("==============================================")

        print("System       | ≥2+1 | Quote | Vorteil vs Zufall")

        print("------------------------------------------------")

        let randomBaseline = randomPercent

        print(

            String(

                format:

                    "7.8          | %4d | %5.1f%% | %+6.1f Pkt.",

                atLeast21Alpha78,

                alpha78Percent,

                alpha78Percent - randomBaseline

            )

        )

        print(

            String(

                format:

                    "Max1         | %4d | %5.1f%% | %+6.1f Pkt.",

                atLeast21MaxOne,

                maxOnePercent,

                maxOnePercent - randomBaseline

            )

        )

        print(

            String(

                format:

                    "Max3         | %4d | %5.1f%% | %+6.1f Pkt.",

                atLeast21MaxThree,

                maxThreePercent,

                maxThreePercent - randomBaseline

            )

        )

        print(

            String(

                format:

                    "Portfolio     | %4d | %5.1f%% | %+6.1f Pkt.",

                atLeast21Portfolio,

                portfolioPercent,

                portfolioPercent - randomBaseline

            )

        )

        print(

            String(

                format:

                    "Zufall       | %4d | %5.1f%% |      —",

                atLeast21Random,

                randomPercent

            )

        )

        // MARK: - Score-Diagnose

        print("")

        print("==============================================")

        print("SCORE-DIAGNOSE")

        print("==============================================")

        print("Vergleich: Top-9 nach Score vs. restliche Kandidaten")

        print("------------------------------------------------")

        let top9TotalTickets =

            evaluatedDraws * min(

                scoreTop9Count,

                candidateCount

            )

        let actualRestCount = max(

            0,

            candidateCount - min(

                scoreTop9Count,

                candidateCount

            )

        )

        let restTotalTickets =

            evaluatedDraws * actualRestCount

        let top9TicketPercent: Double

        if top9TotalTickets > 0 {

            top9TicketPercent =

                Double(scoreTop9WinningTickets)

                / Double(top9TotalTickets)

                * 100.0

        } else {

            top9TicketPercent = 0.0

        }

        let restTicketPercent: Double

        if restTotalTickets > 0 {

            restTicketPercent =

                Double(scoreRestWinningTickets)

                / Double(restTotalTickets)

                * 100.0

        } else {

            restTicketPercent = 0.0

        }

        let scoreDifference =

            top9TicketPercent - restTicketPercent

        let scoreSystemPercent =

            Double(scoreRankingSystemHits[9, default: 0])

            / evaluated

            * 100.0

        print(

            String(

                format:

                    "Top-9 Treffer     | %6d / %6d | %5.2f%%",

                scoreTop9WinningTickets,

                top9TotalTickets,

                top9TicketPercent

            )

        )

        print(

            String(

                format:

                    "Rest Treffer      | %6d / %6d | %5.2f%%",

                scoreRestWinningTickets,

                restTotalTickets,

                restTicketPercent

            )

        )

        print(

            String(

                format:

                    "Score-Vorteil     |              | %+5.2f Pkt.",

                scoreDifference

            )

        )

        print(

            String(

                format:

                    "Top-9 ≥2+1        | %6d / %6d | %5.1f%%",

                scoreRankingSystemHits[9, default: 0],

                evaluatedDraws,

                scoreSystemPercent

            )

        )

        print("==============================================")

        // MARK: - Top-9-Überschneidung

        print("")

        print("==============================================")

        print("SCORE-DIAGNOSE NACH GEWINNZIEL")

        print("==============================================")

        print("Vergleich: Top-9 vs. restliche Kandidaten")

        print("------------------------------------------------")

        print(String(

            format: "2+1 exakt Top-9       | %5d",

            scoreTop9Exact21Tickets

        ))

        print(String(

            format: "2+1 exakt Rest        | %5d",

            scoreRestExact21Tickets

        ))

        print(String(

            format: "3+0 oder besser Top-9 | %5d",

            scoreTop9ThreePlusTickets

        ))

        print(String(

            format: "3+0 oder besser Rest  | %5d",

            scoreRestThreePlusTickets

        ))

        print(String(

            format: "Alle Gewinnklassen Top-9 | %5d",

            scoreTop9WinningTickets

        ))

        print(String(

            format: "Alle Gewinnklassen Rest  | %5d",

            scoreRestWinningTickets

        ))

        print("==============================================")

        print("==============================================")

        print("")

        print("==============================================")

        print("SCORE-RANKING-DIAGNOSE")

        print("==============================================")

        print("Breitere Score-Pools → jeweils 9 Tipps")

        print("------------------------------------------------")

        let rankingPoolSizes = [9, 12, 15, 18, 21, 24, 27]

        for poolSize in rankingPoolSizes {

            // Top-9 is the direct Score Top-9 control and must use

            // exactly the same system-hit counter as A in the A/B/C test.

            if poolSize == 9 {

                let hits = controlAHas21

                let percent = Double(hits) / Double(evaluatedDraws) * 100.0

                print(String(format: "Top-9          | %4d | %5.1f%%", hits, percent))

            } else {

                let hits = scoreRankingSystemHits[poolSize, default: 0]

                let percent = Double(hits) / evaluated * 100.0

                print(String(format: "Top-%-2d → 9     | %4d | %5.1f%%", poolSize, hits, percent))

            }

        }

        print(String(format: "Zufall         | %4d | %5.1f%%", atLeast21Random, randomPercent))

        print("==============================================")

        print("")

        print("==============================================")

        print("AUSWAHL-RANG-DIAGNOSE")

        print("==============================================")

        print("Rang der tatsächlich ausgewählten Portfolio-Tipps")

        print("im ursprünglichen Score-Ranking")

        print("------------------------------------------------")

        print("Pool | Ausgewählte Tipps | Anteil")

        print("------------------------------------------------")

        for threshold in selectionRankThresholds {

            let count = selectionRankCounts[threshold, default: 0]

            let percent = selectionRankTotal > 0

                ? Double(count) / Double(selectionRankTotal) * 100.0

                : 0.0

            print(String(format: "Top-%-2d | %17d | %5.1f%%", threshold, count, percent))

        }

        if selectionRankTotal > 0 {

            let averageRank = Double(selectionRankSum) / Double(selectionRankTotal)

            print(String(format: "Ø Rang                     | %.1f", averageRank))

            print(String(format: "Anzahl ausgewerteter Tipps | %d", selectionRankTotal))

            print(String(format: "Bester Rang                | %d", selectionRankBest))

            print(String(format: "Schlechtester Rang         | %d", selectionRankWorst))

        } else {

            print("Keine ausgewählten Tipps gefunden")

        }

        print("==============================================")

        print("")

        print("TOP-9 SCORE – ÜBERSCHNEIDUNG")

        print("==============================================")

        let averageTop9Overlap: Double

        if scoreTop9PairCount > 0 {

            averageTop9Overlap =

                Double(scoreTop9PairOverlapTotal)

                / Double(scoreTop9PairCount)

        } else {

            averageTop9Overlap = 0.0

        }

        print(

            String(

                format:

                    "Ø gemeinsame Hauptzahlen | %.2f",

                averageTop9Overlap

            )

        )

        print(

            String(

                format:

                    "Max. gemeinsame Hauptzahlen | %d",

                scoreTop9MaxOverlap

            )

        )

        print(

            String(

                format:

                    "Stark ähnliche Paare (≥4) | %d",

                scoreTop9StrongPairs

            )

        )

        print(

            String(

                format:

                    "Verglichene Tipp-Paare      | %d",

                scoreTop9PairCount

            )

        )

        print("==============================================")

        // MARK: - Gewinnklassen gesamt

        print("")

        print("==============================================")

        print("A/B/C KONTROLLTEST")

        print("==============================================")

        print("A = Score Top-9 direkt")

        print("B = Portfolio DiversityBonus 0.00")

        print("C = Portfolio DiversityBonus 0.15")

        print("------------------------------------------------")

        print("Variante | >=2+1 | Quote | 2+1 | 3+0 oder besser")

        print("------------------------------------------------")

        print(String(format: "A Top-9  | %6d | %5.1f%% | %4d | %16d", controlAHas21, Double(controlAHas21) / Double(evaluatedDraws) * 100.0, controlAExact21, controlAThreePlus))

        print(String(format: "B Bonus0  | %6d | %5.1f%% | %4d | %16d", controlBHas21, Double(controlBHas21) / Double(evaluatedDraws) * 100.0, controlBExact21, controlBThreePlus))

        print(String(format: "C Bonus15 | %6d | %5.1f%% | %4d | %16d", controlCHas21, Double(controlCHas21) / Double(evaluatedDraws) * 100.0, controlCExact21, controlCThreePlus))

        print("==============================================")

        print("")

        print("GEWINNKLASSEN GESAMT")

        print("==============================================")

        print("System       | Treffer | Quote je 9-Tipp-System")

        print("------------------------------------------------")

        func totalWinningClasses(

            _ strategy: Strategy

        ) -> Int {

            guard let matrix = results[strategy] else {

                return 0

            }

            return winningClasses.reduce(0) { total, entry in

                total + matrix[entry.0][entry.1]

            }

        }

        let totalAlpha78 =

            totalWinningClasses(.alpha78)

        let totalMaxOne =

            totalWinningClasses(.maxOne)

        let totalMaxThree =

            totalWinningClasses(.maxThree)

        let totalPortfolio =

            totalWinningClasses(.portfolio)

        let totalRandom =

            winningClasses.reduce(0) { total, entry in

                total + random[entry.0][entry.1]

            }

        func ticketRate(_ count: Int) -> Double {

            Double(count)

                / Double(totalTickets)

                * 100.0

        }

        print(

            String(

                format:

                    "7.8          | %7d | %5.2f%%",

                totalAlpha78,

                ticketRate(totalAlpha78)

            )

        )

        print(

            String(

                format:

                    "Max1         | %7d | %5.2f%%",

                totalMaxOne,

                ticketRate(totalMaxOne)

            )

        )

        print(

            String(

                format:

                    "Max3         | %7d | %5.2f%%",

                totalMaxThree,

                ticketRate(totalMaxThree)

            )

        )

        print(

            String(

                format:

                    "Portfolio     | %7d | %5.2f%%",

                totalPortfolio,

                ticketRate(totalPortfolio)

            )

        )

        print(

            String(

                format:

                    "Zufall       | %7d | %5.2f%%",

                totalRandom,

                ticketRate(totalRandom)

            )

        )

        print("==============================================")

    }

    private func select(

        scored: [(Ticket, Double)],

        limit: Int,

        maximumCommonNumbers: Int

    ) -> [Ticket] {

        var result: [Ticket] = []

        result.reserveCapacity(limit)

        for item in scored {

            var different = true

            for existing in result {

                if commonNumbers(existing, item.0)

                    > maximumCommonNumbers {

                    different = false

                    break

                }

            }

            if different {

                result.append(item.0)

                if result.count == limit {

                    break

                }

            }

        }

        return result

    }

    private func selectPortfolio(

        scored: [(Ticket, Double)],

        limit: Int,

        diversityBonusMultiplier: Double = 0.15

    ) -> [Ticket] {

        guard !scored.isEmpty else {

            return []

        }

        var result: [Ticket] = []

        result.reserveCapacity(limit)

        result.append(scored[0].0)

        while result.count < limit {

            var bestTicket: Ticket?

            var bestValue = -Double.infinity

            for candidate in scored {

                if result.contains(where: {

                    $0.numbers == candidate.0.numbers &&

                    $0.euroNumbers == candidate.0.euroNumbers

                }) {

                    continue

                }

                let minimumDistance = result.map {

                    5 - commonNumbers($0, candidate.0)

                }.min() ?? 0

                let diversityBonus =

                    Double(minimumDistance) * diversityBonusMultiplier

                let value =

                    candidate.1 + diversityBonus

                if value > bestValue {

                    bestValue = value

                    bestTicket = candidate.0

                }

            }

            guard let bestTicket else {

                break

            }

            result.append(bestTicket)

        }

        return result

    }

    private func commonNumbers(

        _ lhs: Ticket,

        _ rhs: Ticket

    ) -> Int {

        var count = 0

        for number in lhs.numbers {

            if rhs.numbers.contains(number) {

                count += 1

            }

        }

        return count

    }

    private final class SeededRandomGenerator {

        private var state: UInt64

        init(seed: UInt64) {

            self.state = seed

        }

        private func next() -> UInt64 {

            state =

                state &* 6364136223846793005

                &+ 1442695040888963407

            return state

        }

        private func randomInt(

            _ upperBound: Int

        ) -> Int {

            Int(

                next()

                % UInt64(upperBound)

            )

        }

        func makeTicket() -> Ticket {

            var numbers = Set<Int>()

            while numbers.count < 5 {

                numbers.insert(

                    randomInt(50) + 1

                )

            }

            var euroNumbers = Set<Int>()

            while euroNumbers.count < 2 {

                euroNumbers.insert(

                    randomInt(12) + 1

                )

            }

            return Ticket(

                numbers: numbers.sorted(),

                euroNumbers: euroNumbers.sorted()

            )

        }

    }

}

