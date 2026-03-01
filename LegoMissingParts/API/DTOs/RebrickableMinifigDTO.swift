import Foundation

struct RebrickableMinifigDTO: Decodable, Sendable {
    let id: Int
    let setNum: String
    let setName: String
    let quantity: Int
    let setImgUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case setNum = "set_num"
        case setName = "set_name"
        case quantity
        case setImgUrl = "set_img_url"
    }
}
