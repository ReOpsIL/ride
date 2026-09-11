import Foundation
import Sparkle

extension UpdateController {
    convenience init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        if Self.isConfigured(publicKey: key) {
            let controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            self.init(publicKey: key, check: { controller.checkForUpdates(nil) })
        } else {
            self.init(publicKey: key)
        }
    }
}
