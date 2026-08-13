import SwiftUI

struct FeedPostDetailView: View {
    private let appState: AppState

    @State private var viewModel: FeedPostDetailViewModel

    @State private var showReportConfirm = false
    @State private var showBlockConfirm = false
    @State private var showOtherReasonInput = false
    @State private var otherReasonText = ""
    @State private var pendingReason: ReportReason?
    @State private var commentText = ""
    @State private var shouldScrollToLatestComment = false
    @State private var showEditSheet = false
    @State private var replyingTo: CommunityComment?
    @FocusState private var commentFieldFocused: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        post: FeedPost,
    ) {
        self.appState = appState
        _viewModel = State(initialValue: FeedPostDetailViewModel(
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
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

    private var authorMenu: some View {
        Menu {
            Button(.communityEditPost, action: openEdit)
        } label: {
            Image(.more)
        }
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
                        onReply: currentUserId == nil ? nil : { startReply(thread.parent) })
                        .id(thread.parent.id)
                    ForEach(thread.replies) { reply in
                        CommentRow(
                            comment: reply,
                            currentUserId: currentUserId,
                            onDelete: { deleteComment(reply) },
                            onReport: { reportComment(reply, reason: $0) },
                            onBlock: { blockCommentAuthor(reply) },
                            onLike: currentUserId == nil ? nil : { likeComment(reply) })
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
