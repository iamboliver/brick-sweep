import Foundation
import Testing

@testable import BrickSweep

@Suite("Color Mapping Service Tests")
struct ColorMappingServiceTests {
    @Test("Returns stored value when available")
    func storedValue() async throws {
        let service = ColorMappingService()
        let result = await service.brickLinkColorId(for: 1, stored: 7)
        #expect(result == 7)
    }

    @Test("Returns nil when no mapping available and no API")
    func noMapping() async throws {
        let service = ColorMappingService()
        let result = await service.brickLinkColorId(for: 99999, stored: nil)
        // Will either find it in static mapping or return nil
        // 99999 shouldn't exist in static mapping
        #expect(result == nil)
    }
}
