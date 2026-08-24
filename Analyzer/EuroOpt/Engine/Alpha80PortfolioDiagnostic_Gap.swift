import Foundation

final class Alpha80PortfolioDiagnostic_Gap {

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

        print(">>> ALPHA80 GAP – DIESE DATEI WIRD AUSGEFÜHRT <<<")

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

        // MARK: - Score-Schwellenwert-Diagnose

        let scoreThresholds = [9, 18, 27, 36, 45, 60, 90]

        var scoreThresholdWinningTickets: [Int: Int] = [

            9: 0,

            18: 0,

            27: 0,

            36: 0,

            45: 0,

            60: 0,

            90: 0

        ]

        var scoreThresholdExact21Tickets: [Int: Int] = [

            9: 0,

            18: 0,

            27: 0,

            36: 0,

            45: 0,

            60: 0,

            90: 0

        ]

        var scoreThresholdThreePlusTickets: [Int: Int] = [

            9: 0,

            18: 0,

            27: 0,

            36: 0,

            45: 0,

            60: 0,

            90: 0

        ]

        // MARK: - F2-Diagnose

        let f2Values = [0.0, 0.25, 0.5, 1.0, 1.5, 2.0]

        var f2WinningTickets: [Double: Int] = [:]

        var f2Exact21Tickets: [Double: Int] = [:]

        var f2ThreePlusTickets: [Double: Int] = [:]

        // MARK: - Score-Komponenten-Diagnose

        let scoreComponentNames = [

            "Frequency",

            "Pair",

            "Even/Odd",

            "High/Low",

            "Sum",

            "Gap"

        ]

        var scoreComponentSystemHits: [String: Int] = [

            "Frequency": 0,

            "Pair": 0,

            "Even/Odd": 0,

            "High/Low": 0,

            "Sum": 0,

            "Gap": 0

        ]

        var scoreComponentWinningTickets: [String: Int] = [

            "Frequency": 0,

            "Pair": 0,

            "Even/Odd": 0,

            "High/Low": 0,

            "Sum": 0,

            "Gap": 0

        ]

        var scoreTop9PairOverlapTotal = 0

        var scoreTop9PairCount = 0

        var scoreTop9MaxOverlap = 0

        var scoreTop9StrongPairs = 0

        let scoreTop9Count = ticketCount

        // MARK: - Start

        print("==============================================")

        print("ALPHA 8.0 – PORTFOLIO-DIAGNOSTIK")

        print("==============================================")

        print("Ausgewertete Ziehungen : \\(evaluatedDraws)")

        print("Tickets je Variante    : \\(ticketCount)")

        print("Kandidaten je Ziehung  : \\(candidateCount)")

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

                        // MARK: - Optimierter Score-Pool

            // Ein gemeinsamer Cache fuer ALLE Score-Varianten.

            let scoreCache = ScoreCache(draws: training)

            let baseGoal = OptimizationGoal()

            let baseScoreEngine = ScoreEngine(

                cache: scoreCache,

                goal: baseGoal

            )

            // Frequency wird einmal separat auf 0 gesetzt.

            // Daraus lassen sich alle F2-Varianten exakt linear ableiten.

            var baseAndNoFrequency: [(Ticket, Double, Double)] = []

            baseAndNoFrequency.reserveCapacity(candidates.count)

            var noFrequencyGoal = baseGoal

            noFrequencyGoal.frequencyWeight = 0

            let noFrequencyEngine = ScoreEngine(

                cache: scoreCache,

                goal: noFrequencyGoal

            )

            for ticket in candidates {

                let baseScore = baseScoreEngine.score(ticket: ticket)

                let noFrequencyScore = noFrequencyEngine.score(ticket: ticket)

                baseAndNoFrequency.append((ticket, baseScore, noFrequencyScore))

            }

            let frequencyWeight = baseGoal.frequencyWeight

            func scoreWithFrequencyWeight(

                _ item: (Ticket, Double, Double),

                weight: Double

            ) -> (Ticket, Double) {

                let frequencyContribution: Double

                if abs(frequencyWeight) < 0.0000000001 {

                    frequencyContribution = 0

                } else {

                    frequencyContribution = (item.1 - item.2) / frequencyWeight

                }

                let score = item.2 + weight * frequencyContribution

                return (item.0, score)

            }

            var f2ScoredPools: [Double: [(Ticket, Double)]] = [:]

            for f2 in f2Values {

                let scoredForF2 = baseAndNoFrequency

                    .map { scoreWithFrequencyWeight($0, weight: f2) }

                    .sorted { $0.1 > $1.1 }

                f2ScoredPools[f2] = scoredForF2

            }

            // Standard-Score = F2 1.0

            let scored = f2ScoredPools[1.0] ?? []

            // MARK: - F2-Diagnose

            for f2 in f2Values {

                guard let f2Scored = f2ScoredPools[f2] else { continue }

                let top9F2 = f2Scored.prefix(min(9, f2Scored.count))

                for item in top9F2 {

                    let ticket = item.0

                    let main = Set(ticket.numbers).intersection(target.numbers).count

                    let euro = Set(ticket.euroNumbers).intersection(target.euroNumbers).count

                    if main == 2 && euro == 1 {

                        f2Exact21Tickets[f2, default: 0] += 1

                    }

                    if main >= 3 {

                        f2ThreePlusTickets[f2, default: 0] += 1

                    }

                    if (main >= 2 && euro >= 1) || main >= 3 {

                        f2WinningTickets[f2, default: 0] += 1

                    }

                }

            }

            // MARK: - Score-Komponenten-Diagnose

            let componentZeroing: [(String, (inout OptimizationGoal) -> Void)] = [

                ("Frequency", { $0.frequencyWeight = 0 }),

                ("Pair", { $0.pairWeight = 0 }),

                ("Even/Odd", { $0.evenOddWeight = 0 }),

                ("High/Low", { $0.highLowWeight = 0 }),

                ("Sum", { $0.sumWeight = 0 }),

                ("Gap", { $0.gapWeight = 0 })

            ]

            for (name, zeroComponent) in componentZeroing {

                var componentScored: [(Ticket, Double)]

                if name == "Frequency" {

                    // Bereits oben berechnet - keine zweite Score-Berechnung.

                    componentScored = baseAndNoFrequency

                        .map { ($0.0, $0.2) }

                        .sorted { $0.1 > $1.1 }

                } else {

                    var goal = baseGoal

                    zeroComponent(&goal)

                    let componentEngine = ScoreEngine(

                        cache: scoreCache,

                        goal: goal

                    )

                    componentScored = candidates

                        .map { ($0, componentEngine.score(ticket: $0)) }

                        .sorted { $0.1 > $1.1 }

                }

                let componentTop9 = componentScored.prefix(

                    min(scoreTop9Count, componentScored.count)

                )

                var systemHas21 = false

                for item in componentTop9 {

                    let ticket = item.0

                    let main = Set(ticket.numbers)

                        .intersection(target.numbers)

                        .count

                    let euro = Set(ticket.euroNumbers)

                        .intersection(target.euroNumbers)

                        .count

                    if (main >= 2 && euro >= 1) || main >= 3 {

                        systemHas21 = true

                    }

                    if main == 2 && euro == 1 {

                        scoreComponentWinningTickets[name, default: 0] += 1

                    } else if main >= 3 {

                        scoreComponentWinningTickets[name, default: 0] += 1

                    }

                }

                if systemHas21 {

                    scoreComponentSystemHits[name, default: 0] += 1

                }

            }

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

                let reduced = selectPortfolio(

                    scored: pool,

                    limit: min(ticketCount, pool.count)

                )

                if hasSystemHit(reduced, target: target) {

                    scoreRankingSystemHits[poolSize, default: 0] += 1

                }

            }









            // MARK: - Score-Schwellenwert-Diagnose

            for threshold in scoreThresholds {

                let actualCount = min(threshold, scored.count)

                for index in 0..<actualCount {

                    let ticket = scored[index].0

                    let main = Set(ticket.numbers)

                        .intersection(target.numbers)

                        .count

                    let euro = Set(ticket.euroNumbers)

                        .intersection(target.euroNumbers)

                        .count

                    if main == 2 && euro == 1 {

                        scoreThresholdExact21Tickets[threshold, default: 0] += 1

                    }

                    if main >= 3 {

                        scoreThresholdThreePlusTickets[threshold, default: 0] += 1

                    }

                    if (main >= 2 && euro >= 1) || main >= 3 {

                        scoreThresholdWinningTickets[threshold, default: 0] += 1

                    }

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

            if top9Has21 {

                scoreRankingSystemHits[9, default: 0] += 1

            }

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

                        scored: scored,

                        limit: ticketCount

                    )

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

        print("System       | Ziehungen | Wahrscheinlichkeit")

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

                format: "7.8          | %9d | %.1f%%",

                atLeast21Alpha78,

                alpha78Percent

            )

        )

        print(

            String(

                format: "Max1         | %9d | %.1f%%",

                atLeast21MaxOne,

                maxOnePercent

            )

        )

        print(

            String(

                format: "Max3         | %9d | %.1f%%",

                atLeast21MaxThree,

                maxThreePercent

            )

        )

        print(

            String(

                format: "Portfolio     | %9d | %.1f%%",

                atLeast21Portfolio,

                portfolioPercent

            )

        )

        print(

            String(

                format: "Zufall       | %9d | %.1f%%",

                atLeast21Random,

                randomPercent

            )

        )

        // MARK: - Systemvergleich

        print("")

        print("==============================================")

        print("SYSTEMVERGLEICH")

        print("==============================================")

        print("System       | ≥2+1 | Quote | Vorteil vs Zufall")

        print("------------------------------------------------")

        let randomBaseline = randomPercent

        print(

            String(

                format:

                    "7.8          | %4d | %5.1f%% | %+6.1f Pkt.",

                atLeast21Alpha78,

                alpha78Percent,

                alpha78Percent - randomBaseline

            )

        )

        print(

            String(

                format:

                    "Max1         | %4d | %5.1f%% | %+6.1f Pkt.",

                atLeast21MaxOne,

                maxOnePercent,

                maxOnePercent - randomBaseline

            )

        )

        print(

            String(

                format:

                    "Max3         | %4d | %5.1f%% | %+6.1f Pkt.",

                atLeast21MaxThree,

                maxThreePercent,

                maxThreePercent - randomBaseline

            )

        )

        print(

            String(

                format:

                    "Portfolio     | %4d | %5.1f%% | %+6.1f Pkt.",

                atLeast21Portfolio,

                portfolioPercent,

                portfolioPercent - randomBaseline

            )

        )

        print(

            String(

                format:

                    "Zufall       | %4d | %5.1f%% |      —",

                atLeast21Random,

                randomPercent

            )

        )

        // MARK: - Score-Diagnose

        print("")

        print("==============================================")

        print("F2-DIAGNOSE")

        print("==============================================")

        print("F2-Frequenzgewichtung → jeweils Top-9")

        print("------------------------------------------------")

        print("F2 | >=2+1 | Quote | 2+1 | 3+0 oder besser")

        print("------------------------------------------------")

        for f2 in f2Values {

            let hits = f2WinningTickets[f2, default: 0]

            let exact21 = f2Exact21Tickets[f2, default: 0]

            let threePlus = f2ThreePlusTickets[f2, default: 0]

            let percent = evaluatedDraws > 0 ? Double(hits) / Double(evaluatedDraws) * 100.0 : 0.0

            print(

                String(

                    format: "%.2f | %6d | %5.1f%% | %3d | %16d",

                    f2,

                    hits,

                    percent,

                    exact21,

                    threePlus

                )

            )

        }

        print("==============================================")

        print("")

        print("SCORE-KOMPONENTEN-DIAGNOSE")

        print("==============================================")

        print("Jeweils eine Score-Komponente auf 0 gesetzt")

        print("------------------------------------------------")

        print("Entfernte Komponente | ≥2+1 | Quote")

        print("------------------------------------------------")

        for name in scoreComponentNames {

            let hits = scoreComponentSystemHits[name, default: 0]

            let percent = evaluatedDraws > 0

                ? Double(hits) / Double(evaluatedDraws) * 100.0

                : 0.0

            print(

                String(

                    format: "%-19@ | %4d | %5.1f%%",

                    name,

                    hits,

                    percent

                )

            )

        }

        print("==============================================")

        print("")

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

                    "Top-9 Treffer     | %6d / %6d | %5.2f%%",

                scoreTop9WinningTickets,

                top9TotalTickets,

                top9TicketPercent

            )

        )

        print(

            String(

                format:

                    "Rest Treffer      | %6d / %6d | %5.2f%%",

                scoreRestWinningTickets,

                restTotalTickets,

                restTicketPercent

            )

        )

        print(

            String(

                format:

                    "Score-Vorteil     |              | %+5.2f Pkt.",

                scoreDifference

            )

        )

        print(

            String(

                format:

                    "Top-9 ≥2+1        | %6d / %6d | %5.1f%%",

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

            format: "2+1 exakt Top-9       | %5d",

            scoreTop9Exact21Tickets

        ))

        print(String(

            format: "2+1 exakt Rest        | %5d",

            scoreRestExact21Tickets

        ))

        print(String(

            format: "3+0 oder besser Top-9 | %5d",

            scoreTop9ThreePlusTickets

        ))

        print(String(

            format: "3+0 oder besser Rest  | %5d",

            scoreRestThreePlusTickets

        ))

        print(String(

            format: "Alle Gewinnklassen Top-9 | %5d",

            scoreTop9WinningTickets

        ))

        print(String(

            format: "Alle Gewinnklassen Rest  | %5d",

            scoreRestWinningTickets

        ))

        print("==============================================")

        print("==============================================")

        print("")

        print("==============================================")

        print("SCORE-SCHWELLENWERT-DIAGNOSE")

        print("==============================================")

        print("Trefferqualität des gesamten Score-Pools")

        print("------------------------------------------------")

        print("Pool | Treffer | Quote je Ticket | 2+1 | 3+0 oder besser")

        print("------------------------------------------------")

        for threshold in scoreThresholds {

            let hits = scoreThresholdWinningTickets[threshold, default: 0]

            let totalTickets = evaluatedDraws * threshold

            let percent = totalTickets > 0

                ? Double(hits) / Double(totalTickets) * 100.0

                : 0.0

            let exact21 = scoreThresholdExact21Tickets[threshold, default: 0]

            let threePlus = scoreThresholdThreePlusTickets[threshold, default: 0]

            print(

                String(

                    format: "Top-%-3d | %7d | %13.3f%% | %3d | %16d",

                    threshold,

                    hits,

                    percent,

                    exact21,

                    threePlus

                )

            )

        }

        print("==============================================")

        print("")

        print("SCORE-RANKING-DIAGNOSE")

        print("==============================================")

        print("Breitere Score-Pools → jeweils 9 Tipps")

        print("------------------------------------------------")

        let rankingPoolSizes = [9, 12, 15, 18, 21, 24, 27]

        for poolSize in rankingPoolSizes {

            let hits = scoreRankingSystemHits[poolSize, default: 0]

            let percent = Double(hits) / evaluated * 100.0

            if poolSize == 9 {

                print(String(format: "Top-9          | %4d | %5.1f%%", hits, percent))

            } else {

                print(String(format: "Top-%-2d → 9     | %4d | %5.1f%%", poolSize, hits, percent))

            }

        }

        print(String(format: "Zufall         | %4d | %5.1f%%", atLeast21Random, randomPercent))

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

                    "Verglichene Tipp-Paare      | %d",

                scoreTop9PairCount

            )

        )

        print("==============================================")

        // MARK: - Gewinnklassen gesamt

        print("")

        print("==============================================")

        print("GEWINNKLASSEN GESAMT")

        print("==============================================")

        print("System       | Treffer | Quote je 9-Tipp-System")

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

                    "7.8          | %7d | %5.2f%%",

                totalAlpha78,

                ticketRate(totalAlpha78)

            )

        )

        print(

            String(

                format:

                    "Max1         | %7d | %5.2f%%",

                totalMaxOne,

                ticketRate(totalMaxOne)

            )

        )

        print(

            String(

                format:

                    "Max3         | %7d | %5.2f%%",

                totalMaxThree,

                ticketRate(totalMaxThree)

            )

        )

        print(

            String(

                format:

                    "Portfolio     | %7d | %5.2f%%",

                totalPortfolio,

                ticketRate(totalPortfolio)

            )

        )

        print(

            String(

                format:

                    "Zufall       | %7d | %5.2f%%",

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

        limit: Int

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

                    Double(minimumDistance) * 0.15

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

