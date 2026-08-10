import Foundation

final class OnlineImportService {

    func downloadLatestDraws(completion: @escaping (Result<Data, Error>) -> Void) {

        guard let url = URL(string: "https://www.lotto.de/bin/eurojackpot.json") else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            completion(.success(data))

        }.resume()

    }

}
