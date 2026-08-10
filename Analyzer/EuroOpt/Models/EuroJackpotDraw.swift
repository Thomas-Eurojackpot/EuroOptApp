import Foundation

struct EuroJackpotDraw: Identifiable, Codable {

    let id = UUID()

    let date: Date

    let numbers: [Int]

    let euroNumbers: [Int]

}
