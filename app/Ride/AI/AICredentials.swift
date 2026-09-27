import Foundation

enum AICredentials {
    static func key(_ account: String) -> String? {
        DemoLaunch.isDemo ? nil : Keychain.read(account)
    }
}
