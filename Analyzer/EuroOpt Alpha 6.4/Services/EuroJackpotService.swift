//
//  EuroJackpotService.swift
//  EuroOpt
//
//  Alpha 6.0
//

import Foundation

final class EuroJackpotService {

    // MARK: - Database URL

    var databaseURL: URL {

        let fileManager = FileManager.default

        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let folder = applicationSupport.appendingPathComponent("EuroOpt")

        if !fileManager.fileExists(atPath: folder.path) {

            try? fileManager.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )

        }

        let fileURL = folder.appendingPathComponent("draws.json")

        if !fileManager.fileExists(atPath: fileURL.path) {

            if let bundleURL = Bundle.main.url(
                forResource: "draws",
                withExtension: "json"
            ) {

                print("===================================")
                print("Bundle-Datei gefunden:")
                print(bundleURL.path)

                do {

                    try fileManager.copyItem(
                        at: bundleURL,
                        to: fileURL
                    )

                    print("✅ Bundle-Datei wurde kopiert")

                } catch {

                    print("❌ Fehler beim Kopieren:")
                    print(error)

                }

            } else {

                print("❌ Bundle-Datei NICHT gefunden")

            }

        }

        return fileURL

    }

    // MARK: - Load

    func loadDraws() -> [EuroJackpotDraw] {

        do {

            let url = databaseURL

            print("===================================")
            print("Database URL:")
            print(url.path)

            let text = try String(
                contentsOf: url,
                encoding: .utf8
            )

            print("-----------------------------------")
            print("Erste 300 Zeichen:")
            print(String(text.prefix(300)))
            print("-----------------------------------")

            let data = Data(text.utf8)

            let decoder = JSONDecoder()

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            decoder.dateDecodingStrategy = .formatted(formatter)

            let draws = try decoder.decode(
                [EuroJackpotDraw].self,
                from: data
            )

            print("Anzahl Ziehungen:", draws.count)

            if let first = draws.first {

                print("Erste Ziehung:", first.date)

            }

            if let last = draws.last {

                print("Letzte Ziehung:", last.date)

            }

            print("===================================")

            return draws

        } catch {

            print("❌ Fehler beim Laden:")
            print(error)

            return []

        }

    }

    // MARK: - Save

    func saveDraws(
        data: Data
    ) throws {

        try data.write(
            to: databaseURL,
            options: .atomic
        )

    }

}
