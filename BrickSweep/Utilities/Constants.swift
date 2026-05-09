import Foundation

enum AppConstants {
    enum Keychain {
        static let apiKey = "rebrickable_api_key"
        static let userToken = "rebrickable_user_token"
    }

    enum UserDefaultsKeys {
        static let syncSetsToRebrickable = "syncSetsToRebrickable"
    }

    enum IAP {
        static let proProductID = "com.oliverbarwell.BrickCheck.pro"
        static let freeTierSetLimit = 5
    }
}
