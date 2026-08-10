import Foundation

final class OnlineImportService {

    private let url = URL(string: "https://www.lotto.de/bin/eurojackpot.json")!

    func downloadLatestDraws(
        completion: @escaping (Result<Data, Error>) -> Void
    ) {

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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

            completion(.success(data))

        }.resume()
    }
}
