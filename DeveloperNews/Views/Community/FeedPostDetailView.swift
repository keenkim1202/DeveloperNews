import SwiftUI

/// Resolves the post for `postId` on appear rather than carrying it on the
/// navigation stack, so a push always renders the current document.
/// `FeedPostServicing.post(id:)` is async and the destination builder is not,
/// so the read happens here and the body only renders once it has an answer.
struct FeedPostDetailView: View {
    private enum Resolution {
        case loading
        case resolved(FeedPostDetailViewModel)
        case missing
        case failed
    }

    private let appState: AppState
    private let postId: FeedPost.ID
    /// A comment to scroll to and mark on arrival, set when the push came from
    /// an activity row about that specific comment.
    private let highlightedCommentId: String?

    @State private var resolution: Resolution = .loading

    init(
        appState: AppState,
        postId: FeedPost.ID,
        highlightedCommentId: String? = nil,
    ) {
        self.appState = appState
        self.postId = postId
        self.highlightedCommentId = highlightedCommentId
    }

    var body: some View {
        Group {
            switch resolution {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .resolved(viewModel):
                FeedPostDetailContentView(
                    appState: appState,
                    viewModel: viewModel,
                    highlightedCommentId: highlightedCommentId)
            case .missing:
                UnavailableDestinationView(reason: .postDeleted)
            case .failed:
                UnavailableDestinationView(
                    reason: .loadFailed,
                    onRetry: retry)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(resolvePost)
    }

    private func resolvePost() async {
        guard case .loading = resolution else {
            return
        }
        do {
            guard let post = try await appState.feedPostService.post(id: postId) else {
                resolution = .missing
                return
            }
            resolution = .resolved(FeedPostDetailViewModel(
                appState: appState,
                post: post))
        }
        catch {
            // A failed read is not a deleted post. Saying so would be a lie the
            // reader cannot check, and it hides a condition that retrying fixes.
            resolution = .failed
        }
    }

    private func retry() {
        resolution = .loading
        Task {
            await resolvePost()
        }
    }
}

private struct FeedPostDetailContentView: View {
    private let appState: AppState
    private let viewModel: FeedPostDetailViewModel
    private let highlightedCommentId: String?

    @State private var showReportConfirm = false
    @State private var showBlockConfirm = false
    @State private var showOtherReasonInput = false
    @State private var otherReasonText = ""
    @State private var pendingReason: ReportReason?
    @State private var commentText = ""
    @State private var shouldScrollToLatestComment = false
    @State private var hasScrolledToHighlight = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var replyingTo: CommunityComment?
    @FocusState private var commentFieldFocused: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var signInViewModel: SignInViewModel
    @State private var showSignIn = false

    init(
        appState: AppState,
        viewModel: FeedPostDetailViewModel,
        highlightedCommentId: String?,
    ) {
        self.appState = appState
        self.viewModel = viewModel
        self.highlightedCommentId = highlightedCommentId
        _signInViewModel = State(initialValue: SignInViewModel(appState: appState))
    }

    private func openSignIn() {
        showSignIn = true
    }

    private var currentUserId: String? {
        viewModel.currentUserId
    }
    private var isAuthor: Bool {
        viewModel.isAuthor
    }
    private var isLiked: Bool {
        viewModel.isLiked
    }
    private var currentPost: FeedPost {
        viewModel.currentPost
    }
    private var visibleComments: [CommunityComment] {
        viewModel.visibleComments
    }
    private var commentThreads: [CommentThread] {
        viewModel.commentThreads
    }
    private var canSubmitComment: Bool {
        viewModel.canSubmitComment(commentText: commentText)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    postHeader
                    if !currentPost.comment.isEmpty {
                        Text(currentPost.comment)
                            .font(.body)
                    }
                    storyCard
                    engagementBar
                    Divider()
                    commentsSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(TapGesture().onEnded(dismissKeyboard))
            .keenOnChange(of: visibleComments.count) {
                scrollToLatestComment(proxy)
                scrollToHighlightedComment(proxy)
            }
            .safeAreaInset(edge: .bottom) {
                if currentUserId != nil {
                    CommentInputBar(
                        text: $commentText,
                        errorMessage: viewModel.commentErrorMessage,
                        canSubmit: canSubmitComment,
                        isFocused: $commentFieldFocused,
                        onSubmit: submitComment,
                        replyingToName: replyingTo?.authorName,
                        onCancelReply: cancelReply)
                }
                else {
                    CommentSignInPrompt(onSignIn: openSignIn)
                }
            }
            .sheet(isPresented: $showSignIn) {
                SignInView(appState: appState, viewModel: signInViewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    shareLink
                }
                if currentUserId != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        if isAuthor {
                            authorMenu
                        }
                        else {
                            moderationMenu
                        }
                    }
                }
            }
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
            .sheet(isPresented: $showEditSheet) {
                FeedPostEditView(
                    originalComment: currentPost.comment,
                    onSave: saveEdit)
            }
            .alert(.communityReportReasonOtherTitle, isPresented: $showOtherReasonInput) {
                TextField(.communityReportReasonOtherPlaceholder, text: $otherReasonText)
                    .keenOnChange(of: otherReasonText, perform: onOtherReasonTextChange)
                Button("Cancel", role: .cancel) {}
                Button(.communityReport, action: submitOtherReport)
            } message: {
                Text(.communityReportReasonOtherMessage)
            }
            .alert(
                .communityReportConfirmTitle,
                isPresented: $showReportConfirm) {
                Button("Cancel", role: .cancel) {}
                Button(
                    .communityReport,
                    role: .destructive,
                    action: submitPendingReport)
            }
            .alert(
                .communityDeleteConfirm,
                isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button(
                    "Delete",
                    role: .destructive,
                    action: deletePost)
            }
            .alert(
                .communityBlockConfirmTitle,
                isPresented: $showBlockConfirm) {
                Button("Cancel", role: .cancel) {}
                Button(
                    .communityBlockConfirmAction,
                    role: .destructive,
                    action: blockUser)
            } message: {
                Text(.communityBlockConfirmMessage)
            }
        }
    }

    /// Shares the story the post is about rather than the post itself: there is
    /// no web address for a post, and the article is what a recipient can open.
    @ViewBuilder
    private var shareLink: some View {
        if let url = currentPost.story.storyURL {
            ShareLink(item: url, subject: Text(currentPost.story.title)) {
                Image(.share)
            }
            .accessibilityLabel(Text(.commonShare))
        }
    }

    private var authorMenu: some View {
        Menu {
            Button(.communityEditPost, action: openEdit)
            Button(
                .communityDeletePost,
                role: .destructive,
                action: confirmDelete)
        } label: {
            Image(.more)
        }
        .accessibilityLabel(Text(.communityMoreActions))
    }

    private var moderationMenu: some View {
        Menu {
            Menu {
                Button(.communityReportReasonSpam, action: reportSpam)
                Button(.communityReportReasonInappropriate, action: reportInappropriate)
                Button(.communityReportReasonOther, action: openOtherReasonInput)
            } label: {
                Label(.communityReport, systemImage: "exclamationmark.bubble")
            }
            Button(
                .communityBlockUser,
                role: .destructive,
                action: confirmBlockUser)
        } label: {
            Image(.more)
        }
        .accessibilityLabel(Text(.communityMoreActions))
    }

    private var postHeader: some View {
        HStack(spacing: 8) {
            NavigationLink(
                value: CommunityTabDestination.userProfile(
                    userId: currentPost.authorId)) {
                HStack(spacing: 4) {
                    if let emoji = currentPost.authorEmoji {
                        Text(emoji)
                    }
                    Text(currentPost.authorName)
                        .font(.dsLabel)
                        .underline()
                }
            }
            .buttonStyle(.plain)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(currentPost.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var storyCard: some View {
        NavigationLink(value: CommunityTabDestination.storyDetail(currentPost.story)) {
            HStack(alignment: .top, spacing: 12) {
                if let thumbnailURL = currentPost.story.thumbnailURL.flatMap(URL.init(string:)) {
                    StoryCardThumbnail(url: thumbnailURL)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentPost.story.title)
                        .font(.dsCardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                    Text(currentPost.story.sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background {
                DSColor.surface
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var engagementBar: some View {
        HStack(spacing: 16) {
            Button(action: toggleLike) {
                HStack(spacing: 4) {
                    Image(isLiked ? .likeFilled : .like)
                        .foregroundStyle(isLiked ? .red : .secondary)
                    Text("\(currentPost.likeCount)")
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)
            .disabled(currentUserId == nil)
            HStack(spacing: 4) {
                Image(.comment)
                Text("\(currentPost.commentCount)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Spacer()
        }
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
                ForEach(commentThreads) { thread in
                    CommentRow(
                        comment: thread.parent,
                        currentUserId: currentUserId,
                        onDelete: { deleteComment(thread.parent) },
                        onReport: { reportComment(thread.parent, reason: $0) },
                        onBlock: { blockCommentAuthor(thread.parent) },
                        onLike: currentUserId == nil ? nil : { likeComment(thread.parent) },
                        onReply: currentUserId == nil ? nil : { startReply(thread.parent) },
                        isHighlighted: thread.parent.id == highlightedCommentId)
                        .id(thread.parent.id)
                    ForEach(thread.replies) { reply in
                        CommentRow(
                            comment: reply,
                            currentUserId: currentUserId,
                            onDelete: { deleteComment(reply) },
                            onReport: { reportComment(reply, reason: $0) },
                            onBlock: { blockCommentAuthor(reply) },
                            onLike: currentUserId == nil ? nil : { likeComment(reply) },
                            isHighlighted: reply.id == highlightedCommentId)
                            .padding(.leading, 32)
                            .id(reply.id)
                    }
                }
            }
        }
    }

    private func onAppear() {
        viewModel.startListening()
    }

    private func onDisappear() {
        viewModel.stopListening()
    }

    private func dismissKeyboard() {
        commentFieldFocused = false
    }

    /// Scrolls to the comment an activity row pointed at, once the comment
    /// listener has actually delivered it. Runs on the same comment-count
    /// change as the latest-comment scroll because that is when the rows the
    /// proxy can reach come into existence, and only once — after that the
    /// user's own position wins.
    private func scrollToHighlightedComment(_ proxy: ScrollViewProxy) {
        guard let highlightedCommentId,
              !hasScrolledToHighlight,
              visibleComments.contains(where: { $0.id == highlightedCommentId })
        else { return }
        hasScrolledToHighlight = true
        withAnimation {
            proxy.scrollTo(highlightedCommentId, anchor: .center)
        }
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
        let parentCommentId = replyingTo?.id
        commentText = ""
        replyingTo = nil
        shouldScrollToLatestComment = true
        Task {
            await viewModel.addComment(text: trimmed, parentCommentId: parentCommentId)
        }
    }

    private func startReply(_ comment: CommunityComment) {
        replyingTo = comment
        commentFieldFocused = true
    }

    private func cancelReply() {
        replyingTo = nil
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

    private func likeComment(_ comment: CommunityComment) {
        Task {
            await viewModel.toggleCommentLike(comment)
        }
    }

    private func onOtherReasonTextChange(_ new: String) {
        if new.count > 200 {
            otherReasonText = String(new.prefix(200))
        }
    }

    private func toggleLike() {
        Task {
            await viewModel.toggleLike()
        }
    }

    private func confirmDelete() {
        showDeleteConfirm = true
    }

    private func deletePost() {
        Task {
            if await viewModel.deletePost() {
                dismiss()
            }
        }
    }

    private func openEdit() {
        showEditSheet = true
    }

    private func saveEdit(_ text: String) {
        Task {
            await viewModel.updateComment(text)
        }
    }

    private func confirmBlockUser() {
        showBlockConfirm = true
    }

    private func reportSpam() {
        confirmReport(.spam)
    }

    private func reportInappropriate() {
        confirmReport(.inappropriate)
    }

    private func openOtherReasonInput() {
        otherReasonText = ""
        showOtherReasonInput = true
    }

    private func submitOtherReport() {
        let trimmed = otherReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submitReport(.other(trimmed))
    }

    private func confirmReport(_ reason: ReportReason) {
        pendingReason = reason
        showReportConfirm = true
    }

    private func submitPendingReport() {
        guard let reason = pendingReason else { return }
        pendingReason = nil
        submitReport(reason)
    }

    private func blockUser() {
        viewModel.blockAuthor()
        dismiss()
    }

    private func submitReport(_ reason: ReportReason) {
        guard currentUserId != nil else { return }
        Task {
            await viewModel.submitReport(reason)
        }
    }
}

private struct StoryCardThumbnail: View {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                DSColor.fill
                    .overlay {
                        Image(.photo)
                            .foregroundStyle(.secondary)
                    }
            case .empty:
                DSColor.fill
                    .overlay {
                        ProgressView().controlSize(.small)
                    }
            @unknown default:
                DSColor.fill
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
