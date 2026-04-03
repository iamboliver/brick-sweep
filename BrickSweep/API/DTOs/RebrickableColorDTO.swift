import Foundation

struct RebrickableColorDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let rgb: String
    let externalIds: RebrickableSetPartDTO.ExternalColorIds?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case rgb
        case externalIds = "external_ids"
    }
}
