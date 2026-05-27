import Foundation

enum AppConstants {
    enum Keychain {
        static let apiKey = "rebrickable_api_key"
        static let userToken = "rebrickable_user_token"
    }

    enum UserDefaultsKeys {
        static let syncSetsToRebrickable = "syncSetsToRebrickable"
        static let hasVerifiedAPIKey = "hasVerifiedAPIKey"
    }

    enum Support {
        static let feedbackEmail = "hello@oliverbarwell.com"
        static let rebrickableAPIURL = "https://rebrickable.com/api/"
        static let exampleSetNumber = "60272"
    }

    enum IAP {
        static let proProductID = "com.oliverbarwell.BrickCheck.pro"
        static let freeTierSetLimit = 5
    }
}
