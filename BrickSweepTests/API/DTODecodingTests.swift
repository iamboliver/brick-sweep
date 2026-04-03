import Foundation
import Testing

@testable import BrickSweep

@Suite("DTO Decoding Tests")
struct DTODecodingTests {
    @Test("Decode RebrickableSetDTO")
    func decodeSet() throws {
        let json = """
        {
            "set_num": "75192-1",
            "name": "Millennium Falcon",
            "year": 2017,
            "theme_id": 158,
            "num_parts": 7541,
            "set_img_url": "https://cdn.rebrickable.com/media/sets/75192-1.jpg",
            "set_url": "https://rebrickable.com/sets/75192-1/millennium-falcon/",
            "last_modified_dt": "2023-01-01T00:00:00.000000Z"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RebrickableSetDTO.self, from: json)
        #expect(dto.setNum == "75192-1")
        #expect(dto.name == "Millennium Falcon")
        #expect(dto.year == 2017)
        #expect(dto.numParts == 7541)
        #expect(dto.setImgUrl == "https://cdn.rebrickable.com/media/sets/75192-1.jpg")
    }

    @Test("Decode PaginatedResponse of sets")
    func decodePaginatedResponse() throws {
        let json = """
        {
            "count": 1,
            "next": null,
            "previous": null,
            "results": [
                {
                    "set_num": "10281-1",
                    "name": "Bonsai Tree",
                    "year": 2021,
                    "theme_id": 674,
                    "num_parts": 878,
                    "set_img_url": "https://cdn.rebrickable.com/media/sets/10281-1.jpg",
                    "set_url": "https://rebrickable.com/sets/10281-1/bonsai-tree/",
                    "last_modified_dt": "2023-01-01T00:00:00.000000Z"
                }
            ]
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder().decode(PaginatedResponse<RebrickableSetDTO>.self, from: json)
        #expect(page.count == 1)
        #expect(page.next == nil)
        #expect(page.results.count == 1)
        #expect(page.results[0].name == "Bonsai Tree")
    }

    @Test("Decode RebrickableSetPartDTO with external IDs")
    func decodeSetPart() throws {
        let json = """
        {
            "id": 123456,
            "inv_part_id": 789,
            "part": {
                "part_num": "3001",
                "name": "Brick 2 x 4",
                "part_cat_id": 11,
                "part_url": "https://rebrickable.com/parts/3001/",
                "part_img_url": "https://cdn.rebrickable.com/media/parts/3001.png",
                "external_ids": {
                    "BrickLink": ["3001"],
                    "BrickOwl": ["3001-2"]
                },
                "print_of": null
            },
            "color": {
                "id": 1,
                "name": "Blue",
                "rgb": "0055BF",
                "is_trans": false,
                "external_ids": {
                    "BrickLink": {
                        "ext_ids": [7],
                        "ext_descrs": [["Blue"]]
                    },
                    "LEGO": {
                        "ext_ids": [23],
                        "ext_descrs": [["Bright Blue"]]
                    }
                }
            },
            "quantity": 4,
            "is_spare": false,
            "element_id": "300123",
            "num_sets": 500
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RebrickableSetPartDTO.self, from: json)
        #expect(dto.id == 123456)
        #expect(dto.quantity == 4)
        #expect(dto.isSpare == false)
        #expect(dto.part.partNum == "3001")
        #expect(dto.part.name == "Brick 2 x 4")
        #expect(dto.part.externalIds?.brickLink?.first == "3001")
        #expect(dto.color.id == 1)
        #expect(dto.color.name == "Blue")
        #expect(dto.color.rgb == "0055BF")
        #expect(dto.color.externalIds?.brickLink?.extIds?.first == 7)
        #expect(dto.elementId == "300123")
    }

    @Test("Decode RebrickableSetPartDTO without external IDs")
    func decodeSetPartWithoutExternalIds() throws {
        let json = """
        {
            "id": 999,
            "inv_part_id": 111,
            "part": {
                "part_num": "99999",
                "name": "Custom Part",
                "part_cat_id": 1,
                "part_url": "https://rebrickable.com/parts/99999/",
                "part_img_url": null,
                "external_ids": {},
                "print_of": null
            },
            "color": {
                "id": 0,
                "name": "Black",
                "rgb": "05131D",
                "is_trans": false,
                "external_ids": {}
            },
            "quantity": 1,
            "is_spare": true,
            "element_id": null,
            "num_sets": 1
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RebrickableSetPartDTO.self, from: json)
        #expect(dto.id == 999)
        #expect(dto.isSpare == true)
        #expect(dto.part.partImgUrl == nil)
        #expect(dto.part.externalIds?.brickLink == nil)
        #expect(dto.color.externalIds?.brickLink == nil)
        #expect(dto.elementId == nil)
    }
}
