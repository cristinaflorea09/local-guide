import Foundation

struct StripePayout: Identifiable, Codable {
    let id: String
    let amount: Int
    let currency: String
    let arrivalDate: Date
    let status: String

    var amountMajor: Double { Double(amount) / 100.0 }
}
