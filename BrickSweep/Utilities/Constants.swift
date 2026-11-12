import Foundation

enum AppConstants {
    static let lastFoundingBuild = 6
    enum Keychain {
        static let apiKey = "rebrickable_api_key"
        static let userToken = "rebrickable_user_token"
    }

    enum UserDefaultsKeys {
        static let verifiedFoundingUser = "verifiedFoundingUser"
        static let syncSetsToRebrickable = "syncSetsToRebrickable"
        static let hasVerifiedAPIKey = "hasVerifiedAPIKey"
        static let whatsNewLastSeenVersion = "whatsNewLastSeenVersion"
    }

    enum Support {
        static let feedbackEmail = "hello@bricksweep.app"
        static let privacyPolicyURL = "https://oliverbarwell.com/bricksweep/privacy"
        static let rebrickableAPIURL = "https://rebrickable.com/api/"
        static let exampleSetNumber = "60272"
    }

    /// Sent on requests to BrickSweep's data files and Rebrickable, so the version is the real one.
    static var userAgent: String {
        userAgent(version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
    }

    static func userAgent(version: String?) -> String {
        guard let version, !version.isEmpty else { return "BrickSweep" }
        return "BrickSweep/\(version)"
    }

    enum IAP {
        static let proProductID = "com.oliverbarwell.BrickCheck.pro"
        static let freeTierSetLimit = 5
    }
}
