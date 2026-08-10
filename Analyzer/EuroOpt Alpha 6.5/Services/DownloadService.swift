//
//  DownloadService.swift
//  EuroOpt
//
//  Alpha 6.0
//

import Foundation

final class DownloadService {

    // MARK: - URLs

    private let versionURL = URL(
        string: "https://raw.githubusercontent.com/Thomas-Eurojackpot/EuroOptData/main/version.json"
    )!

    private let drawsURL = URL(
        string: "https://raw.githubusercontent.com/Thomas-Eurojackpot/EuroOptData/main/draws.json"
    )!

    // MARK: - Version

    func downloadVersion(
        completion: @escaping (Result<VersionInfo, Error>) -> Void
    ) {

        URLSession.shared.dataTask(with: versionURL) { data, _, error in

            if let error {

                completion(.failure(error))
                return

            }

            guard let data else {

                completion(
                    .failure(
                        URLError(.badServerResponse)
                    )
                )

                return

            }

            do {

                let version = try JSONDecoder().decode(
                    VersionInfo.self,
                    from: data
                )

                completion(.success(version))

            } catch {

                completion(.failure(error))

            }

        }
        .resume()

    }

    // MARK: - Draws

    func downloadDraws(
        completion: @escaping (Result<Data, Error>) -> Void
    ) {

        URLSession.shared.dataTask(with: drawsURL) { data, _, error in

            if let error {

                completion(.failure(error))
                return

            }

            guard let data else {

                completion(
                    .failure(
                        URLError(.badServerResponse)
                    )
                )

                return

            }

            completion(.success(data))

        }
        .resume()

    }

}
