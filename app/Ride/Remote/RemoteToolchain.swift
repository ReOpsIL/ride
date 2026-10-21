import Foundation

enum RemoteKind: String, Codable, Equatable, CaseIterable {
    case vm
    case container
    case pod
    case docker

    var title: String {
        switch self {
        case .vm: "VM"
        case .container: "Container"
        case .pod: "Pod"
        case .docker: "Local Docker"
        }
    }
}

struct RemoteToolchain: Codable, Equatable {
    var enabled: Bool
    var kind: RemoteKind
    var user: String
    var host: String
    var port: UInt16
    var identity: String
    var proxy: String
    var remoteRoot: String
    var name: String
    var namespace: String
    var container: String
    var localRoot: String

    static let off = RemoteToolchain(
        enabled: false,
        kind: .vm,
        user: "",
        host: "",
        port: 22,
        identity: "",
        proxy: "",
        remoteRoot: "",
        name: "",
        namespace: "",
        container: "",
        localRoot: ""
    )
}
