import SwiftUI

/// Resolves the post for `postId` before rendering the detail screen.
///
/// The loaded window `CommunityService` keeps is capped, so a route that only
/// consulted it reported any older post as deleted — which is what an activity
/// row pointing at a months-old post would hit. The in-memory lookup still runs
/// first, so the common case costs no read.
struct CommunityPostDetailView: View {
    private enum Resolution {
        case loading
        case resolved(CommunityPost)
        case missing
        case failed
    }

    private let appState: AppState
    private let postId: CommunityPost.ID
    /// A comment to scroll to and mark on arrival, set when the push came from
    /// an activity row about that specific comment.
    private let highlightedCommentId: String?

    @State private var resolution: Resolution = .loading

    init(
        appState: AppState,
        postId: CommunityPost.ID,
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
            case let .resolved(post):
                CommunityPostDetailContentView(
                    appState: appState,
                    post: post,
                    highlightedCommentId: highlightedCommentId)
            case .missing:
                UnavailableDestinationView(reason: .postDeleted)
            case .failed:
                UnavailableDestinationView(
                    reason: .loadFailed,
                    onRetry: retry)
            }
        }
        .task(resolvePost)
    }

    private func resolvePost() async {
        guard case .loading = resolution else {
            return
        }
        if let post = appState.communityService.post(id: postId) {
            resolution = .resolved(post)
            return
        }
        do {
            guard let post = try await appState.communityService.fetchPost(id: postId) else {
                resolution = .missing
                return
            }
            resolution = .resolved(post)
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

struct CommunityPostDetailContentView: View {
    private let appState: AppState
    private let post: CommunityPost
    private let highlightedCommentId: String?

    @State private var viewModel: CommunityPostDetailViewModel

    @State private var showEditPost = false
    @State private var showDeleteConfirm = false
    @State private var showReportConfirm = false
    @State private var showBlockConfirm = false
    @State private var showOtherReasonInput = false
    @State private var otherReasonText = ""
    @State private var alreadyReported = false
    @State private var commentText = ""
    @State private var shouldScrollToLatestComment = false
    @State private var hasScrolledToHighlight = false
    @State private var showSignIn = false
    @State private var signInViewModel: SignInViewModel
    @State private var replyingTo: CommunityComment?
    @FocusState private var commentFieldFocused: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        post: CommunityPost,
        highlightedCommentId: String? = nil,
    ) {
        self.appState = appState
        self.post = post
        self.highlightedCommentId = highlightedCommentId
        _signInViewModel = State(initialValue: SignInViewModel(appState: appState))
        _viewModel = State(initialValue: CommunityPostDetailViewModel(
            appState: appState,
            post: post))
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
    private var isFollowingAuthor: Bool {
        viewModel.isFollowingAuthor
    }
    private var authorEmoji: String? {
        viewModel.authorEmoji
    }

    /// A post that quotes a link shares the link; one that is only text shares
    /// the text, since the post has no address of its own to send.
    @ViewBuilder
    private var shareLink: some View {
        if let url = currentPost.linkURL {
            ShareLink(item: url, subject: Text(currentPost.title)) {
                Image(.share)
            }
            .accessibilityLabel(Text(.commonShare))
        }
        else {
            ShareLink(item: currentPost.shareText, subject: Text(currentPost.title)) {
                Image(.share)
            }
            .accessibilityLabel(Text(.commonShare))
        }
    }

    private var currentPost: CommunityPost {
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
                    Text(currentPost.title)
                        .font(.title2.bold())
                HStack(spacing: 8) {
                    NavigationLink(
                        value: CommunityTabDestination.userProfile(
                            userId: currentPost.authorId)) {
                        HStack(spacing: 4) {
                            if let authorEmoji {
                                Text(authorEmoji)
                            }
                            Text(currentPost.authorName)
                                .font(.dsLabel)
                                .underline()
                        }
                    }
                    .buttonStyle(.plain)

                    if !isAuthor,
                       currentUserId != nil {
                        Button(action: toggleFollow) {
                            Text(isFollowingAuthor ? .communityFollowing : .communityFollow)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background {
                                    isFollowingAuthor
                                        ? DSColor.accent
                                        : DSColor.surface
                                }
                                .foregroundStyle(
                                    isFollowingAuthor
                                        ? DSColor.onAccent
                                        : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(currentPost.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !currentPost.topics.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(currentPost.topics) { topic in
                            Label {
                                Text(topic.title)
                            } icon: {
                                Image(systemName: topic.symbolName)
                            }
                            .font(.dsTag)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                DSColor.surface
                            }
                            .clipShape(Capsule())
                        }
                    }
                }

                if !currentPost.description.isEmpty {
                    Divider()
                    Text(currentPost.description)
                        .font(.body)
                }

                if currentPost.hasLink {
                    Divider()
                    NavigationLink(value: CommunityTabDestination.postLinkDetail(currentPost.id)) {
                        HStack {
                            Label(.bookmarkOpenLink, icon: .safari)
                            Spacer()
                            Image(.chevronForward)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background {
                            DSColor.surface
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(.communityCreatedAt)
                        Text(currentPost.createdAt, style: .date)
                        Text(currentPost.createdAt, style: .time)
                    }
                    if let updatedAt = currentPost.updatedAt {
                        HStack(spacing: 4) {
                            Text(.communityUpdatedAt)
                            Text(updatedAt, style: .date)
                            Text(updatedAt, style: .time)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
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

                if isAuthor {
                    Button(
                        .communityDeletePost,
                        role: .destructive,
                        action: confirmDelete)
                        .font(.footnote)
                }
                else if currentUserId != nil {
                    HStack(spacing: 16) {
                        Button(.communityReport, action: confirmReport)
                            .disabled(alreadyReported)
                            .foregroundStyle(alreadyReported ? Color.secondary : DSColor.destructive)
                        Button(.communityBlockUser, action: confirmBlockUser)
                            .foregroundStyle(DSColor.destructive)
                    }
                    .font(.footnote)

                    if alreadyReported {
                        Text(.communityAlreadyReported)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                commentsSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable(action: refresh)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareLink
            }
            if isAuthor {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openEditPost) {
                        Image(.edit)
                    }
                    .accessibilityLabel(.communityEditPost)
                }
            }
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .alert(.communityReportReasonOtherTitle, isPresented: $showOtherReasonInput) {
            TextField(.communityReportReasonOtherPlaceholder, text: $otherReasonText)
                .keenOnChange(of: otherReasonText, perform: onOtherReasonTextChange)
            Button(
                "Cancel",
                role: .cancel) {}
            Button(.communityReport, action: submitOtherReport)
        } message: {
            Text(.communityReportReasonOtherMessage)
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
        .dialog(
            .communityReportConfirmTitle,
            isPresented: $showReportConfirm,
            buttons: communityReportConfirmDialogView)
        .dialog(
            .communityBlockConfirmTitle,
            message: .communityBlockConfirmMessage,
            isPresented: $showBlockConfirm,
            buttons: communityBlockConfirmDialogView)
        .sheet(isPresented: $showEditPost) {
            EditCommunityPostView(
                appState: appState,
                post: currentPost)
        }
        }
    }

    @ViewBuilder
    private var communityReportConfirmDialogView: some View {
        Button(.communityReportReasonSpam, action: reportSpam)
        Button(.communityReportReasonInappropriate, action: reportInappropriate)
        Button(.communityReportReasonOther, action: openOtherReasonInput)
    }

    private var communityBlockConfirmDialogView: some View {
        Button(
            .communityBlockConfirmAction,
            role: .destructive,
            action: blockUser)
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
        viewModel.markAsRead()
        viewModel.startListening()
        Task {
            alreadyReported = await viewModel.refreshAlreadyReported()
        }
    }

    private func onDisappear() {
        viewModel.stopListening()
    }

    private func dismissKeyboard() {
        commentFieldFocused = false
    }

    /// Scrolls to the comment an activity row pointed at, once the comment
    /// listener has actually delivered it. Only once — after that the user's
    /// own scroll position wins.
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

    private func refresh() async {
        await viewModel.refresh()
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

    private func toggleFollow() {
        Task {
            await viewModel.toggleFollow()
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

    private func confirmReport() {
        showReportConfirm = true
    }

    private func confirmBlockUser() {
        showBlockConfirm = true
    }

    private func openSignIn() {
        showSignIn = true
    }

    private func openEditPost() {
        showEditPost = true
    }

    private func deletePost() {
        Task {
            await viewModel.deletePost()
            dismiss()
        }
    }

    private func reportSpam() {
        submitReport(.spam)
    }

    private func reportInappropriate() {
        submitReport(.inappropriate)
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

    private func blockUser() {
        viewModel.blockAuthor()
        dismiss()
    }

    private func submitReport(_ reason: ReportReason) {
        guard currentUserId != nil else { return }
        Task {
            await viewModel.submitReport(reason)
            alreadyReported = true
        }
    }
}

