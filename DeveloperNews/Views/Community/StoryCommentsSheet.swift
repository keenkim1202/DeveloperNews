import SwiftUI

// Comments bottom sheet for the article detail screen. It shares the live
// StoryEngagementViewModel with ArticleDetailView so the comment listener and
// counts stay in sync without spinning up a second listener.
struct StoryCommentsSheet: View {
    private var viewModel: StoryEngagementViewModel

    @State private var commentText = ""
    @State private var shouldScrollToLatestComment = false
    @FocusState private var commentFieldFocused: Bool

    @Environment(\.dismiss) private var dismiss

    init(viewModel: StoryEngagementViewModel) {
        self.viewModel = viewModel
    }

    private var currentUserId: String? {
        viewModel.currentUserId
    }

    private var visibleComments: [CommunityComment] {
        viewModel.visibleComments
    }

    private var canSubmitComment: Bool {
        viewModel.canSubmitComment(commentText: commentText)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    commentsSection
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(TapGesture().onEnded(dismissKeyboard))
                .keenOnChange(of: visibleComments.count) {
                    scrollToLatestComment(proxy)
                }
                .safeAreaInset(edge: .bottom) {
                    if currentUserId != nil {
                        CommentInputBar(
                            text: $commentText,
                            errorMessage: viewModel.commentErrorMessage,
                            canSubmit: canSubmitComment,
                            isFocused: $commentFieldFocused,
                            onSubmit: submitComment)
                    }
                }
                .navigationTitle(Text(.communityComments))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done", action: close)
                    }
                }
            }
        }
        // A single large detent keeps the sheet from resizing when the keyboard
        // appears, so the comment input tracks the keyboard smoothly (the pushed
        // post detail screen behaves this way). A medium detent would fight the
        // keyboard animation as the sheet grows to fit it.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.communityComments)
                .font(.headline)

            if visibleComments.isEmpty {
                Text(.communityCommentsEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            else {
                ForEach(visibleComments) { comment in
                    CommentRow(
                        comment: comment,
                        currentUserId: currentUserId,
                        onDelete: { deleteComment(comment) },
                        onReport: { reportComment(comment, reason: $0) },
                        onBlock: { blockCommentAuthor(comment) })
                        .id(comment.id)
                }
            }
        }
    }

    private func close() {
        dismiss()
    }

    private func dismissKeyboard() {
        commentFieldFocused = false
    }

    private func scrollToLatestComment(_ proxy: ScrollViewProxy) {
        guard shouldScrollToLatestComment,
              let lastId = visibleComments.last?.id
        else { return }
        shouldScrollToLatestComment = false
        withAnimation {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private func submitComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              viewModel.hasAuthenticatedUser
        else { return }
        commentText = ""
        shouldScrollToLatestComment = true
        Task {
            await viewModel.addComment(text: trimmed)
        }
    }

    private func deleteComment(_ comment: CommunityComment) {
        Task {
            await viewModel.deleteComment(comment)
        }
    }

    private func reportComment(
        _ comment: CommunityComment,
        reason: ReportReason,
    ) {
        Task {
            await viewModel.reportComment(comment, reason: reason)
        }
    }

    private func blockCommentAuthor(_ comment: CommunityComment) {
        viewModel.blockCommentAuthor(comment)
    }
}
