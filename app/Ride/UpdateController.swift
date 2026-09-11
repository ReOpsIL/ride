final class UpdateController {
    static let placeholderPublicKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    static func isConfigured(publicKey: String) -> Bool {
        !publicKey.isEmpty && publicKey != placeholderPublicKey
    }

    let isConfigured: Bool
    private let check: (() -> Void)?

    init(publicKey: String, check: (() -> Void)? = nil) {
        isConfigured = Self.isConfigured(publicKey: publicKey)
        self.check = isConfigured ? check : nil
    }

    func checkForUpdates() {
        check?()
    }
}
