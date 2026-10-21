import AppKit
import SwiftUI

struct RemoteFields: View {
    @ObservedObject var editor: RemoteEditor

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.m) {
            reach
            RemoteFieldRow(title: "User", help: "Login name on the remote.") {
                RemoteTextField(prompt: "dev", text: $editor.draft.user)
            }
            RemoteFieldRow(title: "Identity", help: "SSH private key on this Mac. Leave empty to use ssh-agent and `~/.ssh/config`.") {
                HStack(spacing: Tokens.Space.s) {
                    RemoteTextField(prompt: "~/.ssh/id_ed25519", text: $editor.draft.identity)
                    Button("Choose…") { chooseIdentity() }
                }
            }
            RemoteFieldRow(title: "Remote Root", help: "Absolute directory on the remote. Ride copies the project here before each build, run, or debug.") {
                RemoteTextField(prompt: "/work/project", text: $editor.draft.remoteRoot)
            }
        }
    }

    @ViewBuilder private var reach: some View {
        switch editor.draft.kind {
        case .vm:
            hostRows
        case .container:
            hostRows
            RemoteFieldRow(title: "Proxy", help: "Optional ssh `ProxyCommand`, such as `ssh -W %h:%p jumphost`.") {
                RemoteTextField(prompt: "none", text: $editor.draft.proxy)
            }
        case .pod:
            RemoteFieldRow(title: "Namespace", help: "Kubernetes namespace of the pod.") {
                RemoteTextField(prompt: "default", text: $editor.draft.namespace)
            }
            RemoteFieldRow(title: "Pod", help: "Pod name, as listed by `kubectl get pods`.") {
                RemoteTextField(prompt: "rust-dev-0", text: $editor.draft.name)
            }
            RemoteFieldRow(title: "Container", help: "Optional container inside the pod. Leave empty for the pod's default.") {
                RemoteTextField(prompt: "default", text: $editor.draft.container)
            }
        case .docker:
            RemoteFieldRow(title: "Container", help: "Name or ID of a running container, as listed by `docker ps`.") {
                RemoteTextField(prompt: "ride-rust", text: $editor.draft.name)
            }
        }
    }

    @ViewBuilder private var hostRows: some View {
        RemoteFieldRow(title: "Host", help: "Host name or IPv4 address.") {
            RemoteTextField(prompt: "build.example.com", text: $editor.draft.host)
        }
        RemoteFieldRow(title: "Port", help: "SSH port, usually 22.") {
            RemoteTextField(prompt: "22", text: port)
                .frame(width: 80)
        }
    }

    private var port: Binding<String> {
        Binding(
            get: { String(editor.draft.port) },
            set: { text in
                if let value = UInt16(text), value > 0 {
                    editor.draft.port = value
                }
            }
        )
    }

    private func chooseIdentity() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        panel.message = "Choose an SSH private key (not the .pub file)"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        editor.draft.identity = (url.path as NSString).abbreviatingWithTildeInPath
    }
}
