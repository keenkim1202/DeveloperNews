import SwiftUI

// Shared comment composer bar. The post comment UI is the canonical design, so
// the feed post, community post, and story comment screens all render this.
struct CommentInputBar: View {
    private var text: Binding<String>
    private let errorMessage: String?
    private let canSubmit: Bool
    private var isFocused: FocusState<Bool>.Binding
    private let onSubmit: () -> Void
    private let replyingToName: String?
    private let onCancelReply: (() -> Void)?

    init(
        text: Binding<String>,
        errorMessage: String?,
        canSubmit: Bool,
        isFocused: FocusState<Bool>.Binding,
        onSubmit: @escaping () -> Void,
        replyingToName: String? = nil,
        onCancelReply: (() -> Void)? = nil,
    ) {
        self.text = text
        self.errorMessage = errorMessage
        self.canSubmit = canSubmit
        self.isFocused = isFocused
        self.onSubmit = onSubmit
        self.replyingToName = replyingToName
        self.onCancelReply = onCancelReply
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if let replyingToName {
                replyContextHeader(replyingToName)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(DSColor.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    .communityCommentPlaceholder,
                    text: text,
                    axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused(isFocused)
                Button(action: onSubmit) {
                    Image(.sendFilled)
                        .font(.title2)
                }
                .disabled(!canSubmit)
                .accessibilityLabel(.communityCommentSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background {
            // Extend the background into the bottom container safe area so the
            // bar reads as one solid surface while it tracks the keyboard,
            // instead of tearing against the home-indicator strip beneath it.
            DSColor.background
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private func replyContextHeader(_ name: String) -> some View {
        HStack(spacing: 8) {
            Text(.communityReplyingTo(name))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button(action: cancelReply) {
                Image(.close)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func cancelReply() {
        onCancelReply?()
    }
}
