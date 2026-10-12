import AppKit
import SwiftUI

struct ReviewShotBox: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let row: ReviewRow
    @ObservedObject var review: ReviewModel
    @State private var targeting = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("Evidence")
                .font(Tokens.ui(10, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
            if let shot = review.shots[row.reviewKey], let image = NSImage(contentsOf: shot.local) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Tokens.Space.s) {
                    Text(caption(shot))
                        .font(Tokens.ui(10))
                        .foregroundStyle(ts.ui.textTertiary)
                    Spacer(minLength: Tokens.Space.xs)
                    Button("Remove") { review.removeShot(row, root: state.git.root) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove evidence")
                }
                .font(Tokens.ui(10, weight: .semibold))
                .foregroundStyle(ts.ui.accent)
                HStack(spacing: Tokens.Space.s) {
                    Button("Share") { review.shareShot(row, root: state.git.root) }
                        .disabled(shot.shared != nil)
                    Button("Keep local") { review.keepShot(row) }
                        .disabled(shot.kept || shot.shared != nil)
                }
                .buttonStyle(.plain)
                .font(Tokens.ui(10, weight: .semibold))
                .foregroundStyle(ts.ui.accent)
            } else {
                Text(targeting ? "Drop to keep it on this Mac" : "Drop a screenshot. It stays local until Share.")
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Tokens.Space.s)
                    .background(ts.ui.bgBase, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
            }
        }
        .onDrop(of: [.fileURL, .image, .png], isTargeted: $targeting) { providers in
            ReviewImages.take(providers) { data in
                if let data {
                    review.storeShot(row, data: data)
                }
            }
        }
    }

    private func caption(_ shot: ReviewShot) -> String {
        if let shared = shot.shared {
            return shared
        }
        return shot.kept ? "Stays on this Mac" : "Local until shared · over 2 MB is refused"
    }
}
