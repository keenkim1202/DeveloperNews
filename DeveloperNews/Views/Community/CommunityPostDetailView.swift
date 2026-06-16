import SwiftUI

struct CommunityPostDetailView: View {
    private let appState: AppState
    private let post: CommunityPost

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
    @State private var commentPendingDeletion: CommunityComment?
    @State private var showDeleteCommentConfirm = false
    @FocusState private var commentFieldFocused: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        post: CommunityPost,
    ) {
        self.appState = appState
        self.post = post
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

    private var currentPost: CommunityPost {
        viewModel.currentPost
    }

    private var visibleComments: [CommunityComment] {
        viewModel.visibleComments
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
                            AuthorInfo(
                                id: currentPost.authorId,
                                name: currentPost.authorName,
                                emoji: authorEmoji))) {
                        HStack(spacing: 4) {
                            if let authorEmoji {
                                Text(authorEmoji)
                            }
                            Text(currentPost.authorName)
                                .font(.caption.weight(.semibold))
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
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                }
                                .foregroundStyle(
                                    isFollowingAuthor
                                        ? Color.white
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
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Color(.secondarySystemBackground)
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
                            Label(.bookmarkOpenLink, systemImage: "safari")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background {
                            Color(.secondarySystemBackground)
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
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? .red : .secondary)
                            Text("\(currentPost.likeCount)")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentUserId == nil)
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
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
                            .foregroundStyle(alreadyReported ? Color.secondary : Color.red)
                        Button(.communityBlockUser, action: confirmBlockUser)
                            .foregroundStyle(.red)
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
        .scrollDismissesKeyboard(.interactively)
        .refreshable(action: refresh)
        .simultaneousGesture(TapGesture().onEnded(dismissKeyboard))
        .keenOnChange(of: visibleComments.count) {
            scrollToLatestComment(proxy)
        }
        .safeAreaInset(edge: .bottom) {
            if currentUserId != nil {
                commentInputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isAuthor {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openEditPost) {
                        Image(systemName: "pencil")
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
        .alert(
            .communityDeleteCommentConfirm,
            isPresented: $showDeleteCommentConfirm) {
            Button("Cancel", role: .cancel) {}
            Button(
                "Delete",
                role: .destructive,
                action: deleteConfirmedComment)
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
                ForEach(visibleComments) { comment in
                    commentRow(comment)
                        .id(comment.id)
                }
            }
        }
    }

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            if let error = viewModel.commentErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    .communityCommentPlaceholder,
                    text: $commentText,
                    axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($commentFieldFocused)
                Button(action: submitComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(!canSubmitComment)
                .accessibilityLabel(.communityCommentSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background {
            Color.black
        }
    }

    private func commentRow(_ comment: CommunityComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let emoji = comment.authorEmoji {
                    Text(emoji)
                        .font(.caption)
                }
                Text(comment.authorName)
                    .font(.caption.weight(.semibold))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(comment.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(comment.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if comment.authorId == currentUserId {
                    Menu {
                        Button(role: .destructive, action: { confirmDeleteComment(comment) }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(comment.text)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            Color(.secondarySystemBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        commentText = ""
        shouldScrollToLatestComment = true
        Task {
            await viewModel.addComment(text: trimmed)
        }
    }

    private func confirmDeleteComment(_ comment: CommunityComment) {
        commentPendingDeletion = comment
        showDeleteCommentConfirm = true
    }

    private func deleteConfirmedComment() {
        guard let comment = commentPendingDeletion else { return }
        commentPendingDeletion = nil
        Task {
            await viewModel.deleteComment(comment)
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

