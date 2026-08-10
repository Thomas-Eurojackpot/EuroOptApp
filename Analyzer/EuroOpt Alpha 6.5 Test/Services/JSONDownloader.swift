//
//  JSONDownloader.swift
//  EuroOpt
//
//  Alpha 5.3
//

import Foundation

final class JSONDownloader {

    enum DownloadError: Error {
        case invalidURL
        case invalidResponse
        case noData
    }

    func download(
        from urlString: String,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {

        guard let url = URL(string: urlString) else {
            completion(.failure(DownloadError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse,
                  200...299 ~= http.statusCode else {

                completion(.failure(DownloadError.invalidResponse))
                return
            }

            guard let data else {
                completion(.failure(DownloadError.noData))
                return
            }

            completion(.success(data))

        }
        .resume()

    }

}
