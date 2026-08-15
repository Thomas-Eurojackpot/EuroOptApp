import Foundation

struct SavedRecommendations: Codable {

    let drawDate: String
    let reports: [SavedRecommendation]
}

struct SavedRecommendation: Codable {

    let numbers: [Int]
    let euroNumbers: [Int]
    let eqi: Double
}

final class SavedRecommendationsStore {

    private let fileManager = FileManager.default

    private var fileURL: URL {

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

        return folder.appendingPathComponent(
            "savedRecommendations.json"
        )
    }

    func load() -> SavedRecommendations? {

#if DEBUG
        // Diagnose Alpha 7.6 from a clean optimizer run.
        // The production release keeps the normal persistence behavior.
        return nil
#else
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)

            return try JSONDecoder().decode(
                SavedRecommendations.self,
                from: data
            )

        } catch {
            print("❌ Gespeicherte Empfehlungen konnten nicht geladen werden:")
            print(error)
            return nil
        }
#endif
    }

    func save(
        drawDate: String,
        reports: [OptimizerReport]
    ) {

        let saved = SavedRecommendations(
            drawDate: drawDate,
            reports: reports.map {
                SavedRecommendation(
                    numbers: $0.ticket.numbers,
                    euroNumbers: $0.ticket.euroNumbers,
                    eqi: $0.eqi.value
                )
            }
        )

        do {

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(saved)

            try data.write(
                to: fileURL,
                options: .atomic
            )

            print("💾 Empfehlungen gespeichert")
            print("   Ziehung: \(drawDate)")
            print("   Tipps: \(reports.count)")

        } catch {

            print("❌ Empfehlungen konnten nicht gespeichert werden:")
            print(error)
        }
    }
}
