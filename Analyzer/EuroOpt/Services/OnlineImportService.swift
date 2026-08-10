import Foundation

final class OnlineImportService {

    // LOTTO.de's former JSON endpoint is currently returning a stale archive.
    // WestLotto publishes the current Eurojackpot result on a stable public page.
    private let url = URL(string: "https://www.westlotto.de/infos-und-zahlen/gewinnzahlen/eurojackpot/gewinnzahlen_ejp.html")!

    func downloadLatestDraws(
        completion: @escaping (Result<Data, Error>) -> Void
    ) {

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            guard let data, !data.isEmpty else {
                completion(.failure(URLError(.zeroByteResource)))
                return
            }

            do {
                let normalized = try Self.parseWestLottoPage(data)
                completion(.success(normalized))
            } catch {
                completion(.failure(error))
            }

        }.resume()
    }

    private static func parseWestLottoPage(_ data: Data) throws -> Data {

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Remove markup first. This keeps the parser independent of the
        // current HTML nesting while retaining the visible result text.
        let plain = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Current page format:
        // Ergebnisse vom Freitag, den 07.08.2026 1 3 6 13 23 5 7
        let pattern = "Ergebnisse vom [^0-9]*([0-9]{2}\\.[0-9]{2}\\.[0-9]{4}) ([0-9]{1,2}) ([0-9]{1,2}) ([0-9]{1,2}) ([0-9]{1,2}) ([0-9]{1,2}) ([0-9]{1,2}) ([0-9]{1,2})"

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: plain, range: NSRange(plain.startIndex..., in: plain)) else {
            throw URLError(.cannotParseResponse)
        }

        func capture(_ index: Int) -> String? {
            let range = match.range(at: index)
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: plain) else {
                return nil
            }
            return String(plain[swiftRange])
        }

        guard let dateString = capture(1),
              let date = Self.parseDate(dateString) else {
            throw URLError(.cannotParseResponse)
        }

        var values: [Int] = []
        for index in 2...8 {
            guard let value = capture(index), let number = Int(value) else {
                throw URLError(.cannotParseResponse)
            }
            values.append(number)
        }

        let mainNumbers = Array(values.prefix(5))
        let euroNumbers = Array(values.suffix(2))

        guard mainNumbers.count == 5,
              euroNumbers.count == 2,
              Set(mainNumbers).count == 5,
              Set(euroNumbers).count == 2,
              mainNumbers.allSatisfy({ (1...50).contains($0) }),
              euroNumbers.allSatisfy({ (1...12).contains($0) }) else {
            throw URLError(.cannotParseResponse)
        }

        let draw: [[String: Any]] = [[
            "date": Self.formatDate(date),
            "numbers": mainNumbers,
            "euroNumbers": euroNumbers
        ]]

        return try JSONSerialization.data(withJSONObject: draw, options: [.prettyPrinted])
    }

    private static func parseDate(_ value: String) -> Date? {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: value)
    }

    private static func formatDate(_ date: Date) -> String {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
