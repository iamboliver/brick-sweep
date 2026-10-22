import Foundation

struct RebrickableThemeDTO: Decodable, Sendable {
    let id: Int
    let parentId: Int?
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
    }
}
