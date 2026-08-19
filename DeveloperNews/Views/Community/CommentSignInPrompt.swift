import SwiftUI

/// Stands in for the comment box when nobody is signed in.
///
/// The box used to be omitted outright, which left the reader with a thread
/// they could not join and no indication of why, or of what to do about it.
/// Sits in the same place the box would, so the way in is where the reader is
/// already looking.
struct CommentSignInPrompt: View {
    private let onSignIn: () -> Void

    init(onSignIn: @escaping () -> Void) {
        self.onSignIn = onSignIn
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Text(.commentSignInPrompt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onSignIn) {
                    Text(.commentSignInAction)
                        .font(.dsButton)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background {
            DSColor.background
        }
    }
}
