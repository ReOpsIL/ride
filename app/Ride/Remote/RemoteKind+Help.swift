import Foundation

extension RemoteKind {
    var summary: String {
        switch self {
        case .vm:
            "A machine running sshd that this Mac can reach directly."
        case .container:
            "A container whose SSH port is published, such as `-p 2222:22`. Add a proxy command when it is only reachable through another host."
        case .pod:
            "A Kubernetes pod running sshd. Ride tunnels SSH through `kubectl exec` and `nc`, so no port is exposed."
        case .docker:
            "A running container on this Mac's Docker. Ride tunnels SSH through `docker exec` and `nc`; the container must run sshd. `scripts/remote-docker/up.sh` builds one."
        }
    }
}
