import Foundation

final class UpdateManager {

    // MARK: - Properties

    private let downloader = DownloadService()
    private let onlineImport = OnlineImportService()
    private let database = DrawDatabase()

    // MARK: - Public

    func updateIfNeeded(
        completion: @escaping (Bool) -> Void
    ) {

        print("▶️ updateIfNeeded gestartet")

        // First ask the live LOTTO.de source. This makes the app independent
        // from a manually maintained version.json for detecting new draws.
        onlineImport.downloadLatestDraws { result in

            switch result {

            case .success(let data):

                print("✅ LOTTO.de Online-Daten geladen")
                print("Bytes:", data.count)

                if let onlineDraws = self.decodeOnlineDraws(data) {

                    print("Online Ziehungen erkannt:", onlineDraws.count)

                    let localDraws = self.database.allDraws()
                    let localLatest = localDraws.max { $0.date < $1.date }?.date
                    let onlineLatest = onlineDraws.max { $0.date < $1.date }?.date

                    if let onlineLatest {
                        print("Online letzte Ziehung:", self.formatDate(onlineLatest))
                    }

                    if let localLatest {
                        print("Lokale letzte Ziehung:", self.formatDate(localLatest))
                    }

                    guard let onlineLatest else {
                        print("⚠️ Online-Daten enthalten keine gültige Ziehung")
                        self.fallbackToRepository(completion: completion)
                        return
                    }

                    if localLatest == nil || onlineLatest > localLatest! {

                        do {

                            // The live endpoint may return the complete archive
                            // or only the latest draw. Merge instead of replacing
                            // the local archive so historical data is never lost.
                            let mergedDraws = self.mergeDraws(
                                localDraws,
                                with: onlineDraws
                            )

                            let normalized = try self.encodeDraws(mergedDraws)
                            try self.database.replaceDatabase(with: normalized)

                            print("⬇️ Neue Ziehungen übernommen")
                            print("Datenbank nach Update:", mergedDraws.count, "Ziehungen")

                            completion(true)

                        } catch {

                            print("❌ Fehler beim Speichern der Online-Daten")
                            print(error)
                            self.fallbackToRepository(completion: completion)

                        }

                    } else {

                        print("⛔ Keine neue Ziehung vorhanden")
                        completion(false)

                    }

                } else {

                    print("⚠️ LOTTO.de Format konnte nicht erkannt werden")
                    self.fallbackToRepository(completion: completion)
                }

            case .failure(let error):

                print("⚠️ LOTTO.de Online-Import fehlgeschlagen")
                print(error)
                self.fallbackToRepository(completion: completion)
            }
        }
    }

    // MARK: - Repository fallback

    private func fallbackToRepository(
        completion: @escaping (Bool) -> Void
    ) {

        print("↩️ Fallback auf EuroOptData")

        downloader.downloadVersion { result in

            switch result {

            case .success(let onlineVersion):

                print("✅ version.json geladen")
                print("Online Version:", onlineVersion.version)
                print("Online LastDraw:", onlineVersion.lastDraw)
                print("Online DrawCount:", onlineVersion.drawCount)

                let localDraws = self.database.allDraws()

                guard let latestLocal = localDraws.max(by: { $0.date < $1.date }) else {

                    print("Keine lokale Datenbank")
                    self.downloadDatabase(completion: completion)
                    return
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                guard let onlineDate = formatter.date(from: onlineVersion.lastDraw) else {

                    print("❌ Datum konnte nicht gelesen werden")
                    completion(false)
                    return
                }

                print("Lokale letzte Ziehung:", self.formatDate(latestLocal.date))
                print("Repository letzte Ziehung:", self.formatDate(onlineDate))

                if latestLocal.date < onlineDate {

                    self.downloadDatabase(completion: completion)

                } else {

                    print("⛔ Kein Download nötig")
                    completion(false)

                }

            case .failure(let error):

                print("❌ Fehler beim Laden von version.json")
                print(error)
                completion(false)
            }
        }
    }

    private func downloadDatabase(
        completion: @escaping (Bool) -> Void
    ) {

        print("⬇️ downloadDatabase()")

        downloader.downloadDraws { result in

            switch result {

            case .success(let data):

                print("✅ draws.json geladen")
                print("Bytes:", data.count)

                do {

                    try self.database.replaceDatabase(with: data)

                    print("✅ Datenbank ersetzt")
                    completion(true)

                } catch {

                    print("❌ Fehler beim Speichern")
                    print(error)
                    completion(false)
                }

            case .failure(let error):

                print("❌ Fehler beim Download")
                print(error)
                completion(false)
            }
        }
    }

    // MARK: - Online decoding

    private func decodeOnlineDraws(_ data: Data) -> [EuroJackpotDraw]? {

        let decoder = JSONDecoder()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        decoder.dateDecodingStrategy = .custom { decoder in

            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formats = [
                "yyyy-MM-dd",
                "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
            ]

            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: value) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unbekanntes Datum: \(value)"
            )
        }

        // Expected format: the same [EuroJackpotDraw] structure used by
        // EuroOptData. Try that first because it is lossless and fast.
        if let draws = try? decoder.decode([EuroJackpotDraw].self, from: data),
           !draws.isEmpty {
            return draws.sorted { $0.date < $1.date }
        }

        // LOTTO.de may wrap the data differently. The generic parser accepts
        // common date/number key variants and ignores unrelated objects.
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        var draws: [EuroJackpotDraw] = []
        collectDraws(from: object, into: &draws)

        let unique = Dictionary(grouping: draws, by: { $0.date })
            .compactMap { $0.value.first }
            .sorted { $0.date < $1.date }

        return unique.isEmpty ? nil : unique
    }

    private func collectDraws(from value: Any, into draws: inout [EuroJackpotDraw]) {

        if let array = value as? [Any] {
            for item in array {
                collectDraws(from: item, into: &draws)
            }
            return
        }

        guard let dictionary = value as? [String: Any] else {
            return
        }

        if let date = firstString(
            in: dictionary,
            keys: ["date", "drawDate", "drawingDate", "draw_date"]
        ),
           let numbers = firstIntArray(
                in: dictionary,
                keys: ["numbers", "winningNumbers", "mainNumbers", "winning_numbers"]
           ),
           let euroNumbers = firstIntArray(
                in: dictionary,
                keys: ["euroNumbers", "euroNumbersDrawn", "euroNumbersWinning", "euro_numbers"]
           ),
           numbers.count >= 5,
           euroNumbers.count >= 2,
           numbers.prefix(5).allSatisfy({ (1...50).contains($0) }),
           euroNumbers.prefix(2).allSatisfy({ (1...12).contains($0) }) {

            if let parsedDate = parseDate(date) {
                let draw = EuroJackpotDraw(
                    date: parsedDate,
                    numbers: Array(numbers.prefix(5)),
                    euroNumbers: Array(euroNumbers.prefix(2))
                )
                draws.append(draw)
            }
        }

        for nested in dictionary.values {
            collectDraws(from: nested, into: &draws)
        }
    }

    private func firstString(
        in dictionary: [String: Any],
        keys: [String]
    ) -> String? {

        for key in keys {
            if let value = dictionary[key] as? String {
                return value
            }
        }

        return nil
    }

    private func firstIntArray(
        in dictionary: [String: Any],
        keys: [String]
    ) -> [Int]? {

        for key in keys {
            if let values = dictionary[key] as? [Int] {
                return values
            }

            if let values = dictionary[key] as? [NSNumber] {
                return values.map(\.intValue)
            }
        }

        return nil
    }

    private func parseDate(_ value: String) -> Date? {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in [
            "yyyy-MM-dd",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func mergeDraws(
        _ localDraws: [EuroJackpotDraw],
        with onlineDraws: [EuroJackpotDraw]
    ) -> [EuroJackpotDraw] {

        var byDate: [Date: EuroJackpotDraw] = [:]

        for draw in localDraws {
            byDate[draw.date] = draw
        }

        for draw in onlineDraws {
            byDate[draw.date] = draw
        }

        return byDate.values.sorted { $0.date < $1.date }
    }

    private func encodeDraws(_ draws: [EuroJackpotDraw]) throws -> Data {

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        encoder.dateEncodingStrategy = .formatted(formatter)

        return try encoder.encode(draws.sorted { $0.date < $1.date })
    }

    private func formatDate(_ date: Date) -> String {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
