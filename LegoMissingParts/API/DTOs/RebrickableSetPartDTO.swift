import Foundation

struct RebrickableSetPartDTO: Decodable, Sendable {
    let id: Int
    let quantity: Int
    let isSpare: Bool
    let elementId: String?
    let part: PartInfo
    let color: ColorInfo

    enum CodingKeys: String, CodingKey {
        case id
        case quantity
        case isSpare = "is_spare"
        case elementId = "element_id"
        case part
        case color
    }

    struct PartInfo: Decodable, Sendable {
        let partNum: String
        let name: String
        let partImgUrl: String?
        let externalIds: ExternalPartIds?

        enum CodingKeys: String, CodingKey {
            case partNum = "part_num"
            case name
            case partImgUrl = "part_img_url"
            case externalIds = "external_ids"
        }
    }

    struct ColorInfo: Decodable, Sendable {
        let id: Int
        let name: String
        let rgb: String
        let externalIds: ExternalColorIds?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case rgb
            case externalIds = "external_ids"
        }
    }

    struct ExternalPartIds: Decodable, Sendable {
        let brickLink: [String]?

        enum CodingKeys: String, CodingKey {
            case brickLink = "BrickLink"
        }
    }

    struct ExternalColorIds: Decodable, Sendable {
        let brickLink: BrickLinkColorEntry?

        enum CodingKeys: String, CodingKey {
            case brickLink = "BrickLink"
        }
    }

    struct BrickLinkColorEntry: Decodable, Sendable {
        let extIds: [Int]?
        let extDescrs: [[String]]?

        enum CodingKeys: String, CodingKey {
            case extIds = "ext_ids"
            case extDescrs = "ext_descrs"
        }
    }
}
