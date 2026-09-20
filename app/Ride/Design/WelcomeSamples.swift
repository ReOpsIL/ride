import SwiftUI

struct WelcomeSamples: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @State private var error: String?

    private var samples: [SampleProject] { SampleProjects.available }

    @ViewBuilder
    var body: some View {
        if !samples.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Try a sample project")
                    .font(Tokens.ui(11, weight: .semibold))
                    .foregroundStyle(ts.ui.textTertiary)
                HStack(spacing: Tokens.Space.s) {
                    ForEach(samples) { sample in
                        Button(sample.title) { copy(sample) }
                            .controlSize(.small)
                            .help(sample.summary)
                    }
                }
                if let error {
                    Text(error)
                        .font(Tokens.ui(11))
                        .foregroundStyle(ts.ui.error)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func copy(_ sample: SampleProject) {
        guard let destination = state.chooseSampleDestination(for: sample) else {
            return
        }
        error = state.openSample(sample, at: destination)
    }
}
