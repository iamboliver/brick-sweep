import Foundation

struct RebrickableSetDTO: Decodable, Sendable {
    let setNum: String
    let name: String
    let year: Int
    let numParts: Int
    let setImgUrl: String?

    enum CodingKeys: String, CodingKey {
        case setNum = "set_num"
        case name
        case year
        case numParts = "num_parts"
        case setImgUrl = "set_img_url"
    }
}
