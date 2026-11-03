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
        static let feedbackEmail = "hello@oliverbarwell.com"
        static let privacyPolicyURL = "https://oliverbarwell.com/bricksweep/privacy"
        static let rebrickableAPIURL = "https://rebrickable.com/api/"
        static let exampleSetNumber = "60272"
    }

    enum IAP {
        static let proProductID = "com.oliverbarwell.BrickCheck.pro"
        static let freeTierSetLimit = 5
    }
}
