import Testing

@testable import BrickSweep

@Suite("User-Agent Tests")
struct UserAgentTests {
    @Test("Carries the app version")
    func includesVersion() {
        #expect(AppConstants.userAgent(version: "1.1") == "BrickSweep/1.1")
    }

    @Test("Drops the version when there isn't one")
    func withoutVersion() {
        #expect(AppConstants.userAgent(version: nil) == "BrickSweep")
        #expect(AppConstants.userAgent(version: "") == "BrickSweep")
    }

    @Test("The shipped value uses the bundle's version")
    func shippedValue() {
        #expect(AppConstants.userAgent.hasPrefix("BrickSweep"))
        #expect(AppConstants.userAgent != "BrickSweep/1.0")
    }
}
